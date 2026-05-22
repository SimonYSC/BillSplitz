//
//  AppFlowViewModel.swift
//  BillSplitz
//

import Foundation
import Observation

enum AppFlowStep: String, CaseIterable, Hashable, Identifiable {
    case start
    case sessionSetup
    case receiptCapture
    case receiptReview
    case splitBoard
    case settlement
    case share

    var id: Self { self }

    static let navigableSteps: [AppFlowStep] = [
        .sessionSetup,
        .receiptCapture,
        .receiptReview,
        .splitBoard,
        .settlement,
        .share
    ]

    var title: String {
        switch self {
        case .start:
            "Start"
        case .sessionSetup:
            "Session Setup"
        case .receiptCapture:
            "Receipt Capture"
        case .receiptReview:
            "Receipt Review"
        case .splitBoard:
            "Split Board"
        case .settlement:
            "Settlement"
        case .share:
            "Share"
        }
    }

    var systemImage: String {
        switch self {
        case .start:
            "rectangle.stack.badge.play"
        case .sessionSetup:
            "person.3.sequence.fill"
        case .receiptCapture:
            "camera.viewfinder"
        case .receiptReview:
            "list.bullet.clipboard"
        case .splitBoard:
            "square.grid.2x2"
        case .settlement:
            "dollarsign.arrow.circlepath"
        case .share:
            "square.and.arrow.up"
        }
    }

    var next: AppFlowStep? {
        guard let index = Self.navigableSteps.firstIndex(of: self) else {
            return .sessionSetup
        }

        return Self.navigableSteps.indices.contains(index + 1) ? Self.navigableSteps[index + 1] : nil
    }

    var previous: AppFlowStep? {
        guard let index = Self.navigableSteps.firstIndex(of: self), index > 0 else {
            return nil
        }

        return Self.navigableSteps[index - 1]
    }

    var stepNumber: Int? {
        guard let index = Self.navigableSteps.firstIndex(of: self) else {
            return nil
        }

        return index + 1
    }
}

@MainActor
@Observable
final class AppFlowViewModel {
    var path: [AppFlowStep] = []
    private(set) var activeSession: SplitSession?
    private(set) var recoverableStep: AppFlowStep = .sessionSetup

    var currentStep: AppFlowStep {
        path.last ?? .start
    }

    var hasRecoverableSession: Bool {
        activeSession != nil
    }

    var activeSessionTitle: String {
        activeSession?.title ?? "No active split"
    }

    func startNewSplit() {
        activeSession = SplitSession(title: "Sushi Night", status: .draft)
        show(.sessionSetup)
    }

    @discardableResult
    func resumeSplit() -> Bool {
        guard hasRecoverableSession else {
            return false
        }

        show(recoverableStep)
        return true
    }

    func advance() {
        guard let nextStep = currentStep.next else {
            return
        }

        show(nextStep)
    }

    func moveBack() {
        guard let previousStep = currentStep.previous else {
            returnToStart()
            return
        }

        show(previousStep)
    }

    func returnToStart() {
        path = []
    }

    func finishSharing() {
        activeSession = nil
        recoverableStep = .sessionSetup
        path = []
    }

    private func show(_ step: AppFlowStep) {
        if activeSession == nil {
            activeSession = SplitSession(title: "Sushi Night", status: .draft)
        }

        path = [step]
        recoverableStep = step
        updateSessionStatus(for: step)
    }

    private func updateSessionStatus(for step: AppFlowStep) {
        switch step {
        case .start, .sessionSetup, .receiptCapture:
            activeSession?.status = .draft
        case .receiptReview:
            activeSession?.status = .reviewingReceipt
        case .splitBoard:
            activeSession?.status = .splittingItems
        case .settlement, .share:
            activeSession?.status = .settled
        }
    }
}
