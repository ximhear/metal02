//
//  GraphRenderer.swift
//  Metal01
//
//  Created by gzonelee on 2023/04/21.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
fileprivate let uniformsStride = ((MemoryLayout<GraphUniforms>.size + 0xFF) & -0x100)
fileprivate let alignedUniformsSize = uniformsStride
fileprivate let maxBuffersInFlight = 3

fileprivate struct Vertex {
    var position: vector_float3
}

enum GraphType {
    case cos(dividend: Int, divider: Int = 1)
    case aθ(a: Float, z: Float = 0)
    case aSQRTcos2θ(a: Float)
}

enum RotationType: CustomStringConvertible {
    case x
    case y
    case z
    case none
    
    var description: String {
        switch self {
        case .x:
            return "X"
        case .y:
            return "Y"
        case .z:
            return "Z"
        case .none:
            return "none"
        }
    }
}

class GraphRenderer: NSObject, MTKViewDelegate {
    
    public var device: MTLDevice?
    var commandQueue: MTLCommandQueue?
    var dynamicUniformBuffer: MTLBuffer?
    var pipelineState: MTLRenderPipelineState?
    var depthState: MTLDepthStencilState?
    
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var uniformBufferOffset = 0
    var uniformBufferIndex = 0
    var uniformsSize = 0
    var uniforms: UnsafeMutablePointer<GraphUniforms>?
    
    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    var aspectRatio: Float = 1.0
    var rotation: Float = 0
    var rotationType: RotationType?
    
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
        
        self.dynamicUniformBuffer!.label = "Graph UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer!.contents()).bindMemory(to:GraphUniforms.self, capacity:1)
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        
        let mtlVertexDescriptor = Self.buildMetalVertexDescriptor()
        
        do {
            pipelineState = try Self.buildRenderPipelineWithDevice(device: device,
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
        
        return true
    }
    
    func gcd(_ a: Int, _ b: Int) -> Int {
        let aa = max(a, b)
        let bb = min(a, b)
        let remainder = aa % bb
        if remainder != 0 {
            return gcd(bb, remainder)
        } else {
            return bb
        }
    }
    
    func setRotationType(_ type: RotationType?) {
        rotation = 0
        rotationType = type
    }
    
    func setupVertices(graphType: GraphType) {
        guard let device else { return }
        
        vertexData = []
        
        if case .cos(let a, let b) = graphType {
            // a/b와 1의 최대 공약수를 구해서 2pi를 나누면 주기가 된다.
            // 1 == b/b, a와 b의 최대 공약수(c라고 하자)를 구한 뒤 2pi를 c/b로 나누어준다. 즉, 2pi * b / c
            let c = gcd(a, b)
            let numPoints = Int64(1000 * Float(b) / Float(c))
            let factor = Float(a) / Float(b)
            for i in 0 ... numPoints {
                let angle = 2 * .pi * Float(b) / Float(c) * Float(i) / Float(numPoints)
                let radius = cos(angle * factor)
                vertexData.append(Vertex(position: radius * simd_float3(cos(angle), sin(angle), 0)))
            }
        }
        else if case .aθ(let a, let z) = graphType {
            let numPoints = 1000
            for i in 0 ..< numPoints {
                let angle = 8 * .pi * Float(i) / Float(numPoints)
                let radius = angle * a
                vertexData.append(Vertex(position: radius * simd_float3(cos(angle), sin(angle), z)))
            }
        }
        else if case .aSQRTcos2θ(let a) = graphType {
            let numPoints = 1000
            for i in 0 ... numPoints {
                let angle = 2 * .pi * Float(i) / Float(numPoints)
//                let radius = a * sqrt(cos(2 * angle))
//                vertexData.append(Vertex(position: radius * simd_float3(cos(angle), sin(angle), 0)))
                
                let x = a * cos(angle) / (1 + pow(sin(angle), 2))
                let y = a * cos(angle) * sin(angle) / (1 + pow(sin(angle), 2))
                vertexData.append(Vertex(position: simd_float3(x, y, 0)))
            }
        }
        
        GZLogFunc(MemoryLayout<Vertex>.stride)
        GZLogFunc(vertexData.count)
        let vertexBufferSize = vertexData.count * MemoryLayout<Vertex>.stride
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: vertexBufferSize, options: [])
    }
    
    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Create a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        
        mtlVertexDescriptor.attributes[0].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[0].offset = 0
        mtlVertexDescriptor.attributes[0].bufferIndex = 0
        
        mtlVertexDescriptor.layouts[0].stride = 16
        mtlVertexDescriptor.layouts[0].stepRate = 1
        mtlVertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
        
        return mtlVertexDescriptor
    }
    
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexGraph")
        let fragmentFunction = library?.makeFunction(name: "fragmentGraph")
        
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
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:GraphUniforms.self, capacity:1)
        uniforms?[0].projectionMatrix = projectionMatrix
        uniforms?[0].viewMatrix = matrix4x4_translation(0.0, 0.0, 3.0)
        
        let rotationMatrix: matrix_float4x4
        if let rotationType {
            switch rotationType {
            case .none:
                rotationMatrix = .init(diagonal: .init(x: 1, y: 1, z: 1, w: 1))
            case .x:
                rotationMatrix = matrix4x4_rotation(radians: rotation , axis: .init(x: 1, y: 0, z: 0))
            case .y:
                rotationMatrix = matrix4x4_rotation(radians: rotation , axis: .init(x: 0, y: 1, z: 0))
            case .z:
                rotationMatrix = matrix4x4_rotation(radians: rotation , axis: .init(x: 0, y: 0, z: 1))
            }
        }
        else {
            rotationMatrix = .init(diagonal: .init(x: 1, y: 1, z: 1, w: 1))
        }
        uniforms?[0].modelMatrix = rotationMatrix
        rotation += 0.010
    }
    
    private func draw(renderEncoder: MTLRenderCommandEncoder,
                      viewport: MTLViewport,
                      dynamicUniformBuffer: MTLBuffer,
                      uniformBufferOffset: Int,
                      primitiveType: MTLPrimitiveType = .lineStrip) {
        renderEncoder.setViewport(viewport)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: vertexData.count)
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
                
                let primitives: [MTLPrimitiveType] = [
                    .lineStrip
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
        aspectRatio = aspect
        projectionMatrix = makeLeftHandedPerspectiveMatrix(fovyRadians: radians_from_degrees(65), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
    }
}
