//
//  FirstView.swift
//  SwiftUI02
//
//  Created by we on 2023/05/08.
//

import SwiftUI

struct FirstView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink("content") {
                    ContentView()
                }
                NavigationLink("metal view") {
                    MetalViewContainer()
                }
                NavigationLink("metal view controller") {
                    MetalVCView(command: .init(id: .now, command: ""))
                }
                NavigationLink("compute") {
                    ComputeView()
                }
                NavigationLink("Mandelbrot") {
                    MandelbrotContainer()
                }
            }
        }
    }
}

struct FirstView_Previews: PreviewProvider {
    static var previews: some View {
        FirstView()
    }
}
