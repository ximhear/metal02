//
//  ComputeEngine.swift
//  SwiftUI02
//
//  Created by we on 2023/05/17.
//

import Foundation
import Metal

class ComputeEngine: ObservableObject {
    var device: MTLDevice?
    var commandQueue: MTLCommandQueue?
    var computePipelineState: MTLComputePipelineState?
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else { return }
        self.commandQueue = commandQueue
        
        guard let library = device.makeDefaultLibrary() else { return }
        guard let function = library.makeFunction(name: "square_numbers") else { return }
        
        // Create a compute pipeline state
        do {
            computePipelineState = try device.makeComputePipelineState(function: function)
        }
        catch {
            GZLogFunc(error)
            return
        }
    }
    
    func calculateOnGPU(start: @escaping () -> Void, finished: @escaping (TimeInterval) -> Void) {
        
        guard let device, let commandQueue, let computePipelineState else {
            start()
            finished(-1)
            return
        }

        GZLogFunc(MemoryLayout<Int>.size)
        let s = Date.now
        start()
        // Create some data
        let dataSize = 1024 // choose an appropriate size
        var inData = [Int](repeating: 0, count: dataSize)
        for x in 0..<dataSize {
            inData[x] = x
        }
        var outData = [Int](repeating: 1, count: dataSize)

        // Create input and output buffers
        let inBuffer = device.makeBuffer(bytes: &inData, length: dataSize * MemoryLayout<Int>.size, options: [])
        let outBuffer = device.makeBuffer(bytes: &outData, length: dataSize * MemoryLayout<Int>.size, options: [])

        // Create a command buffer
        let commandBuffer = commandQueue.makeCommandBuffer()!

        // Create a compute command encoder
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!

        // Set the compute pipeline state and buffers
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setBuffer(inBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(outBuffer, offset: 0, index: 1)

        let w = computePipelineState.threadExecutionWidth
        GZLogFunc(w)
        GZLogFunc(computePipelineState.maxTotalThreadsPerThreadgroup)
        GZLogFunc()
        // Dispatch the compute command
        let threadsPerGroup = MTLSize(width: w, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (dataSize + w - 1) / w * 2, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        GZLogFunc(threadsPerGroup)
        GZLogFunc(numThreadgroups)
        GZLogFunc()
        
//        GZLogFunc(w)
//        let h = computePipelineState.maxTotalThreadsPerThreadgroup / w
//        let threadsPerThreadgroup = MTLSizeMake(w, 1, 1)
//        let threadsPerGrid = MTLSize(width: dataSize,
//                                     height: 1,
//                                     depth: 1)
//        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

        // End encoding and commit the command
        computeEncoder.endEncoding()
        commandBuffer.commit()

        // Wait for the command to complete
        commandBuffer.waitUntilCompleted()
        let e = Date.now
        
        let dataPointer = outBuffer!.contents().bindMemory(to: Int.self, capacity: dataSize)
        var output = [Int](repeating: 0, count: dataSize)
        for i in 0..<dataSize {
            output[i] = dataPointer[i]
        }
        for (index, x) in output.enumerated() {
            GZLogFunc("[\(index)] : \(x)")
        }
        finished(e.timeIntervalSince(s))
    }
    
}
