//
//  AppFlowViewModelTests.swift
//  BillSplitzTests
//

import Foundation
import Testing
@testable import BillSplitz

@MainActor
struct AppFlowViewModelTests {
    @Test func startingNewSplitCreatesDraftAtSetup() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())

        viewModel.startNewSplit()

        #expect(viewModel.currentStep == .sessionSetup)
        #expect(viewModel.path == [.sessionSetup])
        #expect(viewModel.draft.session.title == "Dinner")
        #expect(viewModel.draft.session.status == .draft)
        #expect(viewModel.hasRecoverableSession)
    }

    @Test func advancingRequiresReceiptInputBeforeReview() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())

        viewModel.startNewSplit()
        viewModel.advance()
        #expect(viewModel.currentStep == .receiptCapture)

        viewModel.advance()
        #expect(viewModel.currentStep == .receiptCapture)
        #expect(viewModel.validationMessage == "Paste receipt text, enter items manually, or use the sample receipt.")
    }

    @Test func sampleReceiptCanAdvanceToShareAfterAssignments() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())

        viewModel.startNewSplit()
        viewModel.advance()
        viewModel.useSampleReceipt()
        viewModel.advance()
        #expect(viewModel.currentStep == .receiptReview)
        #expect(viewModel.draft.items.count == 4)
        #expect(viewModel.draft.session.tax == decimal("3.97"))
        #expect(viewModel.draft.session.tip == decimal("8.43"))

        viewModel.advance()
        #expect(viewModel.currentStep == .splitBoard)
        #expect(viewModel.unassignedItems.count == 2)

        viewModel.advance()
        #expect(viewModel.currentStep == .splitBoard)

        let spicyRoll = viewModel.draft.items.first { $0.normalizedName == "Spicy tuna roll" }!
        let greenTea = viewModel.draft.items.first { $0.normalizedName == "Green tea" }!
        let you = viewModel.draft.participants.first { $0.name == "You" }!
        let alex = viewModel.draft.participants.first { $0.name == "Alex" }!

        viewModel.setAssignmentMode(itemID: spicyRoll.id, mode: .assigned)
        viewModel.toggleAssignment(itemID: spicyRoll.id, participantID: you.id)
        viewModel.setAssignmentMode(itemID: greenTea.id, mode: .assigned)
        viewModel.toggleAssignment(itemID: greenTea.id, participantID: alex.id)

        viewModel.advance()
        #expect(viewModel.currentStep == .settlement)
        if case .ready(let lines) = viewModel.settlementState {
            #expect(lines.map(\.grandTotal).reduce(0, +) == viewModel.draft.receiptTotal)
        } else {
            Issue.record("Expected settlement to be ready")
        }

        viewModel.advance()
        #expect(viewModel.currentStep == .share)
        #expect(viewModel.shareText.contains("Who owes what"))
    }

    @Test func participantSelectionUsesLatestAssignmentMode() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())
        viewModel.startNewSplit()

        let item = ReceiptItem(
            rawText: "Soup 12.00",
            normalizedName: "Soup",
            unitPrice: decimal("12.00"),
            category: .main
        )
        viewModel.draft.items = [item]

        let you = viewModel.draft.participants[0]
        let alex = viewModel.draft.participants[1]

        viewModel.setAssignmentMode(itemID: item.id, mode: .assigned)
        viewModel.selectParticipantForAssignment(itemID: item.id, participantID: you.id)

        #expect(viewModel.draft.items[0].assignmentMode == .assigned)
        #expect(viewModel.isParticipant(you.id, assignedTo: item.id))
        #expect(!viewModel.isParticipant(alex.id, assignedTo: item.id))

        viewModel.setAssignmentMode(itemID: item.id, mode: .split)
        viewModel.selectParticipantForAssignment(itemID: item.id, participantID: you.id)
        viewModel.selectParticipantForAssignment(itemID: item.id, participantID: alex.id)

        #expect(viewModel.draft.items[0].assignmentMode == .split)
        #expect(viewModel.isParticipant(you.id, assignedTo: item.id))
        #expect(viewModel.isParticipant(alex.id, assignedTo: item.id))
    }

    @Test func resumeReturnsToMostRecentFlowStep() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())

        viewModel.startNewSplit()
        viewModel.advance()
        viewModel.useSampleReceipt()
        viewModel.advance()
        viewModel.returnToStart()

        #expect(viewModel.currentStep == .start)
        #expect(viewModel.resumeSplit())
        #expect(viewModel.currentStep == .receiptReview)
    }

    @Test func backThenAdvancePreservesWork() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())

        viewModel.startNewSplit()
        viewModel.advance()
        viewModel.useSampleReceipt()
        viewModel.advance()
        viewModel.advance()
        #expect(viewModel.currentStep == .splitBoard)

        let spicyRoll = viewModel.draft.items.first { $0.normalizedName == "Spicy tuna roll" }!
        let greenTea = viewModel.draft.items.first { $0.normalizedName == "Green tea" }!
        let you = viewModel.draft.participants.first { $0.name == "You" }!
        let alex = viewModel.draft.participants.first { $0.name == "Alex" }!

        viewModel.setAssignmentMode(itemID: spicyRoll.id, mode: .assigned)
        viewModel.toggleAssignment(itemID: spicyRoll.id, participantID: you.id)
        viewModel.setAssignmentMode(itemID: greenTea.id, mode: .assigned)
        viewModel.toggleAssignment(itemID: greenTea.id, participantID: alex.id)

        let itemIDsBeforeBack = Set(viewModel.draft.items.map(\.id))
        let assignmentsBeforeBack = viewModel.draft.assignments
        let taxBeforeBack = viewModel.draft.session.tax

        viewModel.moveBack()
        viewModel.moveBack()
        #expect(viewModel.currentStep == .receiptCapture)

        viewModel.advance()
        #expect(viewModel.currentStep == .receiptReview)
        #expect(Set(viewModel.draft.items.map(\.id)) == itemIDsBeforeBack)
        #expect(viewModel.draft.assignments == assignmentsBeforeBack)
        #expect(viewModel.draft.session.tax == taxBeforeBack)
    }

    @Test func garbageTextBlocksAdvance() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())

        viewModel.startNewSplit()
        viewModel.advance()
        #expect(viewModel.currentStep == .receiptCapture)

        viewModel.draft.rawReceiptText = "no prices in this text"
        viewModel.advance()

        #expect(viewModel.currentStep == .receiptCapture)
        #expect(viewModel.validationMessage != nil)
    }

    @Test func changedTextReParses() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())

        viewModel.startNewSplit()
        viewModel.advance()
        viewModel.useSampleReceipt()
        viewModel.advance()
        #expect(viewModel.currentStep == .receiptReview)
        #expect(viewModel.draft.items.count == 4)

        viewModel.moveBack()
        #expect(viewModel.currentStep == .receiptCapture)

        viewModel.draft.rawReceiptText += "\nExtra roll 6.00"
        viewModel.advance()

        #expect(viewModel.currentStep == .receiptReview)
        #expect(viewModel.draft.items.count == 5)
    }

    @Test func settlementAndShareDoNotMarkSessionSettled() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())

        viewModel.startNewSplit()
        viewModel.advance()
        viewModel.useSampleReceipt()
        viewModel.advance()
        viewModel.advance()
        #expect(viewModel.currentStep == .splitBoard)

        let spicyRoll = viewModel.draft.items.first { $0.normalizedName == "Spicy tuna roll" }!
        let greenTea = viewModel.draft.items.first { $0.normalizedName == "Green tea" }!
        let you = viewModel.draft.participants.first { $0.name == "You" }!
        let alex = viewModel.draft.participants.first { $0.name == "Alex" }!

        viewModel.setAssignmentMode(itemID: spicyRoll.id, mode: .assigned)
        viewModel.toggleAssignment(itemID: spicyRoll.id, participantID: you.id)
        viewModel.setAssignmentMode(itemID: greenTea.id, mode: .assigned)
        viewModel.toggleAssignment(itemID: greenTea.id, participantID: alex.id)

        viewModel.advance()
        #expect(viewModel.currentStep == .settlement)
        #expect(viewModel.draft.session.status == .splittingItems)

        viewModel.advance()
        #expect(viewModel.currentStep == .share)
        #expect(viewModel.draft.session.status == .splittingItems)

        viewModel.advance()
        #expect(viewModel.currentStep == .start)
        #expect(!viewModel.hasRecoverableSession)
    }

    @Test func finishingShareClearsActiveDraft() {
        let repository = InMemorySessionRepository()
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: repository)

        viewModel.startNewSplit()
        viewModel.finishSharing()

        #expect(viewModel.currentStep == .start)
        #expect(!viewModel.hasRecoverableSession)
        #expect(!viewModel.resumeSplit())
        #expect(repository.savedDraft == nil)
    }
}

private func decimal(_ value: String) -> Decimal {
    Decimal(string: value)!
}
