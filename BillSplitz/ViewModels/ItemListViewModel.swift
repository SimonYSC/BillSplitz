//
//  ItemListViewModel.swift
//  BillSplitz
//
//  Created by Simon Chao on 12/16/25.
//

import Foundation

@Observable
class ItemListViewModel {
    // Collections
    var list: [Item] = [
        Item(name: "appetizer 1", price: 7.49),
        Item(name: "appetizer 2", price: 12.99),
        Item(name: "appetizer 3", price: 8.69),
        Item(name: "entre A", price: 17.99),
        Item(name: "entre B", price: 20.99),
        Item(name: "entre C", price: 25.49),
        Item(name: "entre D", price: 32.59),
        Item(name: "dessert", price: 15.49)
    ]
    var users: [User] = [
        User(name: "A", items: []),
        User(name: "B", items: []),
        User(name: "C", items: []),
        User(name: "D", items: [])
    ]
    
    // Constants
    let tax = 0.08875
    let tip = 0.18
    
    // Variables
    var selectedItem: UUID? = nil
    var presentUserOptions: Bool = false
    
    // Computed Properties
    var sum: Double { list.reduce(0) { $0 + $1.price } }
    var sumAfterTaxAndTips: Double { (sum * (1 + tax + tip)) }
    var taxAmount: Double { sum * tax }
    var tipAmount: Double { sum * tip }
    
    // Methods
    func assignItem(to user: inout User) {
        if let selectedItem,
           let index = list.firstIndex(where: { $0.id == selectedItem }) {
            user.items.append(list.remove(at: index))
        }
        selectedItem = nil
    }
}
