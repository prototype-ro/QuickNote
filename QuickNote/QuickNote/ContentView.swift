// ContentView.swift — root navigation router

import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        ZStack {
            // Mind is always the base layer
            MindView()
                .environment(appState)

            // Library slides in from the trailing edge
            if appState.stage == .library {
                LibraryView()
                    .environment(appState)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            }

            // Splash covers everything on first launch
            if appState.stage == .splash {
                SplashView()
                    .environment(appState)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(AppAnimation.springFluid, value: appState.stage)
        .gesture(swipeGesture)
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
