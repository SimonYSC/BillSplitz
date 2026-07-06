//
//  SplitBoardScreen.swift
//  BillSplitz
//

import SwiftUI

@Observable
@MainActor
final class SplitBoardInteraction {
    enum DropTarget: Hashable {
        case participant(UUID)
        case all
    }

    enum Phase: Equatable {
        case idle
        case assigning(itemID: UUID)
        case dragging(itemID: UUID, location: CGPoint, target: DropTarget?)
    }

    var phase: Phase = .idle
    var rowFrames: [UUID: CGRect] = [:]
    var bubbleFrames: [DropTarget: CGRect] = [:]

    func target(at point: CGPoint) -> DropTarget? {
        bubbleFrames.first { $0.value.insetBy(dx: -8, dy: -8).contains(point) }?.key
    }

    var activeItemID: UUID? {
        switch phase {
        case .idle:
            nil
        case .assigning(let itemID):
            itemID
        case .dragging(let itemID, _, _):
            itemID
        }
    }
}

struct SplitBoardScreen: View {
    var viewModel: AppFlowViewModel
    @State private var interaction = SplitBoardInteraction()
    @AppStorage("hasSeenSplitBoardCoachMark") private var hasSeenCoachMark = false
    @State private var showCoachMarkPending = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var reduceMotion: Bool {
        systemReduceMotion || ProcessInfo.processInfo.arguments.contains("--uitest-reduce-motion")
    }

    var body: some View {
        ZStack {
            boardChrome

            if interaction.phase != .idle {
                assignOverlay

                if showCoachMarkPending {
                    SplitBoardCoachMark {
                        hasSeenCoachMark = true
                        showCoachMarkPending = false
                    }
                }
            }
        }
        .coordinateSpace(name: "splitBoard")
        .background(Color.bsPaper)
    }

    private var boardChrome: some View {
        VStack(spacing: 16) {
            BSScreenHeader(step: .splitBoard, onBack: { viewModel.moveBack() })

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    SplitBoardPresetCard(viewModel: viewModel)

                    if !viewModel.unassignedItems.isEmpty {
                        BSStatusStrip(
                            text: "\(viewModel.unassignedItems.count) item\(viewModel.unassignedItems.count == 1 ? "" : "s") still need assignment.",
                            style: .warning
                        )
                    }

                    ForEach(Array(viewModel.draft.items.enumerated()), id: \.element.id) { index, item in
                        SplitItemRow(
                            item: item,
                            index: index,
                            viewModel: viewModel,
                            interaction: interaction,
                            reduceMotion: reduceMotion,
                            onEnterAssignMode: { presentAssignMode(for: item.id) }
                        )
                    }
                }
                .padding(.top, 4)
            }
            .scrollDisabled(interaction.phase != .idle)

