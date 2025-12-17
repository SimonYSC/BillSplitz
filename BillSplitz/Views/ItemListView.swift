//
//  ItemListView.swift
//  BillSplitz
//
//  Created by Simon Chao on 12/13/25.
//

import SwiftUI

struct ItemListView: View {
    @State private var viewModel: ItemListViewModel = .init()
    
    var body: some View {
        NavigationStack {
            VStack {
                List(viewModel.list) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text(item.price, format: .currency(code: "USD"))
                    }
                    //            .onLongPressGesture {
                    //                // show a pop up box to choose how many people is splitting this item
                    //            }
                    .onTapGesture {
                        // show a pop up box to choose which users to give to
                        viewModel.presentUserOptions.toggle()
                        viewModel.selectedItem = item.id
                    }
                }
                List(viewModel.users, id: \.name) { user in
                    VStack {
                        Text(user.name)
                        ForEach(user.items) { item in
                            Text("- \(item.name): $\(item.price, specifier: "%.2f")")
                        }
                    }
                }
                Text("Sum: $\(viewModel.sum, specifier: "%.2f")")
                Text("Tax: $\(viewModel.taxAmount, specifier: "%.2f")")
                Text("Tip: $\(viewModel.tipAmount, specifier: "%.2f")")
                Text("Total: $\(viewModel.sumAfterTaxAndTips, specifier: "%.2f")")
            }
            .navigationTitle("BillSplitz")
            .sheet(isPresented: $viewModel.presentUserOptions) {
                UserSelectionView(viewModel: viewModel)
            }
        }
    }
}

#Preview {
    ItemListView()
}
