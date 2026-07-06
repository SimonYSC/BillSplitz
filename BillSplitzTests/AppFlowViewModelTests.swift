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
        #expect(viewModel.validationMessage == "Paste receipt text, choose a photo, or add items manually.")
    }

    @Test func sampleReceiptCanAdvanceToShareAfterAssignments() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())

        viewModel.startNewSplit()
        viewModel.advance()
        viewModel.useSampleReceipt()
        viewModel.advance()
        #expect(viewModel.currentStep == .receiptReview)
        #expect(viewModel.draft.items.count == 5)
        #expect(viewModel.draft.session.tax == decimal("4.75"))
        #expect(viewModel.draft.session.tip == decimal("11.30"))

        viewModel.advance()
        #expect(viewModel.currentStep == .splitBoard)
        #expect(viewModel.unassignedItems.count == 3)

        viewModel.advance()
        #expect(viewModel.currentStep == .splitBoard)

        let padThai = viewModel.draft.items.first { $0.normalizedName == "Pad Thai" }!
        let greenCurry = viewModel.draft.items.first { $0.normalizedName == "Green Curry" }!
        let thaiIcedTea = viewModel.draft.items.first { $0.normalizedName == "Thai Iced Tea" }!
        let you = viewModel.draft.participants.first { $0.name == "You" }!
        let alex = viewModel.draft.participants.first { $0.name == "Alex" }!

        viewModel.connect(itemID: padThai.id, to: you.id)
        viewModel.connect(itemID: greenCurry.id, to: you.id)
        viewModel.connect(itemID: thaiIcedTea.id, to: alex.id)

        viewModel.advance()
        #expect(viewModel.currentStep == .settlement)
        if case .ready(let lines) = viewModel.settlementState {
            #expect(lines.map(\.grandTotal).reduce(0, +) == viewModel.draft.receiptTotal)
        } else {
            Issue.record("Expected settlement to be ready")
        }

        viewModel.advance()
        #expect(viewModel.currentStep == .share)
        #expect(viewModel.shareText.contains("WHO OWES WHAT"))
    }

    @Test func connectionModelReflectsLatestConnections() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())
        viewModel.startNewSplit()
        viewModel.addParticipant()

        let item = ReceiptItem(
            rawText: "Soup 12.00",
            normalizedName: "Soup",
            unitPrice: decimal("12.00"),
            category: .main
        )
        viewModel.draft.items = [item]

        let you = viewModel.draft.participants[0]
        let alex = viewModel.draft.participants[1]

        viewModel.connect(itemID: item.id, to: you.id)

        #expect(viewModel.draft.items[0].assignmentMode == .assigned)
        #expect(viewModel.isConnected(you.id, to: item.id))
        #expect(!viewModel.isConnected(alex.id, to: item.id))

        viewModel.connect(itemID: item.id, to: alex.id)

        #expect(viewModel.draft.items[0].assignmentMode == .split)
        #expect(viewModel.isConnected(you.id, to: item.id))
        #expect(viewModel.isConnected(alex.id, to: item.id))
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

        let padThai = viewModel.draft.items.first { $0.normalizedName == "Pad Thai" }!
        let greenCurry = viewModel.draft.items.first { $0.normalizedName == "Green Curry" }!
        let thaiIcedTea = viewModel.draft.items.first { $0.normalizedName == "Thai Iced Tea" }!
        let you = viewModel.draft.participants.first { $0.name == "You" }!
        let alex = viewModel.draft.participants.first { $0.name == "Alex" }!

        viewModel.connect(itemID: padThai.id, to: you.id)
        viewModel.connect(itemID: greenCurry.id, to: you.id)
        viewModel.connect(itemID: thaiIcedTea.id, to: alex.id)

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

    @Test func photoOnlyCaptureAdvancesToEmptyReview() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())

        viewModel.startNewSplit()
        viewModel.advance()
        #expect(viewModel.currentStep == .receiptCapture)

        viewModel.notePhotoSelected()
        viewModel.advance()

        #expect(viewModel.currentStep == .receiptReview)
        #expect(viewModel.draft.items.isEmpty)

        viewModel.advance()
        #expect(viewModel.currentStep == .receiptReview)
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
        #expect(viewModel.draft.items.count == 5)

        viewModel.moveBack()
        #expect(viewModel.currentStep == .receiptCapture)

        viewModel.draft.rawReceiptText += "\nExtra roll 6.00"
        viewModel.advance()

        #expect(viewModel.currentStep == .receiptReview)
        #expect(viewModel.draft.items.count == 6)
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

        let padThai = viewModel.draft.items.first { $0.normalizedName == "Pad Thai" }!
        let greenCurry = viewModel.draft.items.first { $0.normalizedName == "Green Curry" }!
        let thaiIcedTea = viewModel.draft.items.first { $0.normalizedName == "Thai Iced Tea" }!
        let you = viewModel.draft.participants.first { $0.name == "You" }!
        let alex = viewModel.draft.participants.first { $0.name == "Alex" }!

        viewModel.connect(itemID: padThai.id, to: you.id)
        viewModel.connect(itemID: greenCurry.id, to: you.id)
        viewModel.connect(itemID: thaiIcedTea.id, to: alex.id)

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

    // MARK: - Split Board connection model

    @Test func connectOnUnassignedItemCreatesSoleAssignment() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())
        viewModel.startNewSplit()

        let item = ReceiptItem(rawText: "Soup 12.00", normalizedName: "Soup", unitPrice: decimal("12.00"), category: .main)
        viewModel.draft.items = [item]
        let you = viewModel.draft.participants[0]

        viewModel.connect(itemID: item.id, to: you.id)

        #expect(viewModel.draft.assignments.count == 1)
        #expect(viewModel.draft.assignments[0].shareRatio == 1)
        #expect(viewModel.draft.items[0].assignmentMode == .assigned)
    }

    @Test func connectingSecondPersonProducesSplit() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())
        viewModel.startNewSplit()
        viewModel.addParticipant()

        let item = ReceiptItem(rawText: "Soup 12.00", normalizedName: "Soup", unitPrice: decimal("12.00"), category: .main)
        viewModel.draft.items = [item]
        let you = viewModel.draft.participants[0]
        let alex = viewModel.draft.participants[1]

        viewModel.connect(itemID: item.id, to: you.id)
        viewModel.connect(itemID: item.id, to: alex.id)

        #expect(viewModel.draft.items[0].assignmentMode == .split)
        #expect(viewModel.isConnected(you.id, to: item.id))
        #expect(viewModel.isConnected(alex.id, to: item.id))
    }

    @Test func connectingSamePersonTwiceIsIdempotent() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())
        viewModel.startNewSplit()

        let item = ReceiptItem(rawText: "Soup 12.00", normalizedName: "Soup", unitPrice: decimal("12.00"), category: .main)
        viewModel.draft.items = [item]
        let you = viewModel.draft.participants[0]

        viewModel.connect(itemID: item.id, to: you.id)
        viewModel.connect(itemID: item.id, to: you.id)

        #expect(viewModel.draft.assignments.count == 1)
    }

    @Test func connectingEveryParticipantIndividuallyReadsAsShared() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())
        viewModel.startNewSplit()

        let item = ReceiptItem(rawText: "Soup 12.00", normalizedName: "Soup", unitPrice: decimal("12.00"), category: .main)
        viewModel.draft.items = [item]

        for participant in viewModel.draft.participants {
            viewModel.connect(itemID: item.id, to: participant.id)
        }

        #expect(viewModel.draft.items[0].assignmentMode == .shared)
    }

    @Test func shareWithEveryoneAssignsOnePerParticipant() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())
        viewModel.startNewSplit()

        let item = ReceiptItem(rawText: "Soup 12.00", normalizedName: "Soup", unitPrice: decimal("12.00"), category: .main)
        viewModel.draft.items = [item]

        viewModel.shareWithEveryone(itemID: item.id)

        #expect(viewModel.draft.assignments.count == viewModel.draft.participants.count)
        #expect(viewModel.draft.items[0].assignmentMode == .shared)
    }

    @Test func connectAfterSharedResetsToSoleOwner() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())
        viewModel.startNewSplit()

        let item = ReceiptItem(rawText: "Soup 12.00", normalizedName: "Soup", unitPrice: decimal("12.00"), category: .main)
        viewModel.draft.items = [item]
        let you = viewModel.draft.participants[0]
        let alex = viewModel.draft.participants[1]

        viewModel.shareWithEveryone(itemID: item.id)
        viewModel.connect(itemID: item.id, to: you.id)

        #expect(viewModel.draft.assignments.count == 1)
        #expect(viewModel.isConnected(you.id, to: item.id))
        #expect(!viewModel.isConnected(alex.id, to: item.id))
        #expect(viewModel.draft.items[0].assignmentMode == .assigned)
    }

    @Test func clearConnectionsBlocksAdvanceWithCountMessage() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())
        viewModel.startNewSplit()
        viewModel.advance()
        viewModel.useSampleReceipt()
        viewModel.advance()
        viewModel.advance()
        #expect(viewModel.currentStep == .splitBoard)

        let padThai = viewModel.draft.items.first { $0.normalizedName == "Pad Thai" }!
        viewModel.shareWithEveryone(itemID: padThai.id)
        viewModel.clearConnections(itemID: padThai.id)

        #expect(viewModel.draft.assignments.filter { $0.receiptItemID == padThai.id }.isEmpty)
        #expect(viewModel.draft.items.first { $0.id == padThai.id }?.assignmentMode == .unassigned)

        viewModel.advance()
        #expect(viewModel.currentStep == .splitBoard)
        let count = viewModel.unassignedItems.count
        #expect(viewModel.validationMessage == "\(count) item\(count == 1 ? "" : "s") still need assignment.")
    }

    @Test func removingParticipantRecomputesAffectedItemModes() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())
        viewModel.startNewSplit()

        let item = ReceiptItem(rawText: "Soup 12.00", normalizedName: "Soup", unitPrice: decimal("12.00"), category: .main)
        viewModel.draft.items = [item]
        let you = viewModel.draft.participants[0]
        let alex = viewModel.draft.participants[1]

        viewModel.addParticipant()
        #expect(viewModel.draft.participants.count == 3)

        viewModel.connect(itemID: item.id, to: you.id)
        viewModel.connect(itemID: item.id, to: alex.id)
        #expect(viewModel.draft.items[0].assignmentMode == .split)

        viewModel.removeParticipant(id: alex.id)

        #expect(viewModel.draft.items[0].assignmentMode == .assigned)
        #expect(viewModel.isConnected(you.id, to: item.id))
    }

    @Test func connectionCaptionDescribesGroupSize() {
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: InMemorySessionRepository())
        viewModel.startNewSplit()
        viewModel.addParticipant()

        let item = ReceiptItem(rawText: "Soup 12.00", normalizedName: "Soup", unitPrice: decimal("12.00"), category: .main)
        viewModel.draft.items = [item]
        let you = viewModel.draft.participants[0]
        let alex = viewModel.draft.participants[1]

        viewModel.connect(itemID: item.id, to: you.id)
        #expect(viewModel.connectionCaption(for: item.id) == "You")

        viewModel.connect(itemID: item.id, to: alex.id)
        #expect(viewModel.connectionCaption(for: item.id) == "You + Alex · Split ½ each")

        viewModel.shareWithEveryone(itemID: item.id)
        #expect(viewModel.connectionCaption(for: item.id) == nil)
    }

    @Test func eachConnectionIntentPersistsDraft() {
        let repository = InMemorySessionRepository()
        let viewModel = AppFlowViewModel()
        viewModel.configure(repository: repository)
        viewModel.startNewSplit()

        let item = ReceiptItem(rawText: "Soup 12.00", normalizedName: "Soup", unitPrice: decimal("12.00"), category: .main)
        viewModel.draft.items = [item]
        let you = viewModel.draft.participants[0]

        viewModel.connect(itemID: item.id, to: you.id)
        #expect(repository.savedDraft?.assignments.count == 1)

        viewModel.shareWithEveryone(itemID: item.id)
        #expect(repository.savedDraft?.assignments.count == viewModel.draft.participants.count)

        viewModel.clearConnections(itemID: item.id)
        #expect(repository.savedDraft?.assignments.isEmpty == true)
    }
}

private func decimal(_ value: String) -> Decimal {
    Decimal(string: value)!
}
