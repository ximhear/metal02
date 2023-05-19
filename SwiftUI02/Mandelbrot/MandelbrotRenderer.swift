//
//  MandelbrotRenderer.swift
//  Metal01
//
//  Created by gzonelee on 2023/04/21.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
fileprivate let uniformsStride = ((MemoryLayout<Uniforms>.size + 0xFF) & -0x100)
fileprivate let alignedUniformsSize = uniformsPVstride
fileprivate let maxBuffersInFlight = 3

struct Vertex {
    var position: vector_float2
    var color: vector_float4
}

class MandelbrotRenderer: NSObject, MTKViewDelegate {
    
    public var device: MTLDevice?
    var commandQueue: MTLCommandQueue?
    var dynamicUniformBuffer: MTLBuffer?
    var pipelineState: MTLRenderPipelineState?
    var depthState: MTLDepthStencilState?
    
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var uniformBufferOffset = 0
    
    var uniformBufferIndex = 0
    
    var uniformsSize = 0
    
    var uniforms: UnsafeMutablePointer<Uniforms>?
    
    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    
    var drag: CGSize = .zero
    
    private var vertexBuffer: MTLBuffer!
    private var vertexData: [Vertex] = [] // Array of rectangle vertices
    
    override init() {
        super.init()
    }
    
    func initialize(metalKitView: MTKView) -> Bool {
        GZLogFunc(projectionMatrix)
        guard let device = metalKitView.device else { return false }
        self.device = device
        guard let queue = device.makeCommandQueue() else { return false }
        self.commandQueue = queue
        
        uniformsSize = alignedUniformsSize
        let uniformBufferSize = uniformsSize * maxBuffersInFlight
        
        guard let buffer = device.makeBuffer(length:uniformBufferSize, options:[MTLResourceOptions.storageModeShared]) else { return false }
        dynamicUniformBuffer = buffer
        
        self.dynamicUniformBuffer!.label = "Mandelbrot UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer!.contents()).bindMemory(to:Uniforms.self, capacity:1)
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        
        let mtlVertexDescriptor = MandelbrotRenderer.buildMetalVertexDescriptor()
        
        do {
            pipelineState = try MandelbrotRenderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return false
        }
        
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled = true
        guard let state = device.makeDepthStencilState(descriptor:depthStateDescriptor) else { return false }
        depthState = state
        
        setupVertices()
        return true
    }
    
    private func setupVertices() {
        guard let device else { return }
        vertexData = []
            // Create an array of rectangle vertices with position and color attributes
            let rectangle1 = [
                Vertex(position: vector_float2(-0.5, -0.5), color: vector_float4(1, 0, 0, 1)),
                Vertex(position: vector_float2(0.5, -0.5), color: vector_float4(0, 1, 0, 1)),
                Vertex(position: vector_float2(-0.5, 0.5), color: vector_float4(0, 0, 1, 1))
            ]

            let rectangle2 = [
                Vertex(position: vector_float2(0.5, -0.5), color: vector_float4(0, 1, 0, 1)),
                Vertex(position: vector_float2(0.5, 0.5), color: vector_float4(0, 0, 1, 1)),
                Vertex(position: vector_float2(-0.5, 0.5), color: vector_float4(1, 0, 0, 1))
            ]

            // Append rectangle vertices to the vertexData array
            vertexData += rectangle1
            vertexData += rectangle2

            let vertexBufferSize = vertexData.count * MemoryLayout<Vertex>.stride
            vertexBuffer = device.makeBuffer(bytes: vertexData, length: vertexBufferSize, options: [])
        }
    
    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Create a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        
        mtlVertexDescriptor.attributes[0].format = MTLVertexFormat.float2
        mtlVertexDescriptor.attributes[0].offset = 0
        mtlVertexDescriptor.attributes[0].bufferIndex = 0
        
        mtlVertexDescriptor.attributes[1].format = MTLVertexFormat.float4
        mtlVertexDescriptor.attributes[1].offset = 8
        mtlVertexDescriptor.attributes[1].bufferIndex = 0
        
        mtlVertexDescriptor.layouts[0].stride = 24
        mtlVertexDescriptor.layouts[0].stepRate = 1
        mtlVertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
        
        return mtlVertexDescriptor
    }
    
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexManderbrot")
        let fragmentFunction = library?.makeFunction(name: "fragmentMandelbrot")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.rasterSampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        uniformBufferOffset = uniformsSize * uniformBufferIndex
    }
    
    private func updateGameState(dynamicUniformBuffer: MTLBuffer, uniformBufferOffset: Int) {
        /// Update any game state before rendering
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)
        uniforms?[0].viewMatrix = matrix4x4_translation(0.0, 0.0, 8.0)
        uniforms?[0].projectionMatrix = projectionMatrix
        
        let translation0 = matrix4x4_translation(0.0, -2.0, 0.0)
        uniforms?[0].modelMatrix = translation0
    }
    
    private func draw(renderEncoder: MTLRenderCommandEncoder,
                      viewport: MTLViewport,
                      dynamicUniformBuffer: MTLBuffer,
                      uniformBufferOffset: Int,
                      primitiveType: MTLPrimitiveType? = nil) {
        renderEncoder.setViewport(viewport)
            
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexData.count)
    }
    
    
    func draw(in view: MTKView) {
        /// Per frame updates hare
       
        guard let commandQueue else {
            return
        }
        guard let dynamicUniformBuffer else {
            return
        }
        guard let pipelineState else {
            return
        }
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }
            
            self.updateDynamicBufferState()
            
            self.updateGameState(dynamicUniformBuffer: dynamicUniformBuffer, uniformBufferOffset: uniformBufferOffset)
            
            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            let renderPassDescriptor = view.currentRenderPassDescriptor
            
            if let renderPassDescriptor, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                /// Final pass rendering code here
                renderEncoder.label = "Primary Render Encoder"
                renderEncoder.pushDebugGroup("Draw Box")
                renderEncoder.setCullMode(.none)
                renderEncoder.setFrontFacing(.clockwise)
                renderEncoder.setDepthStencilState(depthState)
                
                
                let viewports = [
                    MTLViewport(originX: 0, originY: 0, width: Double(view.drawableSize.width), height: Double(view.drawableSize.height), znear: 0.0, zfar: 1.0),
                    ]
                
                let primitives: [MTLPrimitiveType?] = [
                    .triangle
                ]
                let pipelines = [
                    pipelineState,
                ]
                for x in 0..<1 {
                    renderEncoder.setRenderPipelineState(pipelines[x])
                    renderEncoder.setVertexBuffer(dynamicUniformBuffer,
                                                  offset:uniformBufferOffset,
                                                  index: 1)
                    renderEncoder.setFragmentBuffer(dynamicUniformBuffer,
                                                    offset:uniformBufferOffset,
                                                    index: 1)
                    draw(renderEncoder: renderEncoder,
                         viewport: viewports[x],
                         dynamicUniformBuffer: dynamicUniformBuffer,
                         uniformBufferOffset: uniformBufferOffset,
                         primitiveType: primitives[x])
                }
                
                renderEncoder.popDebugGroup()
                renderEncoder.endEncoding()
                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
            }
            
            commandBuffer.commit()
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        
        let aspect = Float(size.width) / Float(size.height)
//        projectionMatrix = makeRightHandedPerspectiveMatrix(fovyRadians: radians_from_degrees(65), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
        projectionMatrix = makeLeftHandedPerspectiveMatrix(fovyRadians: radians_from_degrees(65), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
    }
    
    func applyDrag(_ drag: CGSize) {
        self.drag = drag
    }
}

