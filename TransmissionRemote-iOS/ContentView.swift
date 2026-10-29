//
//  ContentView.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        NavigationStack {
            TorrentListView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppEnvironment())
}