            BSFlowFooter(step: .splitBoard, viewModel: viewModel)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var assignOverlay: some View {
        ZStack {
            Color.bsInk.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture { interaction.phase = .idle }
                .accessibilityIdentifier("assign-scrim")

            if let itemID = interaction.activeItemID {
                SplitBoardBubbleLayer(
                    itemID: itemID,
                    viewModel: viewModel,
                    interaction: interaction,
                    reduceMotion: reduceMotion
                )
            }

            if case .dragging(let itemID, let location, _) = interaction.phase,
               let item = viewModel.draft.items.first(where: { $0.id == itemID }) {
                DragChipView(item: item, viewModel: viewModel, reduceMotion: reduceMotion)
                    .position(location)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    private func presentAssignMode(for itemID: UUID) {
        interaction.phase = .assigning(itemID: itemID)

        if !hasSeenCoachMark {
            showCoachMarkPending = true
        }
    }
}

private struct SplitBoardPresetCard: View {
    var viewModel: AppFlowViewModel

    var body: some View {
        BSCard(title: "Preset") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Appetizers, desserts, and adjustments are shared. Mains and drinks stay assignable.")
                    .font(.bsBody(12, weight: .regular))
                    .foregroundStyle(Color.bsInkMuted)

                Button {
                    viewModel.applyDefaultPreset()
                } label: {
                    Text("APPLY MEAL PRESET")
                        .font(.bsBody(13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(BSButtonStyle(background: .bsAccent, shadowOffset: 4))
                .accessibilityIdentifier("apply-preset-button")
            }
        }
    }
}

private struct SplitItemRow: View {
    let item: ReceiptItem
    let index: Int
    var viewModel: AppFlowViewModel
    var interaction: SplitBoardInteraction
    let reduceMotion: Bool
    let onEnterAssignMode: () -> Void

    @State private var wiggleAngle: Double = 0
    @State private var pulseOpacity: Double = 1

    private var isHeld: Bool {
        interaction.activeItemID == item.id
    }

    private var isDraggingThis: Bool {
        if case .dragging(let itemID, _, _) = interaction.phase {
            return itemID == item.id
        }
        return false
    }

    var body: some View {
        rowBody
            .rotationEffect(.degrees(wiggleAngle))
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named("splitBoard"))
            } action: { frame in
                interaction.rowFrames[item.id] = frame
            }
            .gesture(assignGesture)
            .gesture(redragGesture, isEnabled: isHeld)
            .onChange(of: interaction.phase != .idle) { _, isActive in
                updateWiggle(active: isActive)
            }
    }

    @ViewBuilder
    private var rowBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(item.normalizedName)
                            .font(.bsBody(13, weight: .bold))
                            .foregroundStyle(Color.bsInk)

                        Text(item.category.displayName.uppercased())
                            .font(.bsBody(10, weight: .bold))
                            .foregroundStyle(Color.bsInkMuted)
                    }

                    if let caption = viewModel.connectionCaption(for: item.id) {
                        Text(caption)
                            .font(.bsBody(10, weight: .semibold))
                            .foregroundStyle(Color.bsInkMuted)
                    }
                }

                Spacer()

                Text(CurrencyFormatter.string(for: item.totalPrice, currencyCode: viewModel.draft.session.currencyCode))
                    .font(.bsMono(13))
                    .foregroundStyle(Color.bsInk)

                AssignmentBadge(item: item, viewModel: viewModel)
            }
        }
        .padding(12)
        .background(Color.bsCard)
        .overlay(
            Group {
                if isDraggingThis {
                    Rectangle().strokeBorder(style: StrokeStyle(lineWidth: BSBorder.control, dash: [6, 4]))
                        .foregroundStyle(Color.bsInk)
                } else {
                    Rectangle().stroke(
                        Color.bsInk.opacity(reduceMotion && isHeld ? pulseOpacity : 1),
                        lineWidth: BSBorder.control
                    )
                }
            }
        )
        .opacity(isDraggingThis ? 0.6 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("split-item-row-\(item.normalizedName)")
        .accessibilityActions {
            ForEach(viewModel.draft.participants) { participant in
                Button("Assign to \(participant.name)") {
                    viewModel.connect(itemID: item.id, to: participant.id)
                }
            }

            Button("Share with everyone") {
                viewModel.shareWithEveryone(itemID: item.id)
            }

            Button("Clear assignment") {
                viewModel.clearConnections(itemID: item.id)
            }
        }
    }

    private var assignGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("splitBoard")))
            .onChanged { value in
                switch value {
                case .first:
                    break
                case .second(_, let drag):
                    if interaction.activeItemID != item.id {
                        onEnterAssignMode()
                    }
                    if let drag {
                        interaction.phase = .dragging(
                            itemID: item.id,
                            location: drag.location,
                            target: interaction.target(at: drag.location)
                        )
                    }
                }
            }
            .onEnded { value in
                guard case .second(_, let drag) = value, let drag else {
                    return
                }
                resolveDrop(at: drag.location)
            }
    }

    private var redragGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("splitBoard"))
            .onChanged { drag in
                interaction.phase = .dragging(
                    itemID: item.id,
                    location: drag.location,
                    target: interaction.target(at: drag.location)
                )
            }
            .onEnded { drag in
                resolveDrop(at: drag.location)
            }
    }

    private func resolveDrop(at location: CGPoint) {
        switch interaction.target(at: location) {
        case .participant(let participantID):
            viewModel.connect(itemID: item.id, to: participantID)
            interaction.phase = .assigning(itemID: item.id)
        case .all:
            viewModel.shareWithEveryone(itemID: item.id)
            interaction.phase = .assigning(itemID: item.id)
        case nil:
            interaction.phase = .assigning(itemID: item.id)
        }
    }

    private func updateWiggle(active: Bool) {
        if active {
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.4
                }
            } else {
                withAnimation(
                    .easeInOut(duration: 0.25)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index % 3) * 0.05)
                ) {
                    wiggleAngle = 1.2
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.1)) {
                wiggleAngle = 0
                pulseOpacity = 1
            }
        }
    }
}

