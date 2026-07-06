//
//  BSComponents.swift
//  BillSplitz
//

import SwiftUI

struct BSScreenHeader: View {
    let step: AppFlowStep
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                Button(action: onBack) {
                    Text("←")
                        .font(.bsBody(17, weight: .bold))
                        .foregroundStyle(Color.bsInk)
                        .frame(width: 38, height: 38)
                        .background(Color.bsCard)
                        .overlay(Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.card))
                        .bsShadow(offset: 3)
                }
                .accessibilityIdentifier("back-chip")

                Spacer(minLength: 8)

                Text(step.title)
                    .font(.bsDisplay(21))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bsInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier("screen-title-\(step.rawValue)")

                Spacer(minLength: 8)

                Color.clear.frame(width: 38, height: 38)
            }

            BSProgressBlocks(step: step)
        }
    }
}

private struct BSProgressBlocks: View {
    let step: AppFlowStep

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(AppFlowStep.navigableSteps) { navigableStep in
                    BSProgressBlock(state: state(for: navigableStep))
                }
            }

            Text("\(step.stepNumber ?? 0)/\(AppFlowStep.navigableSteps.count)")
                .font(.bsBody(11, weight: .bold))
                .foregroundStyle(Color.bsInk)
                .fixedSize()
        }
    }

    private func state(for navigableStep: AppFlowStep) -> BSProgressBlockState {
        guard let currentIndex = AppFlowStep.navigableSteps.firstIndex(of: step),
              let blockIndex = AppFlowStep.navigableSteps.firstIndex(of: navigableStep) else {
            return .future
        }

        if blockIndex < currentIndex {
            return .completed
        } else if blockIndex == currentIndex {
            return .current
        } else {
            return .future
        }
    }
}

private enum BSProgressBlockState {
    case completed
    case current
    case future
}

private struct BSProgressBlock: View {
    let state: BSProgressBlockState

    var body: some View {
        Rectangle()
            .fill(fillColor)
            .frame(height: 12)
            .overlay {
                if state != .completed {
                    Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.tag)
                }
            }
            .frame(maxWidth: .infinity)
    }

    private var fillColor: Color {
        switch state {
        case .completed: Color.bsInk
        case .current: Color.bsAccent
        case .future: Color.bsCard
        }
    }
}

struct BSFlowFooter: View {
    let step: AppFlowStep
    let viewModel: AppFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let validationMessage = viewModel.validationMessage {
                BSStatusStrip(text: validationMessage, style: .warning)
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.moveBack()
                } label: {
                    Text("← BACK")
                        .font(.bsBody(13, weight: .bold))
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(BSButtonStyle(background: .bsCard, shadowOffset: 4))

                Button {
                    viewModel.advance()
                } label: {
                    Text(step.next == nil ? "DONE" : "NEXT →")
                        .font(.bsBody(13, weight: .bold))
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(BSButtonStyle(background: .bsAccent, shadowOffset: 4))
                .accessibilityIdentifier("flow-next-button")
            }
        }
    }
}

struct BSCard<Content: View>: View {
    let title: String
    var action: BSCardAction?
    let content: () -> Content

    init(title: String, action: BSCardAction? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.action = action
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.bsDisplay(14))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bsInk)

                Spacer()

                if let action {
                    Button(action: action.perform) {
                        Text(action.title)
                            .font(.bsBody(11, weight: .bold))
                            .textCase(.uppercase)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(BSButtonStyle(background: .bsCard, shadowOffset: 3, borderWidth: BSBorder.tag))
                }
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bsCard)
        .overlay(Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.card))
        .bsShadow(offset: 6)
    }
}

struct BSCardAction {
    let title: String
    let perform: () -> Void
}

enum BSStatusStripStyle {
    case neutral
    case warning
}

struct BSStatusStrip: View {
    let text: String
    var style: BSStatusStripStyle = .neutral

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(style == .warning ? "!" : "i")
                .font(.bsBody(12, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.bsInk)

            Text(text)
                .font(.bsBody(12.5, weight: .semibold))
                .foregroundStyle(Color.bsInk)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(style == .warning ? Color.bsAccent : Color.bsCard)
        .overlay(Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.control))
    }
}

struct BSDashedButtonLabel: View {
    let title: String

    var body: some View {
        Text("+ \(title.uppercased())")
            .font(.bsBody(12, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(Color.bsInk)
            .overlay(
                Rectangle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
                    .foregroundStyle(Color.bsInk)
            )
    }
}

struct DecimalTextField: View {
    let title: String
    @Binding var value: Decimal

    var body: some View {
        HStack {
            Text(title)
                .font(.bsBody(11, weight: .bold))
                .foregroundStyle(.white)
                .textCase(.uppercase)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.bsInk)

            TextField(title, text: Binding<String>(
                get: { CurrencyFormatter.editableString(for: value) },
                set: { newValue in
                    if let decimal = CurrencyFormatter.decimal(from: newValue) {
                        value = decimal
                    }
                }
            ))
            .font(.bsMono(13))
            .keyboardType(.numbersAndPunctuation)
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.bsCard)
            .overlay(Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.control))
        }
    }
}
