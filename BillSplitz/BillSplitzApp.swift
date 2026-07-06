//
//  BillSplitzApp.swift
//  BillSplitz
//
//  Created by Simon Chao on 11/17/25.
//

import SwiftUI

@main
struct BillSplitzApp: App {
    init() {
        _ = BSFontRegistrar.isReady
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
