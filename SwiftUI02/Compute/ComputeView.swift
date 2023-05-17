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
}

struct ComputeView_Previews: PreviewProvider {
    static var previews: some View {
        ComputeView()
    }
}
