//
//  GraphContainer.swift
//  SwiftUI02
//
//  Created by we on 2023/05/26.
//

import SwiftUI

struct GraphContainer: View {
    @State var graphType: GraphType
    @State var rotationType: RotationType = .none
    
    var body: some View {
        VStack {
            GeometryReader { proxy in
                GraphView(graphType: graphType, rotationType: $rotationType)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            Text("Rotation : \(String(describing: rotationType))")
                .font(.title)
                .foregroundColor(.red)
            HStack {
                Button("Rotate X") {
                    rotationType = .x
                }
                .buttonStyle(.borderedProminent)
                Button("Rotate Y") {
                    rotationType = .y
                }
                .buttonStyle(.borderedProminent)
                Button("Rotate Z") {
                    rotationType = .z
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

struct GraphContainer_Previews: PreviewProvider {
    static var previews: some View {
        GraphContainer(graphType: .cos(dividend: 9, divider: 8), rotationType: .none)
    }
}
