//
//  MetalViewContainer.swift
//  SwiftUI02
//
//  Created by we on 2023/05/08.
//

import SwiftUI

struct MetalViewContainer: View {
    @State var command: Command = .init(id: .now, command: "")
    var body: some View {
        VStack {
            MetalView(command: command)
            Button("capture") {
                command = .init(id: .now, command: "capture")
            }
        }
    }
}

struct MetalViewContainer_Previews: PreviewProvider {
    static var previews: some View {
        MetalViewContainer()
    }
}
