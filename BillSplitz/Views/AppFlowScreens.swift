//
//  AppFlowScreens.swift
//  BillSplitz
//

import PhotosUI
import SwiftUI
import UIKit

struct AppStartView: View {
    var viewModel: AppFlowViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BSStartHero()

                VStack(spacing: 12) {
                    Button {
                        viewModel.startNewSplit()
                    } label: {
                        Text("NEW SPLIT")
                            .font(.bsBody(15, weight: .bold))
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(BSButtonStyle(background: .bsAccent, shadowOffset: 6))
                    .accessibilityIdentifier("start-new-split-button")

                    Button {
                        _ = viewModel.resumeSplit()
                    } label: {
                        BSContinueDraftLabel(
                            subtitle: viewModel.hasRecoverableSession ? viewModel.activeSessionTitle : "No saved draft yet",
                            enabled: viewModel.hasRecoverableSession
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.hasRecoverableSession)
                    .accessibilityIdentifier("continue-draft-button")
                }

                if let persistenceError = viewModel.persistenceError {
                    BSStatusStrip(text: persistenceError, style: .warning)
                }

                BSCard(title: "Flow") {
                    VStack(spacing: 10) {
                        ForEach(AppFlowStep.navigableSteps) { step in
                            BSFlowStepRow(step: step)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.bsPaper)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct BSStartHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BILLSPLITZ")
                .font(.bsDisplay(38))
                .foregroundStyle(Color.bsInk)
            Text("Split the receipt. Everyone pays their share — down to the cent.")
                .font(.bsBody(14))
                .foregroundStyle(Color.bsInkMuted)
        }
    }
}

private struct BSContinueDraftLabel: View {
    let subtitle: String
    let enabled: Bool

    var body: some View {
        Text(subtitle.isEmpty ? "CONTINUE DRAFT" : "CONTINUE DRAFT — \(subtitle)")
            .font(.bsBody(13, weight: .bold))
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(enabled ? Color.bsInk : Color.bsDisabledText)
            .background(enabled ? Color.bsCard : Color.bsDisabledFill)
            .overlay(
                Rectangle().stroke(enabled ? Color.bsInk : Color.bsDisabledText, lineWidth: BSBorder.card)
            )
            .modifier(BSConditionalShadow(offset: enabled ? 6 : 0))
    }
}

private struct BSConditionalShadow: ViewModifier {
    let offset: CGFloat

    func body(content: Content) -> some View {
        if offset > 0 {
            content.bsShadow(offset: offset)
        } else {
            content
        }
    }
}

private struct BSFlowStepRow: View {
    let step: AppFlowStep

    var body: some View {
        HStack(spacing: 12) {
            Text("\(step.stepNumber ?? 0)")
                .font(.bsBody(12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.bsInk)

            Text(step.title)
                .font(.bsBody(13, weight: .semibold))
                .foregroundStyle(Color.bsInk)

            Spacer()
        }
    }
}

struct AppFlowStepView: View {
    let step: AppFlowStep
    var viewModel: AppFlowViewModel

    var body: some View {
        // Split Board owns its own header/footer (see SplitBoardScreen) so its assign-mode
        // scrim and bubbles can cover the entire screen via .ignoresSafeArea() — nesting it
        // inside this VStack's 20pt padding would clip the overlay short of the real edges.
        if step == .splitBoard {
            SplitBoardScreen(viewModel: viewModel)
                .toolbar(.hidden, for: .navigationBar)
        } else {
            VStack(spacing: 16) {
                BSScreenHeader(step: step, onBack: { viewModel.moveBack() })

                ScrollView {
                    stepContent
                        .padding(.top, 4)
                }

                BSFlowFooter(step: step, viewModel: viewModel)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.bsPaper)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
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
            EmptyView()
        case .settlement:
            SettlementScreen(viewModel: viewModel)
        case .share:
            ShareScreen(viewModel: viewModel)
        }
    }
}

private struct SessionSetupScreen: View {
    @Bindable var viewModel: AppFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BSCard(title: "Session") {
                TextField("Split title", text: $viewModel.draft.session.title)
                    .textInputAutocapitalization(.words)
                    .font(.bsBody(14))
                    .padding(10)
                    .background(Color.bsCard)
                    .overlay(Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.control))
                    .accessibilityIdentifier("session-title-field")
            }

            BSCard(title: "Payer") {
                BSPayerFields(viewModel: viewModel)
            }

            BSCard(title: "Participants") {
                BSParticipantsList(viewModel: viewModel)
            }
        }
    }
}

