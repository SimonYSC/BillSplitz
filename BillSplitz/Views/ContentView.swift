//
//  ContentView.swift
//  BillSplitz
//
//  Created by Simon Chao on 11/17/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppFlowViewModel()

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            AppStartView(viewModel: viewModel)
                .navigationDestination(for: AppFlowStep.self) { step in
                    AppFlowStepView(step: step, viewModel: viewModel)
                }
        }
        .task {
            let repository = UserDefaultsSessionRepository()
            if ProcessInfo.processInfo.arguments.contains("--reset-draft") {
                try? repository.clearActiveDraft()
            }
            viewModel.configure(repository: repository)
        }
        .onChange(of: viewModel.draft) { _, _ in
            viewModel.persistDraft()
        }
    }
}
