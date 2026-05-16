//
//  SettlementCalculator.swift
//  BillSplitz
//

import Foundation

enum SettlementCalculationError: Error, Equatable {
    case noParticipants
    case unassignedReceiptItem(UUID)
    case missingParticipant(UUID)
    case invalidShareRatio(itemID: UUID, participantID: UUID)
    case zeroAllocationBase
}

struct SettlementCalculator {
    func calculate(
        session: SplitSession,
        participants: [Participant],
        items: [ReceiptItem],
        assignments: [ItemAssignment]
    ) throws -> [SettlementLine] {
        guard !participants.isEmpty else {
            throw SettlementCalculationError.noParticipants
        }

        var itemSubtotals = Dictionary(
            uniqueKeysWithValues: participants.map { ($0.id, Decimal(0)) }
        )
        let participantOrder = participants.map(\.id)
        let participantIDs = Set(participants.map(\.id))
        let assignmentsByItem = Dictionary(grouping: assignments, by: \.receiptItemID)

        for item in items {
            guard let itemAssignments = assignmentsByItem[item.id], !itemAssignments.isEmpty else {
                throw SettlementCalculationError.unassignedReceiptItem(item.id)
            }

            let weights = try combinedWeights(
                for: item,
                assignments: itemAssignments,
                participantIDs: participantIDs
            )
            let itemShares = try roundedAllocation(
                total: item.totalPrice,
                weights: weights,
                participantOrder: participantOrder
            )

            for (participantID, share) in itemShares {
                itemSubtotals[participantID, default: 0] += share
            }
        }

        let taxShares = try roundedAllocation(
            total: session.tax,
            weights: itemSubtotals,
            participantOrder: participantOrder
        )
        let tipShares = try roundedAllocation(
            total: session.tip,
            weights: itemSubtotals,
            participantOrder: participantOrder
        )

        return participants.map { participant in
            let itemSubtotal = itemSubtotals[participant.id, default: 0]
            let taxShare = taxShares[participant.id, default: 0]
            let tipShare = tipShares[participant.id, default: 0]

            return SettlementLine(
                sessionID: session.id,
                participantID: participant.id,
                itemSubtotal: itemSubtotal,
                taxShare: taxShare,
                tipShare: tipShare
            )
        }
    }

    private func combinedWeights(
        for item: ReceiptItem,
        assignments: [ItemAssignment],
        participantIDs: Set<UUID>
    ) throws -> [UUID: Decimal] {
        var weights: [UUID: Decimal] = [:]

        for assignment in assignments {
            guard participantIDs.contains(assignment.participantID) else {
                throw SettlementCalculationError.missingParticipant(assignment.participantID)
            }

            guard assignment.shareRatio > 0 else {
                throw SettlementCalculationError.invalidShareRatio(
                    itemID: item.id,
                    participantID: assignment.participantID
                )
            }

            weights[assignment.participantID, default: 0] += assignment.shareRatio
        }

        return weights
    }

    private func roundedAllocation(
        total: Decimal,
        weights: [UUID: Decimal],
        participantOrder: [UUID]
    ) throws -> [UUID: Decimal] {
        var allocation = Dictionary(uniqueKeysWithValues: participantOrder.map { ($0, Decimal(0)) })
        let totalCents = cents(for: total)

        guard totalCents != 0 else {
            return allocation
        }

        let totalWeight = weights.values.reduce(0, +)
        guard totalWeight > 0 else {
            throw SettlementCalculationError.zeroAllocationBase
        }

        let orderedWeights = participantOrder.compactMap { participantID -> (UUID, Decimal)? in
            guard let weight = weights[participantID] else {
                return nil
            }

            return (participantID, weight)
        }

        let rawShares = orderedWeights.map { participantID, weight in
            (participantID: participantID, amount: total * weight / totalWeight)
        }
        var centsByParticipant = Dictionary(
            uniqueKeysWithValues: rawShares.map { ($0.participantID, cents(for: $0.amount)) }
        )
        let roundedTotalCents = centsByParticipant.values.reduce(0, +)
        let difference = totalCents - roundedTotalCents

        if difference != 0,
           let adjustmentTarget = rawShares.max(by: { abs($0.amount) < abs($1.amount) })?.participantID {
            centsByParticipant[adjustmentTarget, default: 0] += difference
        }

        for (participantID, cents) in centsByParticipant {
            allocation[participantID] = decimal(forCents: cents)
        }

        return allocation
    }

    private func cents(for amount: Decimal) -> Int {
        var scaled = amount * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    private func decimal(forCents cents: Int) -> Decimal {
        Decimal(cents) / 100
    }
}
