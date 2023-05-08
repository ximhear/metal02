//
//  Renderer.swift
//  Metal01
//
//  Created by gzonelee on 2023/04/21.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
let uniformsPVstride = ((MemoryLayout<UniformsPV>.size + 0xFF) & -0x100)
let uniformsMstride = ((MemoryLayout<UniformsM>.size + 0xFF) & -0x100)
let alignedUniformsPVSize = uniformsPVstride * 4
let alignedUniformsMSize = uniformsMstride * 2

let maxBuffersInFlight = 3

enum RendererError: Error {
    case badVertexDescriptor
}

class Renderer: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var dynamicUniformBuffer: MTLBuffer
    var pipelineState: MTLRenderPipelineState
    var pipelineStateLine: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    var colorMap0: MTLTexture
    var colorMap1: MTLTexture
    
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var uniformBufferOffset = 0
    
    var uniformBufferIndex = 0
    
    var uniformsCombinedSize = 0
    var uniformMOffset = 0
    
    var uniformsPV: UnsafeMutablePointer<UniformsPV>
    var uniformsM: UnsafeMutablePointer<UniformsM>
    
    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    
    var rotation: Float = 0
    
    var meshes: [MTKMesh]
    
    init?(metalKitView: MTKView) {
        GZLogFunc(projectionMatrix)
        self.device = metalKitView.device!
        guard let queue = self.device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        uniformsCombinedSize = alignedUniformsPVSize + alignedUniformsMSize
        uniformMOffset = alignedUniformsPVSize
        let uniformBufferSize = uniformsCombinedSize * maxBuffersInFlight
        
        guard let buffer = self.device.makeBuffer(length:uniformBufferSize, options:[MTLResourceOptions.storageModeShared]) else { return nil }
        dynamicUniformBuffer = buffer
        
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        uniformsPV = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:UniformsPV.self, capacity:1)
        uniformsM = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformMOffset).bindMemory(to:UniformsM.self, capacity:1)
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        
        let mtlVertexDescriptor = Renderer.buildMetalVertexDescriptor()
        
        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
            pipelineStateLine = try Renderer.buildRenderPipelineLineWithDevice(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
        
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled = true
        guard let state = device.makeDepthStencilState(descriptor:depthStateDescriptor) else { return nil }
        depthState = state
        
        do {
            meshes = try Renderer.buildMeshes(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to build MetalKit Mesh. Error info: \(error)")
            return nil
        }
        
        do {
            colorMap0 = try Renderer.loadTexture(device: device, textureName: "ColorMap")
            colorMap1 = try Renderer.loadTexture(device: device, textureName: "ggg")
        } catch {
            print("Unable to load texture. Error info: \(error)")
            return nil
        }
        
        super.init()
        
    }
    
    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Create a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue
        
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].format = MTLVertexFormat.float2
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue
        
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 12
//        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 16
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        return mtlVertexDescriptor
    }
    
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")
        
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
    
    class func buildRenderPipelineLineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShaderSolid")
        
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
    
    class func buildMeshes(device: MTLDevice,
                         mtlVertexDescriptor: MTLVertexDescriptor) throws -> [MTKMesh] {
        let a = try buildMesh1(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
        let b = try buildMesh3(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
        return [a, b]
    }
    
    class func buildMesh1(device: MTLDevice,
                         mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let mdlMesh = MDLMesh.newBox(withDimensions: SIMD3<Float>(4, 4, 4),
                                     segments: SIMD3<UInt32>(2, 2, 2),
                                     geometryType: MDLGeometryType.triangles,
                                     inwardNormals:false,
                                     allocator: metalAllocator)
        
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        
        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate
        
        mdlMesh.vertexDescriptor = mdlVertexDescriptor
        
        return try MTKMesh(mesh:mdlMesh, device:device)
    }
    
    class func buildMesh2(device: MTLDevice,
                         mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let mdlMesh = MDLMesh.newIcosahedron(withRadius: 2,
                                     inwardNormals:false,
                                     geometryType: MDLGeometryType.triangles,
                                     allocator: metalAllocator)
        
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        
        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate
        
        mdlMesh.vertexDescriptor = mdlVertexDescriptor
        
        return try MTKMesh(mesh:mdlMesh, device:device)
    }
    
    class func buildMesh3(device: MTLDevice,
                         mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let mdlMesh = MDLMesh.newCapsule(withHeight: 2.5, radii: simd_float2(2.5, 4), radialSegments: 50, verticalSegments: 2, hemisphereSegments: 25, geometryType: .triangles, inwardNormals: false, allocator: metalAllocator)
        
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        
        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate
        
        mdlMesh.vertexDescriptor = mdlVertexDescriptor
        
        return try MTKMesh(mesh:mdlMesh, device:device)
    }
    
    class func loadTexture(device: MTLDevice,
                           textureName: String) throws -> MTLTexture {
        /// Load texture data with optimal parameters for sampling
        
        let textureLoader = MTKTextureLoader(device: device)
        
        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue),
            .generateMipmaps: true
        ]
        
        return try textureLoader.newTexture(name: textureName,
                                            scaleFactor: 1.0,
                                            bundle: nil,
                                            options: textureLoaderOptions)
        
    }
    
    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        uniformBufferOffset = uniformsCombinedSize * uniformBufferIndex
    }
    
    private func updateGameState() {
        /// Update any game state before rendering
        
        uniformsPV = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:UniformsPV.self, capacity:1)
        uniformsPV[0].viewMatrix = matrix4x4_translation(0.0, 0.0, 8.0)
        uniformsPV[0].projectionMatrix = projectionMatrix
        
        uniformsPV = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset + uniformsPVstride).bindMemory(to:UniformsPV.self, capacity:1)
        uniformsPV[0].viewMatrix = simd_mul(matrix4x4_translation(0.0, 0.0, 9.0), matrix4x4_rotation(radians: .pi / 4, axis: .init(1, 0, 0)))
        uniformsPV[0].projectionMatrix = projectionMatrix
        
        uniformsPV = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset + uniformsPVstride * 2).bindMemory(to:UniformsPV.self, capacity:1)
        uniformsPV[0].viewMatrix = simd_mul(matrix4x4_translation(0.0, 0.0, 10.0), matrix4x4_rotation(radians: -Float.pi / 3, axis: .init(1, 0, 0)))
        uniformsPV[0].projectionMatrix = projectionMatrix
        
        uniformsPV = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset + uniformsPVstride * 3).bindMemory(to:UniformsPV.self, capacity:1)
        uniformsPV[0].viewMatrix = simd_mul(matrix4x4_translation(0.0, 0.0, 12.0), matrix4x4_rotation(radians: rotation, axis: .init(1, 1, 1)))
        uniformsPV[0].projectionMatrix = projectionMatrix
        
        let rotationAxis = SIMD3<Float>(1, 1, 0)
        let rotation0 = makeQuaternionRotationMatrix(radians: rotation, axis: rotationAxis)
        let rotation1 = makeQuaternionRotationMatrix(radians: rotation * 4, axis: rotationAxis)
