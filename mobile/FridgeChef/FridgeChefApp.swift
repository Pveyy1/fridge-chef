import SwiftUI

@main
struct FridgeChefApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .preferredColorScheme(.light)
                .tint(Theme.accent)
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var state
    @State private var showSettings = false
    @State private var provider: String?

    var body: some View {
        @Bindable var state = state
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                Group {
                    switch state.stage {
                    case .snap: SnapView()
                    case .review: ReviewView()
                    case .menu: MenuView()
                    case .recipe: RecipeView()
                    case .card: MenuCardView()
                    }
                }
                .transition(.opacity)
                if state.isLoading { LoadingOverlay(text: state.loadingText) }
            }
            .animation(.easeInOut(duration: 0.25), value: state.stage)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text("Fridge Chef").font(Theme.serif(20)).foregroundStyle(Theme.ink)
                        if provider == "demo" {
                            Text("DEMO").font(.system(size: 9, weight: .bold)).tracking(1.5)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Theme.soft).foregroundStyle(Theme.accent)
                                .clipShape(Capsule())
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape").foregroundStyle(Theme.muted)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .toolbarBackground(.white, for: .navigationBar)
        }
        .sheet(isPresented: $showSettings, onDismiss: { Task { await checkServer() } }) {
            SettingsView()
        }
        .alert("Hmm.", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.errorMessage ?? "")
        }
        .task {
            await checkServer()
            #if DEBUG
            await jumpForTesting()
            #endif
        }
    }

    #if DEBUG

    private func jumpForTesting() async {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-jumpTo"), i + 1 < args.count else { return }
        let target = args[i + 1]
        state.startReview(with: Detection(
            sure: ["eggs", "leftover rice", "spring onions", "cheddar", "spinach"],
            unsure: [UnsureItem(looksLike: "white tub with a blue lid", options: ["greek yogurt", "cream cheese"])],
            useFirst: ["spinach"]))
        if target == "review" { return }
        await state.planMenu()
        if target == "menu" { return }
        if let dish = state.dishes.first { state.cook(dish) }
        if target == "card" { state.madeIt() }
    }
    #endif

    private func checkServer() async {
        provider = try? await APIClient(baseURL: state.serverURL).health().provider
    }
}

struct LoadingOverlay: View {
    let text: String
    var body: some View {
        ZStack {
            Color.white.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().controlSize(.large).tint(Theme.accent)
                Text(text).font(Theme.serif(20)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var status = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(AppState.defaultServerURL, text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Test connection") { Task { await test() } }
                    if !status.isEmpty { Text(status).font(.footnote).foregroundStyle(Theme.muted) }
                } header: {
                    Text("Server address")
                } footer: {
                    Text("Default: the online server. To use the server on your Mac instead: http://localhost:8000 in the Simulator, or your Mac’s Wi-Fi address (e.g. http://192.168.1.20:8000) on an iPhone. Clear the box to go back to the default.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { state.serverURL = url; dismiss() }
                }
            }
            .onAppear { url = state.serverURL }
        }
    }

    private func test() async {
        status = "Checking…"
        do {
            let h = try await APIClient(baseURL: url).health()
            status = h.provider == "demo"
                ? "Connected ✓ — demo mode (no API key on the server yet)"
                : "Connected ✓ — using \(h.provider.capitalized)"
        } catch {
            status = error.localizedDescription
        }
    }
}
