//
//  SplitDraft.swift
//  BillSplitz
//

import Foundation

struct SplitDraft: Identifiable, Equatable, Codable {
    var id: UUID
    var session: SplitSession
    var payerID: UUID?
    var participants: [Participant]
    var items: [ReceiptItem]
    var assignments: [ItemAssignment]
    var rawReceiptText: String
    var importedImageName: String?
    var recoverableStep: AppFlowStep
    var updatedAt: Date
    var parsedAt: Date?
    var parsedReceiptText: String?

    init(
        id: UUID = UUID(),
        session: SplitSession,
        payerID: UUID? = nil,
        participants: [Participant],
        items: [ReceiptItem] = [],
        assignments: [ItemAssignment] = [],
        rawReceiptText: String = "",
        importedImageName: String? = nil,
        recoverableStep: AppFlowStep = .sessionSetup,
        updatedAt: Date = .now,
        parsedAt: Date? = nil,
        parsedReceiptText: String? = nil
    ) {
        self.id = id
        self.session = session
        self.payerID = payerID ?? participants.first?.id
        self.participants = participants
        self.items = items
        self.assignments = assignments
        self.rawReceiptText = rawReceiptText
        self.importedImageName = importedImageName
        self.recoverableStep = recoverableStep
        self.updatedAt = updatedAt
        self.parsedAt = parsedAt
        self.parsedReceiptText = parsedReceiptText
    }

    static func blank() -> SplitDraft {
        let payer = Participant(name: "You", paymentMethodType: .venmo, displayColor: "#2F80ED")
        let guest = Participant(name: "Alex", displayColor: "#27AE60")

        return SplitDraft(
            session: SplitSession(title: "Dinner", status: .draft),
            payerID: payer.id,
            participants: [payer, guest]
        )
    }

    var payer: Participant? {
        participants.first { $0.id == payerID } ?? participants.first
    }

    var itemSubtotal: Decimal {
        items.map(\.totalPrice).reduce(0, +)
    }

    var receiptTotal: Decimal {
        itemSubtotal + session.tax + session.tip
    }

    var hasAssignmentsForEveryItem: Bool {
        items.allSatisfy { item in
            assignments.contains { $0.receiptItemID == item.id }
        }
    }
}
