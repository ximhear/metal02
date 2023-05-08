//
//  MetalVCView.swift
//  SwiftUI02
//
//  Created by we on 2023/05/08.
//

import SwiftUI
import MetalKit

struct MetalVCView: UIViewControllerRepresentable {
    var command: Command
    
    init(command: Command) {
        self.command = command
    }
    
    
    
    class Coordinator: NSObject {
    }
    
    func makeCoordinator() -> Coordinator {
        GZLogFunc()
        return Coordinator()
    }
    
    func makeUIViewController(context: Context) -> MetalViewController {
        GZLogFunc()
        let metalView = MTKView()
        metalView.translatesAutoresizingMaskIntoConstraints = false
        let vc = MetalViewController(mtkView: metalView)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MetalViewController, context: Context) {
        GZLogFunc(command)
        guard let r = uiViewController.renderer else {
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
