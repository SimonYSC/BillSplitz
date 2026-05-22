//
//  AppFlowScreens.swift
//  BillSplitz
//

import SwiftUI

struct AppStartView: View {
    let viewModel: AppFlowViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("BillSplitz")
                        .font(.largeTitle.bold())
                    Text("Create a receipt split, review the items, settle totals, and share the result.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    Button {
                        viewModel.startNewSplit()
                    } label: {
                        FlowActionLabel(
                            title: "New Split",
                            subtitle: "Start a draft receipt split",
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
    let viewModel: AppFlowViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FlowStepHeader(step: step)
                FlowPreview(step: step)
                FlowFooter(step: step, viewModel: viewModel)
            }
            .padding(24)
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

private struct FlowPreview: View {
    let step: AppFlowStep

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch step {
            case .start:
                EmptyView()
            case .sessionSetup:
                setupPreview
            case .receiptCapture:
                receiptCapturePreview
            case .receiptReview:
                receiptReviewPreview
            case .splitBoard:
                splitBoardPreview
            case .settlement:
                settlementPreview
            case .share:
                sharePreview
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var setupPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowField(label: "Title", value: "Sushi Night")
            FlowField(label: "Paid by", value: "Simon")
            FlowTokenRow(tokens: ["Alex", "Ben", "Casey"])
        }
    }

    private var receiptCapturePreview: some View {
        VStack(spacing: 12) {
            FlowActionLabel(title: "Take Photo", subtitle: "Camera capture", systemImage: "camera.fill")
            FlowActionLabel(title: "Choose Photo", subtitle: "Photo library import", systemImage: "photo.on.rectangle")
        }
    }

    private var receiptReviewPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowReceiptRow(name: "Gyoza", amount: "$8.95")
            FlowReceiptRow(name: "Spicy tuna roll", amount: "$25.90")
            FlowReceiptRow(name: "Mochi", amount: "$7.50")
            Divider()
            FlowReceiptRow(name: "Tax and tip", amount: "$12.19")
        }
    }

    private var splitBoardPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowReceiptRow(name: "Gyoza", amount: "Shared")
            FlowTokenRow(tokens: ["Alex", "Ben", "Casey"])
            FlowReceiptRow(name: "Spicy tuna roll", amount: "Alex")
            FlowTokenRow(tokens: ["Alex"])
        }
    }

    private var settlementPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowReceiptRow(name: "Alex", amount: "$24.08")
            FlowReceiptRow(name: "Ben", amount: "$19.58")
            FlowReceiptRow(name: "Casey", amount: "$10.88")
            Divider()
            FlowReceiptRow(name: "Total", amount: "$54.54")
        }
    }

    private var sharePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sushi Night")
                .font(.headline)
            Text("Alex $24.08\nBen $19.58\nCasey $10.88\n\nPaid by Simon")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
            Button {
            } label: {
                Label("Share Summary", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(true)
        }
    }
}

private struct FlowField: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct FlowTokenRow: View {
    let tokens: [String]

    var body: some View {
        HStack {
            ForEach(tokens, id: \.self) { token in
                Text(token)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }
}

private struct FlowReceiptRow: View {
    let name: String
    let amount: String

    var body: some View {
        HStack {
            Text(name)
                .fontWeight(.medium)
            Spacer()
            Text(amount)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

private struct FlowFooter: View {
    let step: AppFlowStep
    let viewModel: AppFlowViewModel

    var body: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.moveBack()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                if step.next == nil {
                    viewModel.finishSharing()
                } else {
                    viewModel.advance()
                }
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
