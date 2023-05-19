//
//  ComputeView.swift
//  SwiftUI02
//
//  Created by we on 2023/05/17.
//

import SwiftUI

struct ComputeView: View {
    @State var elapsedOnGPU: TimeInterval = 0
    @State var elapsedOnCPU: TimeInterval = 0
    @State var image: UIImage = .init()
    @StateObject var engine: ComputeEngine = .init()
    var body: some View {
        VStack {
            Spacer()
            Text("\(elapsedOnGPU)")
            Button {
                calculateOnGPU()
            } label: {
                Text("Calculate on GPU")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
            Text("\(elapsedOnCPU)")
            Button {
                calculateOnCPU()
            } label: {
                Text("Calculate on CPU")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
            Button {
                fillTextureWithRed()
            } label: {
                Text("Fill texture with red")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
    
    func calculateOnGPU() {
        engine.calculateOnGPU {
            GZLogFunc()
        } finished: { interval in
            GZLogFunc(interval)
            elapsedOnGPU = interval
        }
    }
    
    func calculateOnCPU() {
        engine.calculateOnCPU {
            GZLogFunc()
        } finished: { interval in
            GZLogFunc(interval)
            elapsedOnCPU = interval
        }
    }
    
    func fillTextureWithRed() {
        engine.fillTextureWithRed {
            GZLogFunc()
        } finished: { interval, img in
            GZLogFunc(interval)
            if let img {
                withAnimation(.easeInOut) {
                    image = img
                }
            }
        }
    }
}

struct ComputeView_Previews: PreviewProvider {
    static var previews: some View {
        ComputeView()
    }
}
