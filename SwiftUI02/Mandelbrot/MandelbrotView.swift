//
//  MandelbrotView.swift
//  SwiftUI02
//
//  Created by we on 2023/05/19.
//

import SwiftUI
import MetalKit

struct MandelbrotView: UIViewRepresentable {
    @Binding var drag: CGSize
    
    init(drag: Binding<CGSize>) {
        self._drag = drag
    }
    
    class Coordinator: NSObject {
        var renderer: MandelbrotRenderer?
        var metalView: MTKView?
        
        override init() {
            GZLogFunc()
            renderer = MandelbrotRenderer()
            super.init()
        }
        
        deinit {
            GZLogFunc()
        }
        
        func applyDrag(_ drag: CGSize) {
            guard let renderer else {
                return
            }
            renderer.applyDrag(drag)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = context.coordinator.renderer
        _ = context.coordinator.renderer?.initialize(metalKitView: metalView)
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.applyDrag(drag)
    }
}