private struct BSPayerFields: View {
    @Bindable var viewModel: AppFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            Picker("Payment method", selection: Binding<PaymentMethodType>(
                get: { viewModel.draft.payerPaymentMethod ?? .venmo },
                set: { viewModel.draft.payerPaymentMethod = $0 }
            )) {
                ForEach(PaymentMethodType.allCases, id: \.self) { paymentType in
                    Text(paymentType.displayName).tag(paymentType)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("payer-method-picker")

            TextField("Payment handle", text: Binding<String>(
                get: { viewModel.draft.payerPaymentHandle ?? "" },
                set: { viewModel.draft.payerPaymentHandle = $0.isEmpty ? nil : $0 }
            ))
            .textInputAutocapitalization(.never)
            .font(.bsBody(14))
            .padding(10)
            .background(Color.bsCard)
            .overlay(Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.control))
            .accessibilityIdentifier("payer-handle-field")

            Text("Covers the bill. Their payment details go in the shared summary so everyone knows where to send money.")
                .font(.bsBody(12, weight: .regular))
                .foregroundStyle(Color.bsInkMuted)
        }
    }
}

private struct BSParticipantsList: View {
    @Bindable var viewModel: AppFlowViewModel

    var body: some View {
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
                BSDashedButtonLabel(title: "Add Participant")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("add-participant-button")
        }
    }
}

private struct ReceiptCaptureScreen: View {
    @Bindable var viewModel: AppFlowViewModel
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BSCard(title: "Receipt Input") {
                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: $viewModel.draft.rawReceiptText)
                        .font(.bsMono(12.5))
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.bsPaperSunken)
                        .overlay(Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.control))
                        .accessibilityIdentifier("receipt-text-editor")

                    HStack(spacing: 10) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("CHOOSE PHOTO")
                                .font(.bsBody(12, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(BSButtonStyle(background: .bsCard, shadowOffset: 3, borderWidth: BSBorder.control))
                        .accessibilityIdentifier("choose-photo-button")
                        .onChange(of: selectedPhoto) { _, newValue in
                            if newValue != nil {
                                viewModel.notePhotoSelected()
                            }
                        }

                        Button {
                            viewModel.useSampleReceipt()
                        } label: {
                            Text("USE SAMPLE")
                                .font(.bsBody(12, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(BSButtonStyle(background: .bsCard, shadowOffset: 3, borderWidth: BSBorder.control))
                        .accessibilityIdentifier("use-sample-receipt-button")
                    }

                    Button {
                        viewModel.parseReceiptText()
                    } label: {
                        Text("PARSE RECEIPT")
                            .font(.bsBody(13, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(BSButtonStyle(background: .bsAccent, shadowOffset: 4))
                    .accessibilityIdentifier("parse-receipt-button")
                }
            }

            if let importedImageName = viewModel.draft.importedImageName {
                BSStatusStrip(text: importedImageName, style: .neutral)
            }
        }
    }
}

private struct BSTotalsRow: View {
    let label: String
    let value: String
    var emphasized: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(emphasized ? .bsBody(14, weight: .bold) : .bsBody(13, weight: .semibold))
                .foregroundStyle(Color.bsInk)
            Spacer()
            Text(value)
                .font(emphasized ? .bsBody(16, weight: .bold) : .bsMono(13))
                .foregroundStyle(Color.bsInk)
        }
    }
}

private struct ReceiptReviewScreen: View {
    @Bindable var viewModel: AppFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BSCard(title: "Totals") {
                VStack(alignment: .leading, spacing: 12) {
                    BSTotalsRow(label: "Items", value: viewModel.itemSubtotalText)
                    DecimalTextField(title: "Tax", value: $viewModel.draft.session.tax)
                        .accessibilityIdentifier("tax-field")
                    DecimalTextField(title: "Tip", value: $viewModel.draft.session.tip)
                        .accessibilityIdentifier("tip-field")
                    BSTotalsRow(label: "Receipt Total", value: viewModel.receiptTotalText, emphasized: true)
                }
            }

