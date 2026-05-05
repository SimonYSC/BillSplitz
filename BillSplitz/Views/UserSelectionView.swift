//
//  UserSelectionView.swift
//  BillSplitz
//
//  Created by Simon Chao on 12/16/25.
//

import SwiftUI

struct UserSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @State var viewModel: ItemListViewModel
    
    init(viewModel: ItemListViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            ForEach($viewModel.users, id: \.name) { $user in
                Button {
                    viewModel.assignItem(to: &user)
                    dismiss()
                } label: {
                    Text(user.name)
                        .frame(width: 200, height: 50)
                        .background(Color.yellow)
                }
            }
        }
    }
    
    
}

#Preview {
    UserSelectionView(viewModel: .init())
}
