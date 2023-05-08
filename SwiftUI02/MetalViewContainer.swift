//
//  MetalViewContainer.swift
//  SwiftUI02
//
//  Created by we on 2023/05/08.
//

import SwiftUI

struct MetalViewContainer: View {
    @State var command: Command = .init(id: .now, command: "")
    @State var captureImage: UIImage = .init()
    var body: some View {
        GeometryReader { proxy in
            VStack {
                MetalView(command: command, uiImage: $captureImage)
                    .frame(width: proxy.size.width, height: proxy.size.height / 2.0)
                Button("capture") {
                    command = .init(id: .now, command: "capture")
                }
                Text("\(captureImage.size.width)")
                Text("\(captureImage.size.height)")
                Image(uiImage: captureImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .border(.green)
                    .padding()
                    .background(.red)
            }
        }
    }
}

struct MetalViewContainer_Previews: PreviewProvider {
    static var previews: some View {
        MetalViewContainer()
    }
}
