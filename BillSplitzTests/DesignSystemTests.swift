//
//  DesignSystemTests.swift
//  BillSplitzTests
//

import SwiftUI
import UIKit
import Testing
@testable import BillSplitz

struct DesignSystemTests {
    @Test func bundledFontsRegisterAndResolve() {
        let ready = BSFontRegistrar.isReady
        let families = UIFont.familyNames.filter {
            $0.contains("Archivo") || $0.contains("Space") || $0.contains("Plex")
        }
        let diagnostic = families
            .map { family in "\(family): \(UIFont.fontNames(forFamilyName: family))" }
            .joined(separator: "\n")

        #expect(ready, "\(diagnostic)")
    }

    @Test func fontResourcesArePresent() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        #expect(urls.count == 7)
    }

    @Test func tokensExist() {
        _ = Color.bsAccent
        #expect(BSBorder.card == 3)

        struct ShadowProbe: View {
            var body: some View {
                ZStack {
                    Rectangle().bsShadow(offset: 6)
                }
            }
        }
        _ = ShadowProbe()
    }
}