            BSCard(title: "Items") {
                VStack(spacing: 12) {
                    if viewModel.draft.items.isEmpty {
                        BSStatusStrip(text: "Parse receipt text or add items manually.", style: .neutral)
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
                        BSDashedButtonLabel(title: "Add Item")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("add-item-button")
                }
            }
        }
    }
}

private struct SettlementScreen: View {
    var viewModel: AppFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch viewModel.settlementState {
            case .ready(let lines):
                VStack(spacing: 12) {
                    ForEach(viewModel.draft.participants) { participant in
                        if let line = viewModel.settlementLine(for: participant.id, in: lines) {
                            SettlementLineCard(
                                participant: participant,
                                line: line,
                                currencyCode: viewModel.draft.session.currencyCode,
                                isPayer: participant.id == viewModel.draft.payerID
                            )
                        }
                    }

                    BSGrandTotalBar(amountText: viewModel.receiptTotalText)
                }
            case .blocked(let message):
                BSStatusStrip(text: message, style: .warning)
            }
        }
    }
}

private struct BSGrandTotalBar: View {
    let amountText: String

    var body: some View {
        HStack {
            Text("RECEIPT TOTAL")
                .font(.bsBody(13, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(.white)

            Spacer()

            Text(amountText)
                .font(.bsDisplay(18))
                .foregroundStyle(Color.bsAccent)
        }
        .padding(14)
        .background(Color.bsInk)
    }
}

private struct ShareScreen: View {
    var viewModel: AppFlowViewModel
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BSCard(title: "The Damage") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.shareText)
                        .font(.bsMono(11.5))
                        .foregroundStyle(Color.bsInk)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.bsPaperSunken)
                        .accessibilityIdentifier("share-summary-text")

                    HStack(spacing: 12) {
                        ShareLink(item: viewModel.shareText) {
                            Text("SHARE SUMMARY")
                                .font(.bsBody(13, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(BSButtonStyle(background: .bsAccent, shadowOffset: 4))
                        .accessibilityIdentifier("share-summary-button")

                        Button {
                            UIPasteboard.general.string = viewModel.shareText
                            copied = true
                        } label: {
                            Text(copied ? "COPIED" : "COPY")
                                .font(.bsBody(13, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(BSButtonStyle(background: .bsCard, shadowOffset: 4))
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
        HStack {
            TextField("Name", text: $participant.name)
                .font(.bsBody(14))
                .padding(10)
                .background(Color.bsCard)
                .overlay(Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.control))

            Button(action: onDelete) {
                Text("✕")
                    .font(.bsBody(15, weight: .bold))
                    .foregroundStyle(canDelete ? .white : Color.bsDisabledText)
                    .frame(width: 44, height: 44)
                    .background(canDelete ? Color.bsDanger : Color.bsDisabledFill)
                    .overlay(Rectangle().stroke(canDelete ? Color.bsInk : Color.bsDisabledText, lineWidth: BSBorder.control))
            }
            .disabled(!canDelete)
            .accessibilityLabel("Remove \(participant.name)")
        }
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
                    .font(.bsBody(14))
                    .padding(10)
                    .background(Color.bsCard)
                    .overlay(Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.control))

                Button(action: onDelete) {
                    Text("✕")
                        .font(.bsBody(15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.bsDanger)
                        .overlay(Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.control))
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
        .padding(10)
        .background(Color.bsPaperSunken)
        .overlay(Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.tag))
    }
}

private struct SettlementLineCard: View {
    let participant: Participant
    let line: SettlementLine
    let currencyCode: String
    let isPayer: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(participant.name)
                    .font(.bsDisplay(14))
                    .textCase(.uppercase)
                Spacer()
                Text(CurrencyFormatter.string(for: line.grandTotal, currencyCode: currencyCode))
                    .font(.bsDisplay(18))
            }
            .foregroundStyle(Color.bsInk)

            Text(
                "ITEMS \(CurrencyFormatter.string(for: line.itemSubtotal, currencyCode: currencyCode)) · " +
                "TAX \(CurrencyFormatter.string(for: line.taxShare, currencyCode: currencyCode)) · " +
                "TIP \(CurrencyFormatter.string(for: line.tipShare, currencyCode: currencyCode))"
            )
            .font(.bsBody(11, weight: .bold))
            .textCase(.uppercase)
            .foregroundStyle(Color.bsInkMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isPayer ? Color.bsAccent : Color.bsCard)
        .overlay(Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.card))
        .bsShadow(offset: 6)
    }
}

