//
//  MandelbrotContainer.swift
//  SwiftUI02
//
//  Created by we on 2023/05/19.
//

import SwiftUI

struct MandelbrotContainer: View {
    @State var drag: CGSize = .zero
    var body: some View {
        VStack {
            MandelbrotView(drag: $drag)
        }
    }
}

struct MandelbrotContainer_Previews: PreviewProvider {
    static var previews: some View {
        MandelbrotContainer()
    }
}
