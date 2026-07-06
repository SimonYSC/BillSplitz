//
//  BSTheme.swift
//  BillSplitz
//

import SwiftUI

private extension Color {
    init(bsHex: UInt32) {
        let r = Double((bsHex >> 16) & 0xFF) / 255
        let g = Double((bsHex >> 8) & 0xFF) / 255
        let b = Double(bsHex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension Color {
    static let bsPaper = Color(bsHex: 0xF0EDE4)
    static let bsPaperSunken = Color(bsHex: 0xF5F2E9)
    static let bsInk = Color(bsHex: 0x111111)
    static let bsInkMuted = Color(bsHex: 0x555555)
    static let bsDisabled = Color(bsHex: 0x999999)
    static let bsDisabledText = Color(bsHex: 0x777777)
    static let bsDisabledShadow = Color(bsHex: 0xC9C5B8)
    static let bsDisabledFill = Color(bsHex: 0xD6D2C6)
    static let bsCard = Color(bsHex: 0xFFFFFF)
    static let bsAccent = Color(bsHex: 0xFFD500)
    static let bsDanger = Color(bsHex: 0xE03A2A)
}

enum BSBorder {
    static let card: CGFloat = 3
    static let control: CGFloat = 2.5
    static let tag: CGFloat = 2
}

struct BSShadowModifier: ViewModifier {
    let offset: CGFloat
    var color: Color = .bsInk

    func body(content: Content) -> some View {
        content.background(alignment: .topLeading) {
            Rectangle()
                .fill(color)
                .offset(x: offset, y: offset)
        }
    }
}

extension View {
    func bsShadow(offset: CGFloat, color: Color = .bsInk) -> some View {
        modifier(BSShadowModifier(offset: offset, color: color))
    }
}

struct BSButtonStyle: ButtonStyle {
    let background: Color
    let shadowOffset: CGFloat
    var borderWidth: CGFloat = BSBorder.card

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        configuration.label
            .background(background)
            .overlay(
                Rectangle()
                    .stroke(Color.bsInk, lineWidth: borderWidth)
            )
            .bsShadow(offset: isPressed ? 0 : shadowOffset)
            .offset(x: isPressed ? shadowOffset : 0, y: isPressed ? shadowOffset : 0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
    }
}
