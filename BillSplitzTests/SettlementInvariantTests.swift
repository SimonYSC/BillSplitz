//
//  SettlementInvariantTests.swift
//  BillSplitzTests
//

import Foundation
import Testing
@testable import BillSplitz

// splitmix64 (Vigna & Blackman): fast, well-distributed seeded PRNG for reproducible test generation.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private let defaultSeed: UInt64 = 0xB111_5111_7A00_0001

private func resolvedSeed() -> UInt64 {
    guard let raw = ProcessInfo.processInfo.environment["BILLSPLITZ_SEED"], let parsed = UInt64(raw) else {
        return defaultSeed
    }
    return parsed
}

private struct GeneratedCase {
    var session: SplitSession
    var participants: [Participant]
    var items: [ReceiptItem]
    var assignments: [ItemAssignment]
}

private func deterministicUUID(index: Int, rng: inout SplitMix64) -> UUID {
    let indexHex = String(format: "%04x", index)
    let suffixHex = String(format: "%012x", rng.next() & 0xFFFF_FFFF_FFFF)
    return UUID(uuidString: "00000000-0000-0000-\(indexHex)-\(suffixHex)")!
}

private func generateCase(rng: inout SplitMix64) -> GeneratedCase {
    let participantCount = Int.random(in: 1...8, using: &rng)
    let participants = (0..<participantCount).map { index in
        Participant(id: deterministicUUID(index: index, rng: &rng), name: "P\(index)")
    }

    let itemCount = Int.random(in: 0...40, using: &rng)
    var items: [ReceiptItem] = []
    var assignments: [ItemAssignment] = []

    for _ in 0..<itemCount {
        let unitPriceCents = Int.random(in: -2000...20000, using: &rng)
        let quantity = Int.random(in: 1...5, using: &rng)
        let item = ReceiptItem(
            rawText: "generated item",
            normalizedName: "generated item",
            quantity: Decimal(quantity),
            unitPrice: Decimal(unitPriceCents) / 100
        )
        items.append(item)

        let assigneeCount = Int.random(in: 1...participants.count, using: &rng)
        let shuffledParticipants = participants.shuffled(using: &rng)
        let assignees = shuffledParticipants.prefix(assigneeCount)

        for participant in assignees {
            let weight = Decimal(Int.random(in: 1...4, using: &rng))
            assignments.append(
                ItemAssignment(receiptItemID: item.id, participantID: participant.id, shareRatio: weight)
            )
        }
    }

    let itemSubtotal = items.reduce(Decimal(0)) { $0 + $1.totalPrice }
    let itemSubtotalCents = NSDecimalNumber(decimal: itemSubtotal * 100).intValue

    let tax: Decimal
    let tip: Decimal
    if itemSubtotalCents <= 0 {
        tax = 0
        tip = 0
    } else {
        let taxCents = Int.random(in: 0...(itemSubtotalCents * 30 / 100), using: &rng)
        let tipCents = Int.random(in: 0...(itemSubtotalCents * 30 / 100), using: &rng)
        tax = Decimal(taxCents) / 100
        tip = Decimal(tipCents) / 100
    }

    let session = SplitSession(title: "Generated", tax: tax, tip: tip)

    return GeneratedCase(session: session, participants: participants, items: items, assignments: assignments)
}

private func isCentsExact(_ amount: Decimal) -> Bool {
    let scaled = amount * 100
    var rounded = Decimal()
    var mutableScaled = scaled
    NSDecimalRound(&rounded, &mutableScaled, 0, .plain)
    return rounded == scaled
}

struct SettlementInvariantTests {
    @Test func invariantsHoldAcrossGeneratedCases() throws {
        let seed = resolvedSeed()
        var rng = SplitMix64(seed: seed)

        for i in 0..<500 {
            let generated = generateCase(rng: &rng)
            let context = "seed \(seed) iteration \(i)"

            let lines = try SettlementCalculator().calculate(
                session: generated.session,
                participants: generated.participants,
                items: generated.items,
                assignments: generated.assignments
            )

            let itemSubtotal = generated.items.reduce(Decimal(0)) { $0 + $1.totalPrice }

            // I1
            let grandTotalSum = lines.reduce(Decimal(0)) { $0 + $1.grandTotal }
            #expect(grandTotalSum == itemSubtotal + generated.session.tax + generated.session.tip, "\(context)")

            // I2
            let taxShareSum = lines.reduce(Decimal(0)) { $0 + $1.taxShare }
            let tipShareSum = lines.reduce(Decimal(0)) { $0 + $1.tipShare }
            #expect(taxShareSum == generated.session.tax, "\(context)")
            #expect(tipShareSum == generated.session.tip, "\(context)")

            // I3
            for line in lines {
                #expect(isCentsExact(line.itemSubtotal), "\(context) participant \(line.participantID)")
                #expect(isCentsExact(line.taxShare), "\(context) participant \(line.participantID)")
                #expect(isCentsExact(line.tipShare), "\(context) participant \(line.participantID)")
                #expect(isCentsExact(line.grandTotal), "\(context) participant \(line.participantID)")
            }

            // I4
            for line in lines where line.itemSubtotal == 0 {
                #expect(line.taxShare == 0, "\(context) participant \(line.participantID)")
                #expect(line.tipShare == 0, "\(context) participant \(line.participantID)")
            }

            // I5
            var shuffleRNG = rng
            let shuffledParticipants = generated.participants.shuffled(using: &shuffleRNG)
            let shuffledItems = generated.items.shuffled(using: &shuffleRNG)

            let shuffledLines = try SettlementCalculator().calculate(
                session: generated.session,
                participants: shuffledParticipants,
                items: shuffledItems,
                assignments: generated.assignments
            )

            let grandTotalByParticipant = Dictionary(uniqueKeysWithValues: lines.map { ($0.participantID, $0.grandTotal) })
            let shuffledGrandTotalByParticipant = Dictionary(
                uniqueKeysWithValues: shuffledLines.map { ($0.participantID, $0.grandTotal) }
            )

            for (participantID, grandTotal) in grandTotalByParticipant {
                #expect(shuffledGrandTotalByParticipant[participantID] == grandTotal, "\(context) participant \(participantID)")
            }
        }
    }
}
