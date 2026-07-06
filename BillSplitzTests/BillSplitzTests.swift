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
            Spring Rolls 8.50
            Pad Thai 16.50
            Green Curry 17.00
            Thai Iced Tea 5.50
            Mango Sticky Rice 9.00
            Tax 4.75
            Tip 11.30
            """
        )

        #expect(result.items.map(\.normalizedName) == ["Spring Rolls", "Pad Thai", "Green Curry", "Thai Iced Tea", "Mango Sticky Rice"])
        #expect(result.items.map(\.category) == [.appetizer, .main, .main, .drink, .dessert])
        #expect(result.tax == decimal("4.75"))
        #expect(result.tip == decimal("11.30"))
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

    @Test func shareExportMatchesFlowDocFormat() throws {
        let you = Participant(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "You"
        )
        let maya = Participant(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Maya"
        )
        let jordan = Participant(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "Jordan"
        )
        let session = SplitSession(title: "Thai Night — Basil House", tax: decimal("4.75"), tip: decimal("11.30"))
        let draft = SplitDraft(
            session: session,
            payerID: you.id,
            participants: [you, maya, jordan],
            payerPaymentMethod: .venmo,
            payerPaymentHandle: "@sam-rivera"
        )
        let lines = [
            SettlementLine(sessionID: session.id, participantID: you.id, itemSubtotal: decimal("30.84"), taxShare: decimal("2.60"), tipShare: decimal("6.16")),
            SettlementLine(sessionID: session.id, participantID: maya.id, itemSubtotal: decimal("14.33"), taxShare: decimal("1.20"), tipShare: decimal("2.87")),
            SettlementLine(sessionID: session.id, participantID: jordan.id, itemSubtotal: decimal("11.33"), taxShare: decimal("0.95"), tipShare: decimal("2.27"))
        ]

        let summary = ShareExportService().plainTextSummary(draft: draft, settlementLines: lines)

        #expect(summary.contains("THAI NIGHT — BASIL HOUSE"))
        #expect(summary.contains("PAID BY YOU · TOTAL"))
        #expect(summary.contains("WHO OWES WHAT"))
        #expect(summary.contains("YOU ............"))
        #expect(summary.contains("PAY YOU VIA VENMO"))
        #expect(summary.contains("@sam-rivera"))
        #expect(summary.contains("— BILLSPLITZ"))
        #expect(summary.components(separatedBy: "@").count - 1 == 1)
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

    @Test func flowDocSampleSettlesToComputedTotals() throws {
        let you = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "You")
        let maya = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Maya")
        let jordan = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "Jordan")
        let participants = [you, maya, jordan]

        let springRolls = ReceiptItem(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            rawText: "Spring Rolls 8.50",
            normalizedName: "Spring Rolls",
            unitPrice: decimal("8.50"),
            category: .appetizer,
            assignmentMode: .shared
        )
        let padThai = ReceiptItem(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            rawText: "Pad Thai 16.50",
            normalizedName: "Pad Thai",
            unitPrice: decimal("16.50"),
            category: .main,
            assignmentMode: .assigned
        )
        let greenCurry = ReceiptItem(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
            rawText: "Green Curry 17.00",
            normalizedName: "Green Curry",
            unitPrice: decimal("17.00"),
            category: .main,
            assignmentMode: .split
        )
        let thaiIcedTea = ReceiptItem(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
            rawText: "Thai Iced Tea 5.50",
            normalizedName: "Thai Iced Tea",
            unitPrice: decimal("5.50"),
            category: .drink,
            assignmentMode: .assigned
        )
        let mangoStickyRice = ReceiptItem(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
            rawText: "Mango Sticky Rice 9.00",
            normalizedName: "Mango Sticky Rice",
            unitPrice: decimal("9.00"),
            category: .dessert,
            assignmentMode: .shared
        )
        let items = [springRolls, padThai, greenCurry, thaiIcedTea, mangoStickyRice]

        let assignments = [
            ItemAssignment(receiptItemID: springRolls.id, participantID: you.id, shareRatio: 1),
            ItemAssignment(receiptItemID: springRolls.id, participantID: maya.id, shareRatio: 1),
            ItemAssignment(receiptItemID: springRolls.id, participantID: jordan.id, shareRatio: 1),
            ItemAssignment(receiptItemID: padThai.id, participantID: you.id, shareRatio: 1),
            ItemAssignment(receiptItemID: greenCurry.id, participantID: you.id, shareRatio: 1),
            ItemAssignment(receiptItemID: greenCurry.id, participantID: maya.id, shareRatio: 1),
            ItemAssignment(receiptItemID: thaiIcedTea.id, participantID: jordan.id, shareRatio: 1),
            ItemAssignment(receiptItemID: mangoStickyRice.id, participantID: you.id, shareRatio: 1),
            ItemAssignment(receiptItemID: mangoStickyRice.id, participantID: maya.id, shareRatio: 1),
            ItemAssignment(receiptItemID: mangoStickyRice.id, participantID: jordan.id, shareRatio: 1)
        ]

        let session = SplitSession(title: "Thai Night — Basil House", tax: decimal("4.75"), tip: decimal("11.30"))
        let lines = try SettlementCalculator().calculate(
            session: session,
            participants: participants,
            items: items,
            assignments: assignments
        )

        let youLine = try #require(lines.first { $0.participantID == you.id })
        let mayaLine = try #require(lines.first { $0.participantID == maya.id })
        let jordanLine = try #require(lines.first { $0.participantID == jordan.id })

        #expect(youLine.itemSubtotal == decimal("30.84"))
        #expect(youLine.taxShare == decimal("2.60"))
        #expect(youLine.tipShare == decimal("6.16"))
        #expect(youLine.grandTotal == decimal("39.60"))

        #expect(mayaLine.itemSubtotal == decimal("14.33"))
        #expect(mayaLine.taxShare == decimal("1.20"))
        #expect(mayaLine.tipShare == decimal("2.87"))
        #expect(mayaLine.grandTotal == decimal("18.40"))

        #expect(jordanLine.itemSubtotal == decimal("11.33"))
        #expect(jordanLine.taxShare == decimal("0.95"))
        #expect(jordanLine.tipShare == decimal("2.27"))
        #expect(jordanLine.grandTotal == decimal("14.55"))

        #expect(lines.map(\.grandTotal).reduce(0, +) == decimal("72.55"))
    }

    @Test func editableStringRoundTripsThroughDecimalParsing() {
        let values = [decimal("3.97"), decimal("1234.56"), decimal("0.05")]

        for value in values {
            #expect(CurrencyFormatter.decimal(from: CurrencyFormatter.editableString(for: value)) == value)
        }
    }

    @Test func editableStringUsesCanonicalDotDecimalWithNoGrouping() {
        #expect(CurrencyFormatter.editableString(for: decimal("1234.56")) == "1234.56")
        #expect(CurrencyFormatter.editableString(for: decimal("3.97")) == "3.97")
    }

    @Test func decimalFromToleratesDollarSignAndGroupingCommas() {
        #expect(CurrencyFormatter.decimal(from: "$1,234.56") == decimal("1234.56"))
    }

    @Test func v1DraftJSONStillDecodes() throws {
        let draft = SplitDraft.blank()
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let payload = try encoder.encode(draft)
        let object = try JSONSerialization.jsonObject(with: payload) as! [String: Any]
        var v1Object = object
        var v1Participants: [[String: Any]] = []

        for (index, var participantObject) in (object["participants"] as! [[String: Any]]).enumerated() {
            participantObject["displayColor"] = "#2F80ED"
            if index == 0 {
                participantObject["paymentMethodType"] = "venmo"
                participantObject["paymentHandle"] = "@old"
            }
            v1Participants.append(participantObject)
        }

        v1Object["participants"] = v1Participants
        v1Object.removeValue(forKey: "payerPaymentMethod")
        v1Object.removeValue(forKey: "payerPaymentHandle")

        let v1Payload = try JSONSerialization.data(withJSONObject: v1Object)
        let decodedDraft = try decoder.decode(SplitDraft.self, from: v1Payload)

        #expect(decodedDraft.payerPaymentMethod == nil)
        #expect(decodedDraft.payerPaymentHandle == nil)
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
