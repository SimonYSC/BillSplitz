//
//  AppFlowViewModel.swift
//  BillSplitz
//

import Foundation
import Observation

enum AppFlowStep: String, CaseIterable, Hashable, Identifiable, Codable {
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

enum SettlementViewState: Equatable {
    case ready([SettlementLine])
    case blocked(String)
}

@MainActor
@Observable
final class AppFlowViewModel {
    var path: [AppFlowStep] = []
    var draft: SplitDraft = .blank()
    private(set) var hasRecoverableSession = false
    private(set) var validationMessage: String?
    private(set) var persistenceError: String?

    private var repository: SessionRepository?
    private var isConfigured = false
    private let parser = ReceiptParserService()
    private let splitRuleEngine = SplitRuleEngine()
    private let settlementCalculator = SettlementCalculator()
    private let shareExportService = ShareExportService()

    var currentStep: AppFlowStep {
        path.last ?? .start
    }

    var activeSessionTitle: String {
        hasRecoverableSession ? draft.session.title : "No active split"
    }

    var itemSubtotalText: String {
        CurrencyFormatter.string(for: draft.itemSubtotal, currencyCode: draft.session.currencyCode)
    }

    var receiptTotalText: String {
        CurrencyFormatter.string(for: draft.receiptTotal, currencyCode: draft.session.currencyCode)
    }

    var unassignedItems: [ReceiptItem] {
        draft.items.filter { item in
            !draft.assignments.contains { $0.receiptItemID == item.id }
        }
    }

    var settlementState: SettlementViewState {
        do {
            let lines = try settlementCalculator.calculate(
                session: draft.session,
                participants: draft.participants,
                items: draft.items,
                assignments: draft.assignments
            )
            return .ready(lines)
        } catch {
            return .blocked(message(for: error))
        }
    }

    var shareText: String {
        switch settlementState {
        case .ready(let lines):
            shareExportService.plainTextSummary(draft: draft, settlementLines: lines)
        case .blocked(let message):
            "BillSplitz summary is not ready.\n\(message)"
        }
    }

    func configure(repository: SessionRepository) {
        guard !isConfigured else {
            return
        }

        self.repository = repository
        isConfigured = true

        do {
            if let savedDraft = try repository.loadActiveDraft() {
                draft = savedDraft
                hasRecoverableSession = true
            }
        } catch {
            persistenceError = "Could not load saved split."
        }
    }

    func startNewSplit() {
        draft = .blank()
        hasRecoverableSession = true
        validationMessage = nil
        show(.sessionSetup)
    }

    @discardableResult
    func resumeSplit() -> Bool {
        guard hasRecoverableSession else {
            return false
        }

        validationMessage = nil
        show(draft.recoverableStep)
        return true
    }

    func advance() {
        guard validateCurrentStep() else {
            return
        }

        if currentStep == .receiptCapture {
            let trimmedText = draft.rawReceiptText.trimmingCharacters(in: .whitespacesAndNewlines)
            let needsParse = !trimmedText.isEmpty && (draft.items.isEmpty || trimmedText != (draft.parsedReceiptText ?? ""))

            if needsParse, !parseReceiptText() {
                return
            }
        }

        if currentStep == .receiptReview, draft.assignments.isEmpty {
            applyDefaultPreset()
        }

        guard let nextStep = currentStep.next else {
            finishSharing()
            return
        }

        show(nextStep)
    }

    func moveBack() {
        validationMessage = nil

        guard let previousStep = currentStep.previous else {
            returnToStart()
            return
        }

        show(previousStep)
    }

    func returnToStart() {
        validationMessage = nil
        path = []
        persistDraft()
    }

    func finishSharing() {
        draft.session.status = .settled
        hasRecoverableSession = false
        validationMessage = nil
        path = []
        draft = .blank()

        do {
            try repository?.clearActiveDraft()
        } catch {
            persistenceError = "Could not clear saved split."
        }
    }

    func persistDraft() {
        guard hasRecoverableSession else {
            return
        }

        do {
            try repository?.saveActiveDraft(draft)
            persistenceError = nil
        } catch {
            persistenceError = "Could not save split."
        }
    }

