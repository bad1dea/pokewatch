import SwiftUI

/// The face plus its gestures:
/// * tap the Pokémon → reaction (handled inside the face)
/// * double-tap anywhere else → next animation routine
/// * long-press → customization
/// * horizontal swipe → previous / next face
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.isLuminanceReduced) private var luminanceReduced
    @Environment(\.scenePhase) private var scenePhase
    @State private var showCustomize = false
    @State private var showBrowser = false

    var body: some View {
        NavigationStack {
            FaceHost()
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { model.cycleVariant() }
                .onLongPressGesture(minimumDuration: 0.6) {
                    model.haptic(.start)
                    showCustomize = true
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { v in
                            let dx = v.translation.width, dy = v.translation.height
                            guard abs(dx) > 50, abs(dx) > abs(dy) * 1.5 else { return }
                            model.shiftFace(by: dx < 0 ? 1 : -1)
                        }
                )
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $showCustomize) {
                    CustomizeView()
                }
                .sheet(isPresented: $showBrowser) {
                    NavigationStack { PokemonBrowser() }
                }
        }
        .background(Color.black)
        .onChange(of: luminanceReduced) { _, reduced in
            // Leaving Always-On: play the wake-up animation.
            if !reduced { model.wake() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.becameActive()
            case .background: model.becameInactive()
            default: break
            }
        }
        .onAppear {
            if model.launch.openSettings { showCustomize = true }
            if model.launch.openBrowser { showBrowser = true }
        }
        .onOpenURL { _ in model.wake() }
    }
}
