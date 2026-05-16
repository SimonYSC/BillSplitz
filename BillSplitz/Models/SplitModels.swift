//
//  SplitModels.swift
//  BillSplitz
//

import Foundation

struct SplitSession: Identifiable, Equatable {
    var id: UUID
    var createdAt: Date
    var title: String
    var currencyCode: String
    var subtotal: Decimal
    var tax: Decimal
    var tip: Decimal
    var status: SplitSessionStatus
    var receiptImageRefs: [String]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        title: String,
        currencyCode: String = "USD",
        subtotal: Decimal = 0,
        tax: Decimal = 0,
        tip: Decimal = 0,
        status: SplitSessionStatus = .draft,
        receiptImageRefs: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.currencyCode = currencyCode
        self.subtotal = subtotal
        self.tax = tax
        self.tip = tip
        self.status = status
        self.receiptImageRefs = receiptImageRefs
    }
}

enum SplitSessionStatus: String, CaseIterable, Codable {
    case draft
    case reviewingReceipt
    case splittingItems
    case settled
}

struct Participant: Identifiable, Equatable {
    var id: UUID
    var name: String
    var paymentMethodType: PaymentMethodType?
    var paymentHandle: String?
    var displayColor: String

    init(
        id: UUID = UUID(),
        name: String,
        paymentMethodType: PaymentMethodType? = nil,
        paymentHandle: String? = nil,
        displayColor: String = "#2F80ED"
    ) {
        self.id = id
        self.name = name
        self.paymentMethodType = paymentMethodType
        self.paymentHandle = paymentHandle
        self.displayColor = displayColor
    }
}

enum PaymentMethodType: String, CaseIterable, Codable {
    case venmo
    case zelle
    case cashApp
    case other
}

struct ReceiptItem: Identifiable, Equatable {
    var id: UUID
    var rawText: String
    var normalizedName: String
    var quantity: Decimal
    var unitPrice: Decimal
    var category: ReceiptItemCategory
    var assignmentMode: ReceiptItemAssignmentMode

    var totalPrice: Decimal {
        quantity * unitPrice
    }

    init(
        id: UUID = UUID(),
        rawText: String,
        normalizedName: String,
        quantity: Decimal = 1,
        unitPrice: Decimal,
        category: ReceiptItemCategory = .other,
        assignmentMode: ReceiptItemAssignmentMode = .unassigned
    ) {
        self.id = id
        self.rawText = rawText
        self.normalizedName = normalizedName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.category = category
        self.assignmentMode = assignmentMode
    }
}

enum ReceiptItemCategory: String, CaseIterable, Codable {
    case appetizer
    case main
    case drink
    case dessert
    case adjustment
    case other
}

enum ReceiptItemAssignmentMode: String, CaseIterable, Codable {
    case unassigned
    case assigned
    case split
    case shared
}

struct ItemAssignment: Identifiable, Equatable {
    var id: UUID
    var receiptItemID: UUID
    var participantID: UUID
    var shareRatio: Decimal

    init(
        id: UUID = UUID(),
        receiptItemID: UUID,
        participantID: UUID,
        shareRatio: Decimal
    ) {
        self.id = id
        self.receiptItemID = receiptItemID
        self.participantID = participantID
        self.shareRatio = shareRatio
    }
}

struct SplitRulePreset: Identifiable, Equatable {
    var id: UUID
    var name: String
    var sharedCategories: Set<ReceiptItemCategory>
    var individuallyAssignedCategories: Set<ReceiptItemCategory>

    static let mealDefault = SplitRulePreset(
        name: "Shared appetizers and desserts",
        sharedCategories: [.appetizer, .dessert],
        individuallyAssignedCategories: [.main, .drink]
    )

    init(
        id: UUID = UUID(),
        name: String,
        sharedCategories: Set<ReceiptItemCategory>,
        individuallyAssignedCategories: Set<ReceiptItemCategory>
    ) {
        self.id = id
        self.name = name
        self.sharedCategories = sharedCategories
        self.individuallyAssignedCategories = individuallyAssignedCategories
    }
}

struct SettlementLine: Identifiable, Equatable {
    var id: UUID
    var sessionID: UUID
    var participantID: UUID
    var itemSubtotal: Decimal
    var taxShare: Decimal
    var tipShare: Decimal
    var grandTotal: Decimal

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        participantID: UUID,
        itemSubtotal: Decimal,
        taxShare: Decimal,
        tipShare: Decimal
    ) {
        self.id = id
        self.sessionID = sessionID
        self.participantID = participantID
        self.itemSubtotal = itemSubtotal
        self.taxShare = taxShare
        self.tipShare = tipShare
        self.grandTotal = itemSubtotal + taxShare + tipShare
    }
}