    func useSampleReceipt() {
        draft.session.title = "Thai Night — Basil House"
        draft.rawReceiptText = """
        Spring Rolls 8.50
        Pad Thai 16.50
        Green Curry 17.00
        Thai Iced Tea 5.50
        Mango Sticky Rice 9.00
        Tax 4.75
        Tip 11.30
        """
        parseReceiptText()
    }

    func notePhotoSelected() {
        draft.importedImageName = "Photo selected for OCR review"
        validationMessage = "Photo noted for OCR review. OCR isn't wired yet — type the receipt text or add items manually on the next screen."
    }

    @discardableResult
    func parseReceiptText() -> Bool {
        let result = parser.parse(draft.rawReceiptText)
        guard !result.items.isEmpty else {
            validationMessage = "Add at least one receipt line with a price."
            return false
        }

        draft.items = result.items
        draft.assignments = []
        draft.session.subtotal = draft.itemSubtotal
        draft.session.tax = result.tax
        draft.session.tip = result.tip
        draft.session.status = .reviewingReceipt
        draft.parsedAt = .now
        draft.parsedReceiptText = draft.rawReceiptText.trimmingCharacters(in: .whitespacesAndNewlines)
        validationMessage = nil
        persistDraft()
        return true
    }

    func addParticipant() {
        let participant = Participant(name: "Person \(draft.participants.count + 1)")
        draft.participants.append(participant)

        if draft.payerID == nil {
            draft.payerID = participant.id
        }
    }

    func removeParticipant(id: UUID) {
        guard draft.participants.count > 2 else {
            validationMessage = "Keep at least two participants."
            return
        }

        let affectedItemIDs = Set(draft.assignments.filter { $0.participantID == id }.map(\.receiptItemID))

        draft.participants.removeAll { $0.id == id }
        draft.assignments.removeAll { $0.participantID == id }

        for itemID in affectedItemIDs {
            recomputeAssignmentMode(for: itemID)
        }

        if draft.payerID == id {
            draft.payerID = draft.participants.first?.id
        }
    }

    func addReceiptItem() {
        let item = ReceiptItem(
            rawText: "",
            normalizedName: "New item",
            unitPrice: 0,
            category: .main,
            assignmentMode: .unassigned
        )
        draft.items.append(item)
        draft.session.subtotal = draft.itemSubtotal
    }

    func deleteReceiptItem(id: UUID) {
        draft.items.removeAll { $0.id == id }
        draft.assignments.removeAll { $0.receiptItemID == id }
        draft.session.subtotal = draft.itemSubtotal
    }

    func refreshReceiptSubtotal() {
        draft.session.subtotal = draft.itemSubtotal
    }

    func applyDefaultPreset() {
        let result = splitRuleEngine.applyMealDefault(
            items: draft.items,
            participants: draft.participants
        )
        draft.items = result.items
        draft.assignments = result.assignments
        validationMessage = nil
        persistDraft()
    }

    func connect(itemID: UUID, to participantID: UUID) {
        let connectedParticipantIDs = Set(draft.assignments.filter { $0.receiptItemID == itemID }.map(\.participantID))

        // A drop on one person after a mistaken All-drop must give sole ownership,
        // not add a third connection on top of full coverage.
        if !draft.participants.isEmpty, connectedParticipantIDs.count == draft.participants.count {
            draft.assignments.removeAll { $0.receiptItemID == itemID }
        } else if connectedParticipantIDs.contains(participantID) {
            recomputeAssignmentMode(for: itemID)
            validationMessage = nil
            persistDraft()
            return
        }

        draft.assignments.append(ItemAssignment(receiptItemID: itemID, participantID: participantID, shareRatio: 1))
        recomputeAssignmentMode(for: itemID)
        validationMessage = nil
        persistDraft()
    }

    func shareWithEveryone(itemID: UUID) {
        draft.assignments.removeAll { $0.receiptItemID == itemID }
        draft.assignments += draft.participants.map {
            ItemAssignment(receiptItemID: itemID, participantID: $0.id, shareRatio: 1)
        }
        recomputeAssignmentMode(for: itemID)
        validationMessage = nil
        persistDraft()
    }

    func clearConnections(itemID: UUID) {
        draft.assignments.removeAll { $0.receiptItemID == itemID }
        recomputeAssignmentMode(for: itemID)
        validationMessage = nil
        persistDraft()
    }

