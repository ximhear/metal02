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
    @Binding var scale: CGFloat
    
    init(drag: Binding<CGSize>, scale: Binding<CGFloat>) {
        self._drag = drag
        self._scale = scale
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
        
        func apply(drag: CGSize, scale: CGFloat) {
            guard let renderer else {
                return
            }
            renderer.apply(drag: drag, scale: scale)
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
        context.coordinator.apply(drag: drag, scale: scale)
    }
}
