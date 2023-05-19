//
//  MandelbrotContainer.swift
//  SwiftUI02
//
//  Created by we on 2023/05/19.
//

import SwiftUI

struct MandelbrotContainer: View {
    @State var drag: CGSize = .zero
    @State var lastLocation: CGPoint? = nil
    
    var body: some View {
        VStack {
            Text("Mandelbrot")
                .font(.largeTitle)
            Text("\(drag.dimension)")
                .lineLimit(1)
            GeometryReader { proxy in
                MandelbrotView(drag: $drag)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .gesture(DragGesture()
                        .onChanged({ value in
                            if let lastLocation {
                                drag.width += (value.location.x - lastLocation.x) / proxy.size.width
                                drag.height += (value.location.y - lastLocation.y) / proxy.size.height
                            }
                            else {
                                drag.width += value.translation.width / proxy.size.width
                                drag.height += value.translation.height / proxy.size.height
                            }
                            self.lastLocation = value.location
                        }).onEnded({ value in
                            if let lastLocation {
                                drag.width += (value.location.x - lastLocation.x) / proxy.size.width
                                drag.height += (value.location.y - lastLocation.y) / proxy.size.height
                            }
                            else {
                                drag.width += value.translation.width / proxy.size.width
                                drag.height += value.translation.height / proxy.size.height
                            }
                            self.lastLocation = nil
                        }))
            }
            Text("Mandelbrot")
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
