// ContentView.swift — root navigation router

import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @State private var audioPlayer = AudioPlayerService()

    var body: some View {
        ZStack {
            // Mind is always the base layer
            MindView()
                .environment(appState)
                .environment(audioPlayer)

            // Library slides in from the trailing edge
            if appState.stage == .library {
                LibraryView()
                    .environment(appState)
                    .environment(audioPlayer)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            }

            // Splash covers everything on first launch
            if appState.stage == .splash {
                SplashView()
                    .environment(appState)
                    .environment(audioPlayer)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(AppAnimation.springFluid, value: appState.stage)
        .gesture(swipeGesture)
        .onOpenURL { url in handleDeepLink(url) }
        .preferredColorScheme(appState.appearance.colorScheme)
    }

    // MARK: - Deep links (widget)

    /// Routes `quicknote://` URLs opened from the widget into app state.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == WidgetRoute.scheme else { return }
        appState.isQuietHours = false
        appState.isRecalling = false
        withAnimation(AppAnimation.springFluid) {
            appState.stage = .inbox
        }
        if url.host == "capture" {
            appState.shouldFocusCapture = true
        }
    }

    // MARK: - Edge swipe for Mind ↔ Library

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                guard horizontal > vertical * 1.5 else { return }
                guard horizontal > 50 else { return }

                withAnimation(AppAnimation.springFluid) {
                    if value.translation.width < 0,
                       appState.stage == .inbox || appState.stage == .library {
                        appState.stage = .library
                    } else if value.translation.width > 0,
                              appState.stage == .library {
                        appState.stage = .inbox
                    }
                }
            }
    }
}
