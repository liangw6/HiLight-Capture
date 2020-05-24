//
//  ContentView.swift
//  HiLight-Capture
//
//  Created by Liang Arthur on 5/24/20.
//  Copyright © 2020 Liang Arthur. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            ZStack {
                ScannerViewController()
                Text("Scan Window")
                    .navigationBarTitle(Text("Scanner"), displayMode: .inline)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
