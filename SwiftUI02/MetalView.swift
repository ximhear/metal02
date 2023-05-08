//
//  MetalView.swift
//  SwiftUI02
//
//  Created by we on 2023/05/08.
//

import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {
    let command: Command
    let textureImage: Binding<UIImage>?
    
    init(command: Command, uiImage: Binding<UIImage>?) {
        GZLogFunc(command)
        textureImage = uiImage
        self.command = command
    }
    
    class Coordinator: NSObject {
        var renderer: Renderer?
        var metalView: MTKView
        var date: Date = .now
        
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
        GZLogFunc(command)
        guard let r = context.coordinator.renderer else {
            return
        }
        if command.command == "reset" {
            r.rotation = 0
        }
        else if command.command == "jump" {
            r.rotation = r.rotation + .pi / 2.0
        }
        else if command.command == "capture" {
            if context.coordinator.date != command.id {
                context.coordinator.date = command.id
                if let textureImage {
                    r.getTexture(mtkView: uiView) { image in
                        textureImage.wrappedValue = image
                        GZLogFunc()
                    }
                }
            }
        }
    }
}
