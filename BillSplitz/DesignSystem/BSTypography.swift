//
//  BSTypography.swift
//  BillSplitz
//

import SwiftUI
import UIKit
import CoreText

enum BSFontRegistrar {
    static let isReady: Bool = {
        registerBundledFonts()
        return resolvedDisplayName != nil
            && resolvedBodyRegularName != nil
            && resolvedBodyMediumName != nil
            && resolvedBodyBoldName != nil
            && resolvedMonoRegularName != nil
            && resolvedMonoMediumName != nil
            && resolvedMonoSemiboldName != nil
    }()

    static func resolvedName(_ candidates: [String]) -> String? {
        candidates.first { UIFont(name: $0, size: 12) != nil }
    }

    static let resolvedDisplayName = resolvedName(["ArchivoBlack-Regular"])
    static let resolvedBodyRegularName = resolvedName(["SpaceGrotesk-Regular"])
    static let resolvedBodyMediumName = resolvedName(["SpaceGrotesk-Medium"])
    static let resolvedBodyBoldName = resolvedName(["SpaceGrotesk-Bold"])
    static let resolvedMonoRegularName = resolvedName(["IBMPlexMono", "IBMPlexMono-Regular"])
    static let resolvedMonoMediumName = resolvedName(["IBMPlexMono-Medium", "IBMPlexMono-Medm"])
    static let resolvedMonoSemiboldName = resolvedName(["IBMPlexMono-SemiBold", "IBMPlexMono-SmBld"])

    private static func registerBundledFonts() {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) else { return }

        for url in urls {
            var unmanagedError: Unmanaged<CFError>?
            let didRegister = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &unmanagedError)
            if !didRegister, let error = unmanagedError?.takeRetainedValue() {
                let code = CFErrorGetCode(error)
                if code != CTFontManagerError.alreadyRegistered.rawValue {
                    assertionFailure("Font registration failed for \(url.lastPathComponent): \(error)")
                }
            }
        }
    }
}

extension Font {
    static func bsDisplay(_ size: CGFloat) -> Font {
        // Touch isReady first: it registers the bundled fonts before any name resolution
        // is cached, which App.init guarantees in the app but nothing guarantees in previews.
        if BSFontRegistrar.isReady, let name = BSFontRegistrar.resolvedDisplayName {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .black)
    }

    static func bsBody(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        guard BSFontRegistrar.isReady else {
            return .system(size: size, weight: weight)
        }

        // Space Grotesk ships no static SemiBold cut upstream; semibold maps to Medium.
        let name: String?
        switch weight {
        case .regular:
            name = BSFontRegistrar.resolvedBodyRegularName
        case .medium, .semibold:
            name = BSFontRegistrar.resolvedBodyMediumName
        case .bold:
            name = BSFontRegistrar.resolvedBodyBoldName
        default:
            name = BSFontRegistrar.resolvedBodyMediumName
        }

        if let name {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight)
    }

    static func bsMono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        guard BSFontRegistrar.isReady else {
            return .system(size: size, weight: weight, design: .monospaced)
        }

        let name: String?
        switch weight {
        case .regular:
            name = BSFontRegistrar.resolvedMonoRegularName
        case .medium:
            name = BSFontRegistrar.resolvedMonoMediumName
        case .semibold:
            name = BSFontRegistrar.resolvedMonoSemiboldName
        default:
            name = BSFontRegistrar.resolvedMonoMediumName
        }

        if let name {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }
}
