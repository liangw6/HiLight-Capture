//
//  ContentView.swift
//  HiLight-Capture
//
//  Created by Liang Arthur on 5/24/20.
//  Copyright © 2020 Liang Arthur. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    
    @ObservedObject var viewModel = ViewModel()
    var body: some View {
        NavigationView {
            ZStack {
                ScanView(viewModel: viewModel)
                Text("\(viewModel.decoded_seq)")
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
