//
//  SplitRuleEngine.swift
//  BillSplitz
//

import Foundation

struct SplitRuleApplication: Equatable {
    var items: [ReceiptItem]
    var assignments: [ItemAssignment]
}

struct SplitRuleEngine {
    func applyMealDefault(items: [ReceiptItem], participants: [Participant]) -> SplitRuleApplication {
        var updatedItems: [ReceiptItem] = []
        var assignments: [ItemAssignment] = []

        for var item in items {
            switch item.category {
            case .appetizer, .dessert, .adjustment:
                item.assignmentMode = .shared
                assignments += participants.map {
                    ItemAssignment(receiptItemID: item.id, participantID: $0.id, shareRatio: 1)
                }
            case .main, .drink, .other:
                item.assignmentMode = .unassigned
            }

            updatedItems.append(item)
        }

        return SplitRuleApplication(items: updatedItems, assignments: assignments)
    }
}
