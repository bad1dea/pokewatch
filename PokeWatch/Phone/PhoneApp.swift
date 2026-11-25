import SwiftUI

@main
struct PokeWatchPhoneApp: App {
    @State private var model = PhoneModel()

    var body: some Scene {
        WindowGroup {
            PhoneRoot()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Palette.electric)
        }
    }
}

enum PhoneTab: String, Hashable { case companion, pokedex, faces, watch }

/// Tab bar on narrow screens (Duo front screen, portrait iPhones), sidebar on wide ones
/// (Duo unfolded, landscape), from iOS 26's adaptive tab view.
struct PhoneRoot: View {
    @Environment(PhoneModel.self) private var model
    @State private var tab: PhoneTab = .companion

    var body: some View {
        TabView(selection: $tab) {
            Tab("Companion", systemImage: "sparkles", value: PhoneTab.companion) {
                NavigationStack { CompanionScreen() }
            }
            Tab("Pokédex", systemImage: "square.grid.3x3.fill", value: PhoneTab.pokedex) {
                NavigationStack { PokedexScreen() }
            }
            Tab("Faces", systemImage: "applewatch", value: PhoneTab.faces) {
                NavigationStack { FacesScreen() }
            }
            Tab("Watch", systemImage: "gearshape.fill", value: PhoneTab.watch) {
                NavigationStack { WatchScreen() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onAppear {
            if let t = model.launch.phoneTab.flatMap(PhoneTab.init(rawValue:)) { tab = t }
        }
    }
}
