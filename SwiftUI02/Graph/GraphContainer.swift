//
//  GraphContainer.swift
//  SwiftUI02
//
//  Created by we on 2023/05/26.
//

import SwiftUI

struct GraphContainer: View {
    @State var graphType: GraphType
    
    var body: some View {
        VStack {
            GeometryReader { proxy in
                GraphView(graphType: graphType)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

struct GraphContainer_Previews: PreviewProvider {
    static var previews: some View {
        GraphContainer(graphType: .cos(dividend: 7, divider: 8))
    }
}
