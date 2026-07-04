//
//  AppFlowScreens.swift
//  BillSplitz
//

import PhotosUI
import SwiftUI
import UIKit

struct AppStartView: View {
    @ObservedObject var viewModel: AppFlowViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("BillSplitz")
                        .font(.largeTitle.bold())
                    Text("Create a receipt split, assign items, settle totals, and share who owes what.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    Button {
                        viewModel.startNewSplit()
                    } label: {
                        FlowActionLabel(
                            title: "New Split",
                            subtitle: "Start a local receipt split",
                            systemImage: "plus.circle.fill"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("start-new-split-button")

                    Button {
                        _ = viewModel.resumeSplit()
                    } label: {
                        FlowActionLabel(
                            title: "Continue Draft",
                            subtitle: viewModel.hasRecoverableSession ? viewModel.activeSessionTitle : "No saved draft yet",
                            systemImage: "arrow.clockwise.circle.fill"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.hasRecoverableSession)
                    .accessibilityIdentifier("continue-draft-button")
                }

                if let persistenceError = viewModel.persistenceError {
                    StatusMessage(text: persistenceError, style: .warning)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Flow")
                        .font(.headline)
                    ForEach(AppFlowStep.navigableSteps) { step in
                        FlowStepRow(step: step)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Start")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppFlowStepView: View {
    let step: AppFlowStep
    @ObservedObject var viewModel: AppFlowViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FlowStepHeader(step: step)

                switch step {
                case .start:
                    EmptyView()
                case .sessionSetup:
                    SessionSetupScreen(viewModel: viewModel)
                case .receiptCapture:
                    ReceiptCaptureScreen(viewModel: viewModel)
                case .receiptReview:
                    ReceiptReviewScreen(viewModel: viewModel)
                case .splitBoard:
                    SplitBoardScreen(viewModel: viewModel)
                case .settlement:
                    SettlementScreen(viewModel: viewModel)
                case .share:
                    ShareScreen(viewModel: viewModel)
                }

                FlowFooter(step: step, viewModel: viewModel)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(step.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Start") {
                    viewModel.returnToStart()
                }
            }
        }
    }
}

private struct SessionSetupScreen: View {
    @ObservedObject var viewModel: AppFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionPanel(title: "Session") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Split title", text: $viewModel.draft.session.title)
                        .textInputAutocapitalization(.words)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("session-title-field")

                    Picker("Paid by", selection: Binding<UUID?>(
                        get: { viewModel.draft.payerID },
                        set: { viewModel.draft.payerID = $0 }
                    )) {
                        ForEach(viewModel.draft.participants) { participant in
                            Text(participant.name).tag(Optional(participant.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("payer-picker")
                }
            }

            SectionPanel(title: "Participants") {
                VStack(spacing: 12) {
                    ForEach($viewModel.draft.participants) { $participant in
                        ParticipantEditorRow(
                            participant: $participant,
                            canDelete: viewModel.draft.participants.count > 2
                        ) {
                            viewModel.removeParticipant(id: participant.id)
                        }
                    }

                    Button {
                        viewModel.addParticipant()
                    } label: {
                        Label("Add Participant", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("add-participant-button")
                }
            }
        }
    }
}

private struct ReceiptCaptureScreen: View {
    @ObservedObject var viewModel: AppFlowViewModel
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionPanel(title: "Receipt Input") {
                VStack(alignment: .leading, spacing: 12) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose Photo", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("choose-photo-button")
                    .onChange(of: selectedPhoto) { _, newValue in
                        if newValue != nil {
                            viewModel.notePhotoSelected()
                        }
                    }

                    TextEditor(text: $viewModel.draft.rawReceiptText)
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        }
                        .accessibilityIdentifier("receipt-text-editor")

                    HStack(spacing: 12) {
                        Button {
                            viewModel.useSampleReceipt()
                        } label: {
                            Label("Use Sample", systemImage: "doc.text")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("use-sample-receipt-button")

                        Button {
                            viewModel.parseReceiptText()
                        } label: {
                            Label("Parse Receipt", systemImage: "text.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("parse-receipt-button")
                    }
                }
            }

            if let importedImageName = viewModel.draft.importedImageName {
                StatusMessage(text: importedImageName, style: .neutral)
            }
        }
    }
}

private struct ReceiptReviewScreen: View {
    @ObservedObject var viewModel: AppFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionPanel(title: "Totals") {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("Items", value: viewModel.itemSubtotalText)
                    DecimalTextField(title: "Tax", value: $viewModel.draft.session.tax)
                        .accessibilityIdentifier("tax-field")
                    DecimalTextField(title: "Tip", value: $viewModel.draft.session.tip)
                        .accessibilityIdentifier("tip-field")
                    LabeledContent("Receipt Total", value: viewModel.receiptTotalText)
                }
            }

