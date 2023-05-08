//
//  ContentView.swift
//  SwiftUI02
//
//  Created by we on 2023/05/04.
//

import SwiftUI

struct ContentView: View {
    @State var command: String = ""
    @State var date: Date = .now
    
    var body: some View {
        GeometryReader { proxy in
            VStack {
                ZStack {
                    MetalView(command: Command(id: date, command: command), uiImage: nil)
                    VStack {
                        Button("reset") {
                            command = "reset"
                            date = .now
                        }
                        Button("jump") {
                            command = "jump"
                            date = .now
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height / 2.0)
                ZStack {
                    MetalVCView(command: Command(id: date, command: command))
                }
                .frame(width: proxy.size.width, height: proxy.size.height / 2.0)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
