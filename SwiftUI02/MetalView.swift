//
//  MetalView.swift
//  SwiftUI02
//
//  Created by we on 2023/05/08.
//

import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {
    var command: Command
    
    init(command: Command) {
        self.command = command
    }
    
    class Coordinator: NSObject {
        var renderer: Renderer?
        var metalView: MTKView
        
        override init() {
            GZLogFunc()
            let metalView = MTKView()
            metalView.device = MTLCreateSystemDefaultDevice()
            renderer = Renderer(metalKitView: metalView)
            metalView.delegate = renderer
            self.metalView = metalView
            super.init()
        }
        
        deinit {
            GZLogFunc()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> MTKView {
        return context.coordinator.metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        GZLogFunc(command.command)
        guard let r = context.coordinator.renderer else {
            return
        }
        if command.command == "reset" {
            r.rotation = 0
        }
        else if command.command == "jump" {
            r.rotation = r.rotation + .pi / 2.0
        }
    }
}
