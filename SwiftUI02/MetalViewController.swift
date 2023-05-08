//
//  MetalViewController.swift
//  SwiftUI02
//
//  Created by gzonelee on 2023/04/21.
//

import UIKit
import MetalKit

class MetalViewController: UIViewController {

    var renderer: Renderer!
    var mtkView: MTKView?
    
    deinit {
        GZLogFunc()
    }
    
    init(mtkView: MTKView) {
        GZLogFunc(mtkView)
        self.mtkView = mtkView
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.view = mtkView
    }
    
    override func viewDidLoad() {
        GZLogFunc()
        super.viewDidLoad()
        
        let intMin: UInt = UInt.max - 255
        let hexString = String(intMin, radix: 16)
        GZLogFunc(intMin)
        GZLogFunc(hexString)


        GZLogFunc(view)
        guard let mtkView else {
            print("View of Gameview controller is not an MTKView")
            return
        }
        view.addSubview(mtkView)
        
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: mtkView.topAnchor),
            view.bottomAnchor.constraint(equalTo: mtkView.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: mtkView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: mtkView.trailingAnchor)
            
        ])

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported")
            return
        }
        
        for x in 0..<32 {
            let supported = defaultDevice.supportsTextureSampleCount(x)
            if supported {
                GZLogFunc("\(x) : \(supported)")
            }
        }
        
        mtkView.device = defaultDevice
        mtkView.backgroundColor = UIColor.cyan

        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
    }
}
