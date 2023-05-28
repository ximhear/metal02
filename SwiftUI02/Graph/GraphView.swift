//
//  GraphView.swift
//  SwiftUI02
//
//  Created by we on 2023/05/26.
//

import SwiftUI
import MetalKit

struct GraphView: UIViewRepresentable {
    @State var graphType: GraphType
    @Binding var rotationType: RotationType
    
    class Coordinator: NSObject {
        var renderer: GraphRenderer?
        var metalView: MTKView?
        
        override init() {
            renderer = GraphRenderer()
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
        let metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = context.coordinator.renderer
        _ = context.coordinator.renderer?.initialize(metalKitView: metalView)
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        GZLogFunc(rotationType)
        context.coordinator.renderer?.setRotationType(rotationType)
        context.coordinator.renderer?.setupVertices(graphType: graphType)
    }
}

struct GraphView_Previews: PreviewProvider {
    static var previews: some View {
        GraphView(graphType: .cos(dividend: 37, divider: 9), rotationType: .constant(.x))
    }
}