            SectionPanel(title: "Items") {
                VStack(spacing: 12) {
                    if viewModel.draft.items.isEmpty {
                        StatusMessage(text: "Parse receipt text or add items manually.", style: .neutral)
                    }

                    ForEach($viewModel.draft.items) { $item in
                        ReceiptItemEditorRow(item: $item) {
                            viewModel.deleteReceiptItem(id: item.id)
                        } onSubtotalChanged: {
                            viewModel.refreshReceiptSubtotal()
                        }
                    }

                    Button {
                        viewModel.addReceiptItem()
                    } label: {
                        Label("Add Item", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("add-item-button")
                }
            }
        }
    }
}

private struct SplitBoardScreen: View {
    @ObservedObject var viewModel: AppFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionPanel(title: "Preset") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Appetizers, desserts, and adjustments are shared. Mains and drinks stay assignable.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        viewModel.applyDefaultPreset()
                    } label: {
                        Label("Apply Meal Preset", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("apply-preset-button")
                }
            }

            if !viewModel.unassignedItems.isEmpty {
                StatusMessage(
                    text: "\(viewModel.unassignedItems.count) item\(viewModel.unassignedItems.count == 1 ? "" : "s") still need assignment.",
                    style: .warning
                )
            }

            ForEach(viewModel.draft.items) { item in
                SplitItemCard(item: item, viewModel: viewModel)
            }
        }
    }
}

private struct SettlementScreen: View {
    @ObservedObject var viewModel: AppFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch viewModel.settlementState {
            case .ready(let lines):
                SectionPanel(title: "Settlement") {
                    VStack(spacing: 12) {
                        ForEach(viewModel.draft.participants) { participant in
                            if let line = viewModel.settlementLine(for: participant.id, in: lines) {
                                SettlementLineRow(
                                    participant: participant,
                                    line: line,
                                    currencyCode: viewModel.draft.session.currencyCode
                                )
                            }
                        }

                        Divider()
                        LabeledContent("Receipt Total", value: viewModel.receiptTotalText)
                            .font(.headline)
                    }
                }
            case .blocked(let message):
                StatusMessage(text: message, style: .warning)
            }
        }
    }
}

private struct ShareScreen: View {
    @ObservedObject var viewModel: AppFlowViewModel
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionPanel(title: "Plain Text Summary") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.shareText)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("share-summary-text")

                    HStack(spacing: 12) {
                        ShareLink(item: viewModel.shareText) {
                            Label("Share Summary", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("share-summary-button")

                        Button {
                            UIPasteboard.general.string = viewModel.shareText
                            copied = true
                        } label: {
                            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("copy-summary-button")
                    }
                }
            }
        }
    }
}

