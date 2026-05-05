//
//  ItemListModel.swift
//  BillSplitz
//
//  Created by Simon Chao on 12/16/25.
//

import Foundation

struct Item: Identifiable {
    var id = UUID()
    var name: String
    var price: Double
}

struct User {
    var name: String
    var items: [Item]
    var totalSpent: Double
    
    init(name: String, items: [Item]) {
        self.name = name
        self.items = items
        self.totalSpent = 0.0
    }
}

