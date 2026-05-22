//
//  ContentView.swift
//  BillSplitz
//
//  Created by Simon Chao on 11/17/25.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppFlowViewModel()

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            AppStartView(viewModel: viewModel)
                .navigationDestination(for: AppFlowStep.self) { step in
                    AppFlowStepView(step: step, viewModel: viewModel)
                }
        }
    }
}

#Preview {
    ContentView()
}
