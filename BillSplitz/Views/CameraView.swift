//
//  CameraView.swift
//  BillSplitz
//
//  Created by Simon Chao on 11/28/25.
//

import SwiftUI

struct CameraView: View {
    var body: some View {
        VStack {
            Image(systemName: "camera")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    CameraView()
}
