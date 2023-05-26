//
//  GraphMenuView.swift
//  SwiftUI02
//
//  Created by we on 2023/05/26.
//

import SwiftUI

struct GraphMenuView: View {
    var body: some View {
        List {
            NavigationLink("r=cos(x)") {
                GraphContainer(graphType: .cos(dividend: 1))
            }
            NavigationLink("r=cos(1.5x)") {
                GraphContainer(graphType: .cos(dividend: 3, divider: 2))
            }
            NavigationLink("r=cos(2x)") {
                GraphContainer(graphType: .cos(dividend: 2))
            }
            NavigationLink("r=cos(2.5x)") {
                GraphContainer(graphType: .cos(dividend: 5, divider: 2))
            }
            NavigationLink("r=cos(3x)") {
                GraphContainer(graphType: .cos(dividend: 3))
            }
            NavigationLink("r=cos(3.5x)") {
                GraphContainer(graphType: .cos(dividend: 7, divider: 2))
            }
            NavigationLink("r=aθ(0.05)") {
                GraphContainer(graphType: .aθ(a: 0.05))
            }
            NavigationLink("r=aθ(0.05, 1)") {
                GraphContainer(graphType: .aθ(a: 0.05, z: 1))
            }
            NavigationLink("r=a√cos(2θ)") {
                GraphContainer(graphType: .aSQRTcos2θ(a: 1.0))
            }
        }
    }
}

struct GraphMenuView_Previews: PreviewProvider {
    static var previews: some View {
        GraphMenuView()
    }
}
