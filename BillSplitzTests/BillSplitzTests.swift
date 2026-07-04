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
    @Test func receiptParserExtractsItemsTaxAndTip() {
        let result = ReceiptParserService().parse(
            """
            Gyoza 8.95
            Spicy tuna roll 25.90
            Green tea 4.50
            Mochi dessert 7.50
            Tax 3.97
            Tip 8.43
            Total 59.25
            """
        )

        #expect(result.items.map(\.normalizedName) == ["Gyoza", "Spicy tuna roll", "Green tea", "Mochi dessert"])
        #expect(result.items.map(\.category) == [.appetizer, .main, .drink, .dessert])
        #expect(result.tax == decimal("3.97"))
        #expect(result.tip == decimal("8.43"))
    }

    @Test func defaultSplitPresetSharesAppetizersDessertsAndLeavesMainsAssignable() {
        let participants = [Participant(name: "A"), Participant(name: "B")]
        let appetizer = ReceiptItem(rawText: "Gyoza 8.00", normalizedName: "Gyoza", unitPrice: decimal("8.00"), category: .appetizer)
        let main = ReceiptItem(rawText: "Roll 12.00", normalizedName: "Roll", unitPrice: decimal("12.00"), category: .main)
        let dessert = ReceiptItem(rawText: "Mochi 6.00", normalizedName: "Mochi", unitPrice: decimal("6.00"), category: .dessert)

        let result = SplitRuleEngine().applyMealDefault(items: [appetizer, main, dessert], participants: participants)

        #expect(result.items.first { $0.id == appetizer.id }?.assignmentMode == .shared)
        #expect(result.items.first { $0.id == main.id }?.assignmentMode == .unassigned)
        #expect(result.items.first { $0.id == dessert.id }?.assignmentMode == .shared)
        #expect(result.assignments.filter { $0.receiptItemID == appetizer.id }.count == 2)
        #expect(result.assignments.filter { $0.receiptItemID == main.id }.isEmpty)
        #expect(result.assignments.filter { $0.receiptItemID == dessert.id }.count == 2)
    }

    @MainActor
    @Test func userDefaultsRepositoryPersistsAndClearsActiveDraft() throws {
        let suiteName = "BillSplitzTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        let repository = UserDefaultsSessionRepository(userDefaults: userDefaults)
        var draft = SplitDraft.blank()
        draft.session.title = "Repository Dinner"

        try repository.saveActiveDraft(draft)
        let loadedDraft = try #require(try repository.loadActiveDraft())

        #expect(loadedDraft.session.title == "Repository Dinner")

        try repository.clearActiveDraft()
        #expect(try repository.loadActiveDraft() == nil)
    }

    @Test func shareExportIncludesParticipantTotalsAndHandles() throws {
        let alice = Participant(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Alice",
            paymentHandle: "@alice"
        )
        let ben = Participant(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Ben"
        )
        let session = SplitSession(title: "Dinner", tax: decimal("1.00"), tip: decimal("2.00"))
        let draft = SplitDraft(session: session, payerID: alice.id, participants: [alice, ben])
        let lines = [
            SettlementLine(sessionID: session.id, participantID: alice.id, itemSubtotal: decimal("10.00"), taxShare: decimal("0.50"), tipShare: decimal("1.00")),
            SettlementLine(sessionID: session.id, participantID: ben.id, itemSubtotal: decimal("10.00"), taxShare: decimal("0.50"), tipShare: decimal("1.00"))
        ]

        let summary = ShareExportService().plainTextSummary(draft: draft, settlementLines: lines)

        #expect(summary.contains("Dinner"))
        #expect(summary.contains("Paid by Alice"))
        #expect(summary.contains("Alice: $11.50 (@alice)"))
        #expect(summary.contains("Ben: $11.50"))
    }

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
