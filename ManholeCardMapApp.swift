//
//  ManholeCardMapApp.swift
//  ManholeCardMap
//
//  Created by ChikaraHanakawa on 2025/04/18.
//

import SwiftUI

@main
struct ManholeCardMapApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // フォント関連の問題を回避するためにデフォルトフォントを指定
                .environment(\.font, Font.system(.body))
        }
    }
}