private struct AssignmentBadge: View {
    let item: ReceiptItem
    var viewModel: AppFlowViewModel

    private var connectedNames: [String] {
        let connectedIDs = Set(viewModel.draft.assignments.filter { $0.receiptItemID == item.id }.map(\.participantID))
        return viewModel.draft.participants.filter { connectedIDs.contains($0.id) }.map(\.name)
    }

    private var initials: String {
        connectedNames.prefix(2).compactMap(\.first).map(String.init).joined()
    }

    private var accessibilityValueText: String {
        switch item.assignmentMode {
        case .unassigned:
            "Unassigned"
        case .shared:
            "Shared"
        case .assigned, .split:
            connectedNames.joined(separator: " + ")
        }
    }

    var body: some View {
        Group {
            switch item.assignmentMode {
            case .unassigned:
                Rectangle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .foregroundStyle(Color.bsDisabled)
                    .overlay(
                        Text("+")
                            .font(.bsBody(14, weight: .bold))
                            .foregroundStyle(Color.bsDisabled)
                    )
            case .assigned, .split:
                Rectangle()
                    .fill(Color.bsAccent)
                    .overlay(Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.tag))
                    .overlay(
                        Text(initials)
                            .font(.bsBody(11, weight: .bold))
                            .foregroundStyle(Color.bsInk)
                    )
            case .shared:
                Rectangle()
                    .fill(Color.bsInk)
                    .overlay(
                        Text("ALL")
                            .font(.bsBody(8, weight: .bold))
                            .foregroundStyle(Color.bsAccent)
                    )
            }
        }
        .frame(width: 28, height: 28)
        .accessibilityIdentifier("split-item-badge-\(item.normalizedName)")
        .accessibilityValue(accessibilityValueText)
    }
}

private struct SplitBoardBubbleLayer: View {
    let itemID: UUID
    var viewModel: AppFlowViewModel
    var interaction: SplitBoardInteraction
    let reduceMotion: Bool

    private var rowFrame: CGRect {
        interaction.rowFrames[itemID] ?? .zero
    }

    private var flipBelow: Bool {
        rowFrame.minY < 200
    }

    private var targets: [SplitBoardInteraction.DropTarget] {
        [.all] + viewModel.draft.participants.map { .participant($0.id) }
    }

