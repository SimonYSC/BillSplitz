//
//  AppFlowViewModelTests.swift
//  BillSplitzTests
//

import Testing
@testable import BillSplitz

@MainActor
struct AppFlowViewModelTests {
    @Test func startingNewSplitCreatesDraftAtSetup() {
        let viewModel = AppFlowViewModel()

        viewModel.startNewSplit()

        #expect(viewModel.currentStep == .sessionSetup)
        #expect(viewModel.path == [.sessionSetup])
        #expect(viewModel.activeSession?.title == "Sushi Night")
        #expect(viewModel.activeSession?.status == .draft)
        #expect(viewModel.hasRecoverableSession)
    }

    @Test func advancingMovesThroughMVPFlowInOrder() {
        let viewModel = AppFlowViewModel()

        viewModel.startNewSplit()
        viewModel.advance()
        #expect(viewModel.currentStep == .receiptCapture)
        #expect(viewModel.activeSession?.status == .draft)

        viewModel.advance()
        #expect(viewModel.currentStep == .receiptReview)
        #expect(viewModel.activeSession?.status == .reviewingReceipt)

        viewModel.advance()
        #expect(viewModel.currentStep == .splitBoard)
        #expect(viewModel.activeSession?.status == .splittingItems)

        viewModel.advance()
        #expect(viewModel.currentStep == .settlement)
        #expect(viewModel.activeSession?.status == .settled)

        viewModel.advance()
        #expect(viewModel.currentStep == .share)
        #expect(viewModel.activeSession?.status == .settled)
    }

    @Test func resumeReturnsToMostRecentFlowStep() {
        let viewModel = AppFlowViewModel()

        viewModel.startNewSplit()
        viewModel.advance()
        viewModel.advance()
        viewModel.returnToStart()

        #expect(viewModel.currentStep == .start)
        #expect(viewModel.resumeSplit())
        #expect(viewModel.currentStep == .receiptReview)
    }

    @Test func finishingShareClearsActiveDraft() {
        let viewModel = AppFlowViewModel()

        viewModel.startNewSplit()
        while viewModel.currentStep.next != nil {
            viewModel.advance()
        }
        viewModel.finishSharing()

        #expect(viewModel.currentStep == .start)
        #expect(viewModel.activeSession == nil)
        #expect(!viewModel.hasRecoverableSession)
        #expect(!viewModel.resumeSplit())
    }
}
