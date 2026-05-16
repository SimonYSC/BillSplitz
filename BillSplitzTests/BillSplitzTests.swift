//
//  BillSplitzTests.swift
//  BillSplitzTests
//
//  Created by Simon Chao on 11/17/25.
//

import Foundation
import Testing
@testable import BillSplitz

struct BillSplitzTests {
    @Test func splitItemRoundingReconcilesToItemTotal() throws {
        let session = SplitSession(title: "Dinner")
        let participants = [
            Participant(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "A"),
            Participant(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "B"),
            Participant(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "C")
        ]
        let item = ReceiptItem(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            rawText: "Shared appetizer 10.00",
            normalizedName: "Shared appetizer",
            unitPrice: decimal("10.00"),
            category: .appetizer,
            assignmentMode: .shared
        )
        let assignments = participants.map {
            ItemAssignment(receiptItemID: item.id, participantID: $0.id, shareRatio: 1)
        }

        let lines = try SettlementCalculator().calculate(
            session: session,
            participants: participants,
            items: [item],
            assignments: assignments
        )

        #expect(lines[0].itemSubtotal == decimal("3.34"))
        #expect(lines[1].itemSubtotal == decimal("3.33"))
        #expect(lines[2].itemSubtotal == decimal("3.33"))
        #expect(lines.map(\.itemSubtotal).reduce(0, +) == decimal("10.00"))
    }

    @Test func taxAndTipAllocateByItemSubtotal() throws {
        let session = SplitSession(
            title: "Dinner",
            tax: decimal("1.77"),
            tip: decimal("3.60")
        )
        let alice = Participant(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Alice"
        )
        let ben = Participant(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Ben"
        )
        let aliceItem = ReceiptItem(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            rawText: "Pasta 15.00",
            normalizedName: "Pasta",
            unitPrice: decimal("15.00"),
            category: .main,
            assignmentMode: .assigned
        )
        let benItem = ReceiptItem(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            rawText: "Soup 5.00",
            normalizedName: "Soup",
            unitPrice: decimal("5.00"),
            category: .main,
            assignmentMode: .assigned
        )

        let lines = try SettlementCalculator().calculate(
            session: session,
            participants: [alice, ben],
            items: [aliceItem, benItem],
            assignments: [
                ItemAssignment(receiptItemID: aliceItem.id, participantID: alice.id, shareRatio: 1),
                ItemAssignment(receiptItemID: benItem.id, participantID: ben.id, shareRatio: 1)
            ]
        )

        let aliceLine = try #require(lines.first { $0.participantID == alice.id })
        let benLine = try #require(lines.first { $0.participantID == ben.id })

        #expect(aliceLine.itemSubtotal == decimal("15.00"))
        #expect(aliceLine.taxShare == decimal("1.33"))
        #expect(aliceLine.tipShare == decimal("2.70"))
        #expect(aliceLine.grandTotal == decimal("19.03"))

        #expect(benLine.itemSubtotal == decimal("5.00"))
        #expect(benLine.taxShare == decimal("0.44"))
        #expect(benLine.tipShare == decimal("0.90"))
        #expect(benLine.grandTotal == decimal("6.34"))

        #expect(lines.map(\.taxShare).reduce(0, +) == session.tax)
        #expect(lines.map(\.tipShare).reduce(0, +) == session.tip)
    }

    @Test func unassignedItemsFailCalculation() throws {
        let item = ReceiptItem(
            rawText: "Dessert 8.00",
            normalizedName: "Dessert",
            unitPrice: decimal("8.00"),
            category: .dessert,
            assignmentMode: .unassigned
        )

        #expect(throws: SettlementCalculationError.unassignedReceiptItem(item.id)) {
            try SettlementCalculator().calculate(
                session: SplitSession(title: "Dinner"),
                participants: [Participant(name: "A")],
                items: [item],
                assignments: []
            )
        }
    }
}

private func decimal(_ value: String) -> Decimal {
    Decimal(string: value)!
}