    func isConnected(_ participantID: UUID, to itemID: UUID) -> Bool {
        draft.assignments.contains {
            $0.receiptItemID == itemID && $0.participantID == participantID
        }
    }

    func connectionCaption(for itemID: UUID) -> String? {
        let connectedIDs = draft.assignments.filter { $0.receiptItemID == itemID }.map(\.participantID)
        guard !connectedIDs.isEmpty, connectedIDs.count != draft.participants.count else {
            return nil
        }

        let connectedIDSet = Set(connectedIDs)
        let names = draft.participants.filter { connectedIDSet.contains($0.id) }.map(\.name)

        guard names.count > 1 else {
            return names.first
        }

        let splitSuffix = names.count == 2 ? " · Split ½ each" : " · Split evenly"
        return names.joined(separator: " + ") + splitSuffix
    }

    func settlementLine(for participantID: UUID, in lines: [SettlementLine]) -> SettlementLine? {
        lines.first { $0.participantID == participantID }
    }

    // Full coverage IS shared: connecting every participant one-by-one reads identically
    // to shareWithEveryone, because assignments are the single source of truth for mode.
    private func recomputeAssignmentMode(for itemID: UUID) {
        guard let index = draft.items.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        let connectedCount = Set(draft.assignments.filter { $0.receiptItemID == itemID }.map(\.participantID)).count

        switch connectedCount {
        case 0:
            draft.items[index].assignmentMode = .unassigned
        case 1:
            draft.items[index].assignmentMode = .assigned
        case draft.participants.count:
            draft.items[index].assignmentMode = .shared
        default:
            draft.items[index].assignmentMode = .split
        }
    }

    private func show(_ step: AppFlowStep) {
        path = [step]
        draft.recoverableStep = step
        updateSessionStatus(for: step)
        persistDraft()
    }

    private func validateCurrentStep() -> Bool {
        switch currentStep {
        case .start:
            validationMessage = nil
        case .sessionSetup:
            guard !draft.session.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                validationMessage = "Name this split before continuing."
                return false
            }

            let namedParticipants = draft.participants.filter {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            guard namedParticipants.count >= 2 else {
                validationMessage = "Add at least two participants."
                return false
            }

            if draft.payerID == nil {
                draft.payerID = draft.participants.first?.id
            }
        case .receiptCapture:
            let hasText = !draft.rawReceiptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasItems = !draft.items.isEmpty
            let hasPhoto = draft.importedImageName != nil

            if !hasText && !hasItems && !hasPhoto {
                validationMessage = "Paste receipt text, choose a photo, or add items manually."
                return false
            }
        case .receiptReview:
            guard !draft.items.isEmpty else {
                validationMessage = "Review needs at least one receipt item."
                return false
            }

            guard draft.items.allSatisfy({ !$0.normalizedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                validationMessage = "Every item needs a name."
                return false
            }
        case .splitBoard:
            if !unassignedItems.isEmpty {
                validationMessage = "\(unassignedItems.count) item\(unassignedItems.count == 1 ? "" : "s") still need assignment."
                return false
            }
        case .settlement:
            if case .blocked(let message) = settlementState {
                validationMessage = message
                return false
            }
        case .share:
            break
        }

        validationMessage = nil
        return true
    }

    private func updateSessionStatus(for step: AppFlowStep) {
        switch step {
        case .start, .sessionSetup, .receiptCapture:
            draft.session.status = .draft
        case .receiptReview:
            draft.session.status = .reviewingReceipt
        case .splitBoard, .settlement, .share:
            draft.session.status = .splittingItems
        }
    }

    private func message(for error: Error) -> String {
        guard let calculationError = error as? SettlementCalculationError else {
            return "Settlement could not be calculated."
        }

        switch calculationError {
        case .noParticipants:
            return "Add at least one participant."
        case .unassignedReceiptItem:
            return "Every receipt item must be assigned before settlement."
        case .missingParticipant:
            return "One assignment points to a participant that no longer exists."
        case .invalidShareRatio:
            return "One assignment has an invalid split ratio."
        case .zeroAllocationBase:
            return "Tax and tip need at least one item subtotal to allocate against."
        }
    }
}