private struct ParticipantEditorRow: View {
    @Binding var participant: Participant
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Name", text: $participant.name)
                    .textFieldStyle(.roundedBorder)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(!canDelete)
                .accessibilityLabel("Remove \(participant.name)")
            }

            HStack(spacing: 10) {
                Picker("Payment", selection: Binding<PaymentMethodType>(
                    get: { participant.paymentMethodType ?? .venmo },
                    set: { participant.paymentMethodType = $0 }
                )) {
                    ForEach(PaymentMethodType.allCases, id: \.self) { paymentType in
                        Text(paymentType.displayName).tag(paymentType)
                    }
                }
                .pickerStyle(.menu)

                TextField("Payment handle", text: Binding<String>(
                    get: { participant.paymentHandle ?? "" },
                    set: { participant.paymentHandle = $0.isEmpty ? nil : $0 }
                ))
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ReceiptItemEditorRow: View {
    @Binding var item: ReceiptItem
    let onDelete: () -> Void
    let onSubtotalChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Item name", text: $item.normalizedName)
                    .textFieldStyle(.roundedBorder)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete \(item.normalizedName)")
            }

            HStack(spacing: 10) {
                DecimalTextField(title: "Price", value: $item.unitPrice)
                    .onChange(of: item.unitPrice) { _, _ in
                        onSubtotalChanged()
                    }

                Picker("Category", selection: $item.category) {
                    ForEach(ReceiptItemCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SplitItemCard: View {
    let item: ReceiptItem
    @ObservedObject var viewModel: AppFlowViewModel

    var body: some View {
        SectionPanel(title: item.normalizedName) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(item.category.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(CurrencyFormatter.string(for: item.totalPrice, currencyCode: viewModel.draft.session.currencyCode))
                        .font(.headline)
                }

                HStack(spacing: 8) {
                    AssignmentModeButton(title: "Shared", isSelected: item.assignmentMode == .shared) {
                        viewModel.setAssignmentMode(itemID: item.id, mode: .shared)
                    }
                    .accessibilityIdentifier("mode-\(item.normalizedName)-shared")
                    AssignmentModeButton(title: "Assigned", isSelected: item.assignmentMode == .assigned) {
                        viewModel.setAssignmentMode(itemID: item.id, mode: .assigned)
                    }
                    .accessibilityIdentifier("mode-\(item.normalizedName)-assigned")
                    AssignmentModeButton(title: "Split", isSelected: item.assignmentMode == .split) {
                        viewModel.setAssignmentMode(itemID: item.id, mode: .split)
                    }
                    .accessibilityIdentifier("mode-\(item.normalizedName)-split")
                }

                FlowTokenWrap {
                    ForEach(viewModel.draft.participants) { participant in
                        ParticipantAssignmentButton(
                            participant: participant,
                            item: item,
                            isSelected: viewModel.isParticipant(participant.id, assignedTo: item.id)
                        ) {
                            viewModel.selectParticipantForAssignment(itemID: item.id, participantID: participant.id)
                        }
                    }
                }

                if !viewModel.draft.assignments.contains(where: { $0.receiptItemID == item.id }) {
                    Text("Unassigned")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

private struct ParticipantAssignmentButton: View {
    let participant: Participant
    let item: ReceiptItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .imageScale(.small)
                }

                Text(participant.name)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
        }
        .buttonStyle(.plain)
        .background(backgroundColor)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(isSelected ? backgroundColor : Color(.separator), lineWidth: 1)
        }
        .accessibilityIdentifier("assign-\(item.normalizedName)-\(participant.name)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var backgroundColor: Color {
        guard isSelected else {
            return Color(.tertiarySystemGroupedBackground)
        }

        return item.assignmentMode == .shared ? .green : .blue
    }
}

private struct AssignmentModeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(isSelected ? .blue : .secondary)
    }
}

private struct SettlementLineRow: View {
    let participant: Participant
    let line: SettlementLine
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(participant.name)
                    .font(.headline)
                Spacer()
                Text(CurrencyFormatter.string(for: line.grandTotal, currencyCode: currencyCode))
                    .font(.headline)
            }

            HStack {
                Text("Items \(CurrencyFormatter.string(for: line.itemSubtotal, currencyCode: currencyCode))")
                Spacer()
                Text("Tax \(CurrencyFormatter.string(for: line.taxShare, currencyCode: currencyCode))")
                Spacer()
                Text("Tip \(CurrencyFormatter.string(for: line.tipShare, currencyCode: currencyCode))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DecimalTextField: View {
    let title: String
    @Binding var value: Decimal

    var body: some View {
        TextField(title, text: Binding<String>(
            get: { CurrencyFormatter.editableString(for: value) },
            set: { newValue in
                if let decimal = CurrencyFormatter.decimal(from: newValue) {
                    value = decimal
                }
            }
        ))
        .keyboardType(.numbersAndPunctuation)
        .textFieldStyle(.roundedBorder)
    }
}

private struct FlowActionLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        }
    }
}

private struct FlowStepRow: View {
    let step: AppFlowStep

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: step.systemImage)
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
            Text(step.title)
                .font(.body)
            Spacer()
            Text("\(step.stepNumber ?? 0)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(Circle())
        }
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct FlowStepHeader: View {
    let step: AppFlowStep

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: step.systemImage)
                    .foregroundStyle(.blue)
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Circle())
                Text(step.title)
                    .font(.title2.bold())
            }

            ProgressView(value: Double(step.stepNumber ?? 1), total: Double(AppFlowStep.navigableSteps.count))
                .tint(.blue)

            Text("Step \(step.stepNumber ?? 1) of \(AppFlowStep.navigableSteps.count)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct FlowFooter: View {
    let step: AppFlowStep
    let viewModel: AppFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let validationMessage = viewModel.validationMessage {
                StatusMessage(text: validationMessage, style: .warning)
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.moveBack()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.advance()
                } label: {
                    Label(step.next == nil ? "Done" : "Next", systemImage: step.next == nil ? "checkmark" : "chevron.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("flow-next-button")
            }
            .controlSize(.large)
        }
    }
}

private struct SectionPanel<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        }
    }
}

private enum StatusMessageStyle {
    case neutral
    case warning
}

private struct StatusMessage: View {
    let text: String
    let style: StatusMessageStyle

    var body: some View {
        Label(text, systemImage: style == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
            .font(.subheadline)
            .foregroundStyle(style == .warning ? .orange : .secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct FlowTokenWrap<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
    }
}