//        let modelMatrix = matrix4x4_rotation(radians: rotation, axis: rotationAxis)
//        let modelMatrix = makeRotationMatrix(radians: rotation, axis: rotationAxis)
        let translation0 = matrix4x4_translation(0.0, -2.0, 0.0)
        let translation1 = matrix4x4_translation(0.0, 2.0, 0.0)
        let scaleMatrix = makeScaleMatrix(scale: .init(x: 0.5, y: 0.5, z: 0.5))
        uniformsM = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset + uniformMOffset).bindMemory(to:UniformsM.self, capacity:1)
        uniformsM[0].modelMatrix = simd_mul(translation0, simd_mul(rotation0, scaleMatrix))
        
        uniformsM = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset + uniformMOffset + uniformsMstride).bindMemory(to:UniformsM.self, capacity:1)
        uniformsM[0].modelMatrix = simd_mul(translation1, rotation1)
        rotation += 0.015
    }
    
private func draw(renderEncoder: MTLRenderCommandEncoder, viewport: MTLViewport, primitiveType: MTLPrimitiveType? = nil) {
        renderEncoder.setViewport(viewport)
        let textures = [colorMap0, colorMap1]
        for x in 0..<2 {
            renderEncoder.setVertexBuffer(dynamicUniformBuffer,
                                          offset:uniformBufferOffset + uniformMOffset + uniformsMstride * x,
                                          index: BufferIndex.uniformsM.rawValue)
            renderEncoder.setFragmentBuffer(dynamicUniformBuffer,
                                            offset:uniformBufferOffset + uniformMOffset + uniformsMstride * x,
                                            index: BufferIndex.uniformsM.rawValue)
            
            for (index, element) in meshes[x].vertexDescriptor.layouts.enumerated() {
                guard let layout = element as? MDLVertexBufferLayout else {
                    return
                }
                
                if layout.stride != 0 {
                    let buffer = meshes[x].vertexBuffers[index]
                    renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
                }
            }
            
            renderEncoder.setFragmentTexture(textures[x], index: TextureIndex.color.rawValue)
            
            for submesh in meshes[x].submeshes {
                renderEncoder.drawIndexedPrimitives(type: primitiveType ?? submesh.primitiveType,
                                                    indexCount: submesh.indexCount,
                                                    indexType: submesh.indexType,
                                                    indexBuffer: submesh.indexBuffer.buffer,
                                                    indexBufferOffset: submesh.indexBuffer.offset)
                
            }
        }
    }
    
    func draw(in view: MTKView) {
        /// Per frame updates hare
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }
            
            self.updateDynamicBufferState()
            
            self.updateGameState()
            
            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            let renderPassDescriptor = view.currentRenderPassDescriptor
            
            if let renderPassDescriptor, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                /// Final pass rendering code here
                renderEncoder.label = "Primary Render Encoder"
                renderEncoder.pushDebugGroup("Draw Box")
                renderEncoder.setCullMode(.back)
                renderEncoder.setFrontFacing(.clockwise)
                renderEncoder.setDepthStencilState(depthState)
                
                
                let viewports = [
                    MTLViewport(originX: 0, originY: 0, width: Double(view.drawableSize.width / 2), height: Double(view.drawableSize.height / 2), znear: 0.0, zfar: 1.0),
                    MTLViewport(originX: view.drawableSize.width / 2, originY: 0, width: Double(view.drawableSize.width / 2), height: Double(view.drawableSize.height / 2), znear: 0.0, zfar: 1.0),
                    MTLViewport(originX: 0, originY: view.drawableSize.height / 2, width: Double(view.drawableSize.width / 2), height: Double(view.drawableSize.height / 2), znear: 0.0, zfar: 1.0),
                    MTLViewport(originX: view.drawableSize.width / 2, originY: view.drawableSize.height / 2, width: Double(view.drawableSize.width / 2), height: Double(view.drawableSize.height / 2), znear: 0.0, zfar: 1.0)
                    ]
                
                let primitives: [MTLPrimitiveType?] = [
                    .triangle, .triangle, .lineStrip, .triangle
                ]
                let pipelines = [
                    pipelineState,
                    pipelineState,
                    pipelineStateLine,
                    pipelineState,
                ]
                for x in 0..<4 {
                    renderEncoder.setRenderPipelineState(pipelines[x])
                    renderEncoder.setVertexBuffer(dynamicUniformBuffer,
                                                  offset:uniformBufferOffset + uniformsPVstride * x,
                                                  index: BufferIndex.uniformsPV.rawValue)
                    renderEncoder.setFragmentBuffer(dynamicUniformBuffer,
                                                    offset:uniformBufferOffset + uniformsPVstride * x,
                                                    index: BufferIndex.uniformsPV.rawValue)
                    draw(renderEncoder: renderEncoder, viewport: viewports[x], primitiveType: primitives[x])
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
    
    func draw1(in view: MTKView) {
        /// Per frame updates hare
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }
            
            self.updateDynamicBufferState()
            
            self.updateGameState()
            
            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            let renderPassDescriptor = view.currentRenderPassDescriptor
            
            if let renderPassDescriptor, let parallelRenderEncoder = commandBuffer.makeParallelRenderCommandEncoder(descriptor: renderPassDescriptor) {
                /// Final pass rendering code here
                
                let viewports = [
                    MTLViewport(originX: 0, originY: 0, width: Double(view.drawableSize.width / 2), height: Double(view.drawableSize.height / 2), znear: 0.0, zfar: 1.0),
                    MTLViewport(originX: view.drawableSize.width / 2, originY: 0, width: Double(view.drawableSize.width / 2), height: Double(view.drawableSize.height / 2), znear: 0.0, zfar: 1.0),
                    MTLViewport(originX: 0, originY: view.drawableSize.height / 2, width: Double(view.drawableSize.width / 2), height: Double(view.drawableSize.height / 2), znear: 0.0, zfar: 1.0),
                    MTLViewport(originX: view.drawableSize.width / 2, originY: view.drawableSize.height / 2, width: Double(view.drawableSize.width / 2), height: Double(view.drawableSize.height / 2), znear: 0.0, zfar: 1.0)
                    ]
                
                let primitives: [MTLPrimitiveType?] = [
                    .lineStrip, .lineStrip, .lineStrip, .lineStrip
                ]
                let pipelines = [
                    pipelineState,
                    pipelineState,
                    pipelineStateLine,
                    pipelineState,
                ]
                for x in 0..<4 {
                    let renderEncoder = parallelRenderEncoder.makeRenderCommandEncoder()!
                    renderEncoder.label = "Primary Render Encoder"
                    renderEncoder.pushDebugGroup("Draw Box")
                    renderEncoder.setCullMode(.back)
                    renderEncoder.setFrontFacing(.clockwise)
                    renderEncoder.setRenderPipelineState(pipelines[x])
                    renderEncoder.setDepthStencilState(depthState)
                    
                    renderEncoder.setVertexBuffer(dynamicUniformBuffer,
                                                  offset:uniformBufferOffset + uniformsPVstride * x,
                                                  index: BufferIndex.uniformsPV.rawValue)
                    renderEncoder.setFragmentBuffer(dynamicUniformBuffer,
                                                    offset:uniformBufferOffset + uniformsPVstride * x,
                                                    index: BufferIndex.uniformsPV.rawValue)
                    
                    draw(renderEncoder: renderEncoder, viewport: viewports[x], primitiveType: primitives[x])
                    
                    renderEncoder.popDebugGroup()
                    renderEncoder.endEncoding()
                }
                parallelRenderEncoder.endEncoding()
            }
            if let drawable = view.currentDrawable {
                commandBuffer.present(drawable)
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
}

// Generic matrix math utility functions
func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, zs, -1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func makeRightHandedPerspectiveMatrix(fovyRadians fovy: Float, aspectRatio: Float, nearZ near: Float, farZ far: Float) -> matrix_float4x4 {
    let yScale = 1 / tan(fovy / 2)
    let xScale = yScale / aspectRatio
    let zScale = far / (far - near)
    let wzScale = -zScale * near
    
    let matrix = matrix_float4x4([
        simd_float4(xScale, 0, 0, 0),
        simd_float4(0, yScale, 0, 0),
        simd_float4(0, 0, -zScale, -1),
        simd_float4(0, 0, wzScale, 0)
    ])
    
    return matrix
}

func matrix_perspective_left_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, -zs, 1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func makeLeftHandedPerspectiveMatrix(fovyRadians fovy: Float, aspectRatio: Float, nearZ near: Float, farZ far: Float) -> matrix_float4x4 {
    let yScale = 1 / tan(fovy / 2)
    let xScale = yScale / aspectRatio
    let zScale = far / (far - near)
    let wzScale = -zScale * near
    
    let matrix = matrix_float4x4([
        simd_float4(xScale, 0, 0, 0),
        simd_float4(0, yScale, 0, 0),
        simd_float4(0, 0, zScale, 1),
        simd_float4(0, 0, wzScale, 0)
    ])
    
    return matrix
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}

func makeQuaternionRotationMatrix(radians: Float, axis: simd_float3) -> matrix_float4x4 {
    let normalizedAxis = normalize(axis)
    let halfAngle = radians / 2
    let w = cos(halfAngle)
    let sinHalfAngle = sin(halfAngle)
    let x = sinHalfAngle * normalizedAxis.x
    let y = sinHalfAngle * normalizedAxis.y
    let z = sinHalfAngle * normalizedAxis.z
    
    let quaternion = simd_quatf(ix: x, iy: y, iz: z, r: w)
    let rotationMatrix = matrix_float4x4(quaternion)
    
    return rotationMatrix
}

func makeRotationMatrix(radians angleRadians: Float, axis: simd_float3) -> matrix_float4x4 {
    let normalizedAxis = normalize(axis)
    let cosAngle = cos(angleRadians)
    let sinAngle = sin(angleRadians)
    let oneMinusCosAngle = 1 - cosAngle
    
    let row0 = simd_float4(
        cosAngle + normalizedAxis.x * normalizedAxis.x * oneMinusCosAngle,
        normalizedAxis.x * normalizedAxis.y * oneMinusCosAngle - normalizedAxis.z * sinAngle,
        normalizedAxis.x * normalizedAxis.z * oneMinusCosAngle + normalizedAxis.y * sinAngle,
        0
    )
    
    let row1 = simd_float4(
        normalizedAxis.y * normalizedAxis.x * oneMinusCosAngle + normalizedAxis.z * sinAngle,
        cosAngle + normalizedAxis.y * normalizedAxis.y * oneMinusCosAngle,
        normalizedAxis.y * normalizedAxis.z * oneMinusCosAngle - normalizedAxis.x * sinAngle,
        0
    )
    
    let row2 = simd_float4(
        normalizedAxis.z * normalizedAxis.x * oneMinusCosAngle - normalizedAxis.y * sinAngle,
        normalizedAxis.z * normalizedAxis.y * oneMinusCosAngle + normalizedAxis.x * sinAngle,
        cosAngle + normalizedAxis.z * normalizedAxis.z * oneMinusCosAngle,
        0
    )
    
    let row3 = simd_float4(0, 0, 0, 1)
    
    let matrix = matrix_float4x4(rows: [row0, row1, row2, row3])
    return matrix
}

func makeScaleMatrix(scale: simd_float3) -> matrix_float4x4 {
    let xScale = simd_float4(scale.x, 0, 0, 0)
    let yScale = simd_float4(0, scale.y, 0, 0)
    let zScale = simd_float4(0, 0, scale.z, 0)
    let wScale = simd_float4(0, 0, 0, 1)
    let scaleMatrix = matrix_float4x4(xScale, yScale, zScale, wScale)
    return scaleMatrix
}
