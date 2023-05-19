//
//  MandelbrotContainer.swift
//  SwiftUI02
//
//  Created by we on 2023/05/19.
//

import SwiftUI

struct MandelbrotContainer: View {
    @State var drag: CGSize = .zero
    @State var scale: CGFloat = 1.0
    @State var lastLocation: CGPoint? = nil
    
    var body: some View {
        VStack {
            Text("Mandelbrot")
                .font(.largeTitle)
            Text("\(drag.dimension)")
                .lineLimit(1)
            GeometryReader { proxy in
                MandelbrotView(drag: $drag, scale: $scale)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .gesture(DragGesture()
                        .onChanged({ value in
                            if let lastLocation {
                                drag.width += (value.location.x - lastLocation.x) / proxy.size.width / scale
                                drag.height += (value.location.y - lastLocation.y) / proxy.size.height / scale
                            }
                            else {
                                drag.width += value.translation.width / proxy.size.width / scale
                                drag.height += value.translation.height / proxy.size.height / scale
                            }
                            self.lastLocation = value.location
                        }).onEnded({ value in
                            if let lastLocation {
                                drag.width += (value.location.x - lastLocation.x) / proxy.size.width / scale
                                drag.height += (value.location.y - lastLocation.y) / proxy.size.height / scale
                            }
                            else {
                                drag.width += value.translation.width / proxy.size.width / scale
                                drag.height += value.translation.height / proxy.size.height / scale
                            }
                            self.lastLocation = nil
                        }))
            }
            HStack {
                Button {
                    scale *= 2
                } label: {
                    Image(systemName: "plus.circle")
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                Button {
                    scale *= 0.5
                } label: {
                    Image(systemName: "minus.circle")
                        .padding()
                }
                .buttonStyle(.borderedProminent)

            }
            Text("\( 1 / scale)")
                .font(.largeTitle)
            Text("\(scale)")
                .font(.largeTitle)
        }
    }
}

struct MandelbrotContainer_Previews: PreviewProvider {
    static var previews: some View {
        MandelbrotContainer()
    }
}

extension CGSize {
    var dimension: String {
        "\(self.width) x \(height)"
    }
}