    var body: some View {
        VStack(spacing: 10) {
            bubbleGrid

            if let item = viewModel.draft.items.first(where: { $0.id == itemID }) {
                Button {
                    viewModel.clearConnections(itemID: itemID)
                    interaction.phase = .assigning(itemID: itemID)
                } label: {
                    Text("✕ CLEAR")
                        .font(.bsBody(11, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(BSButtonStyle(background: .bsCard, shadowOffset: 3, borderWidth: BSBorder.tag))
                .accessibilityIdentifier("assign-clear-chip")
                .opacity(item.assignmentMode == .unassigned ? 0.5 : 1)
            }
        }
        .position(
            x: max(rowFrame.midX, 90),
            y: flipBelow ? rowFrame.maxY + 90 : rowFrame.minY - 90
        )
    }

    private var bubbleGrid: some View {
        let rows = targets.chunked(into: targets.count >= 5 ? (targets.count + 1) / 2 : targets.count)

        return VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, rowTargets in
                HStack(spacing: 12) {
                    ForEach(Array(rowTargets.enumerated()), id: \.element) { rowIndex, target in
                        PersonBubble(
                            target: target,
                            index: rowIndex,
                            itemID: itemID,
                            viewModel: viewModel,
                            interaction: interaction,
                            reduceMotion: reduceMotion
                        )
                    }
                }
            }
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else {
            return [self]
        }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

private struct PersonBubble: View {
    let target: SplitBoardInteraction.DropTarget
    let index: Int
    let itemID: UUID
    var viewModel: AppFlowViewModel
    var interaction: SplitBoardInteraction
    let reduceMotion: Bool

    @State private var appeared = false

    private var isAll: Bool {
        target == .all
    }

    private var participant: Participant? {
        if case .participant(let id) = target {
            return viewModel.draft.participants.first { $0.id == id }
        }
        return nil
    }

    private var isHot: Bool {
        if case .dragging(_, _, let dropTarget) = interaction.phase {
            return dropTarget == target
        }
        return false
    }

    private var isDragging: Bool {
        if case .dragging = interaction.phase {
            return true
        }
        return false
    }

    private var isConnected: Bool {
        guard let participant else {
            return false
        }
        return viewModel.isConnected(participant.id, to: itemID)
    }

    private var label: String {
        isAll ? "ALL" : (participant?.name ?? "")
    }

    private var identifier: String {
        isAll ? "assign-bubble-all" : "assign-bubble-\(participant?.name ?? "")"
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isHot ? Color.bsAccent : (isAll ? Color.bsInk : Color.bsCard))
                    .overlay(Circle().stroke(Color.bsInk, lineWidth: BSBorder.card))
                    .frame(width: 52, height: 52)
                    .bsShadow(offset: 3)

                Text(isAll ? "ALL" : String(label.prefix(1)))
                    .font(isAll ? .bsBody(11, weight: .bold) : .bsDisplay(16))
                    .foregroundStyle(isAll ? Color.bsAccent : Color.bsInk)

                if isConnected {
                    Circle()
                        .fill(Color.bsInk)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text("✓")
                                .font(.bsBody(10, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .offset(x: 18, y: -18)
                }
            }
            .scaleEffect(isHot ? 1.15 : 1)
            .opacity(isDragging && !isHot ? 0.55 : 1)
            .animation(.easeOut(duration: 0.15), value: isHot)

            Text(label.uppercased())
                .font(.bsBody(10, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .bsInk, radius: 2)
        }
        .scaleEffect(appeared ? 1 : 0.5)
        .opacity(appeared ? 1 : 0)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named("splitBoard"))
        } action: { frame in
            interaction.bubbleFrames[target] = frame
        }
        .onAppear {
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.15)) {
                    appeared = true
                }
            } else {
                withAnimation(.spring(duration: 0.25).delay(Double(index) * 0.03)) {
                    appeared = true
                }
            }
        }
        // Tap-to-assign complements drag: same resolution as a drop on this bubble,
        // and it is the deterministic path for assistive tech and UI tests.
        .onTapGesture {
            switch target {
            case .participant(let participantID):
                viewModel.connect(itemID: itemID, to: participantID)
            case .all:
                viewModel.shareWithEveryone(itemID: itemID)
            }
            interaction.phase = .assigning(itemID: itemID)
        }
        .accessibilityIdentifier(identifier)
    }
}

private struct DragChipView: View {
    let item: ReceiptItem
    var viewModel: AppFlowViewModel
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(item.normalizedName)
                .font(.bsBody(12, weight: .bold))
            Text(CurrencyFormatter.string(for: item.totalPrice, currencyCode: viewModel.draft.session.currencyCode))
                .font(.bsMono(12))
        }
        .foregroundStyle(Color.bsInk)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bsCard)
        .overlay(Rectangle().stroke(Color.bsInk, lineWidth: BSBorder.control))
        .bsShadow(offset: 6)
        .rotationEffect(.degrees(reduceMotion ? 0 : -3))
    }
}

private struct SplitBoardCoachMark: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            Spacer()
            BSCard(title: "Tip") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Drag an item onto a name")
                        .font(.bsBody(13, weight: .semibold))
                        .foregroundStyle(Color.bsInk)

                    Button(action: onDismiss) {
                        Text("GOT IT")
                            .font(.bsBody(13, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(BSButtonStyle(background: .bsAccent, shadowOffset: 4))
                    .accessibilityIdentifier("coach-mark-got-it")
                }
            }
            .padding(20)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
