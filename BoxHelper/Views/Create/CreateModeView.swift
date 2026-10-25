import SwiftUI
import TipKit

struct CreateView: View {
    @Binding var missingUUID: UUID?
    @AppStorage(CreateFormPreferences.defaultKey) private var defaultForm = CreateFormDefault.last.rawValue
    // SwiftData-Änderungen aktualisieren auch den Tipp im bereits offenen Formular.
    @ObservedObject private var inventoryStorage = InventoryStorageState.shared
    @ObservedObject private var handoff = InventoryHandoffStore.shared
    @State private var mode: CreateMode
    @State private var leftMode: CreateMode
    @State private var rightMode: CreateMode
    @State private var loadedModes: Set<CreateMode>
    private let createModesTip = CreateModesTip()

    private var hasExistingBox: Bool {
        _ = inventoryStorage.revision
        return !loadBoxes().isEmpty
    }

    init(missingUUID: Binding<UUID?>) {
        self._missingUUID = missingUUID
        let initial = missingUUID.wrappedValue == nil ? CreateFormPreferences.initialMode() : .box
        _mode = State(initialValue: initial)
        _loadedModes = State(initialValue: [initial])
        _leftMode = State(initialValue: initial.alternateModes.left)
        _rightMode = State(initialValue: initial.alternateModes.right)
    }

    var body: some View {
        // Der Navigationscontainer bleibt beim Moduswechsel bestehen. So muss SwiftUI
        // die Toolbar nicht gleichzeitig mit einem neuen NavigationStack verbinden.
        NavigationStack {
            forms
                .inventoryCloudToolbar()
        }
        .onAppear {
            // UserDefaults notifies AppStorage observers; write after the current view update.
            DispatchQueue.main.async { rememberMode() }
        }
        .onChange(of: defaultForm) { _, _ in
            guard missingUUID == nil else { return }
            activate(CreateFormPreferences.initialMode())
        }
        .onChange(of: missingUUID) { _, value in
            if value != nil { activate(.box) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .resumeInventoryHandoff)) { notification in
            guard let name = notification.object as? String, let target = CreateMode(rawValue: name) else { return }
            missingUUID = nil
            activate(target)
        }
        .onChange(of: handoff.pendingFormRequestID, initial: true) { _, request in
            // Beim Kaltstart wurde die Übergabe bereits vor dem Formularaufbau empfangen.
            guard let name = handoff.pendingFormKind, let target = CreateMode(rawValue: name) else { return }
            missingUUID = nil
            activate(target)
            Task { @MainActor in
                // Die äußere Tab-Navigation muss dieselbe Anfrage zunächst ebenfalls lesen.
                await Task.yield()
                handoff.consumeFormRequest(request)
            }
        }
    }

    private var forms: some View {
        // Build only visited forms. Keep them alive afterwards to preserve unsaved inputs.
        ZStack {
            if loadedModes.contains(.box) {
                BoxCreateView(isActive: mode == .box, leftModeButton: leftButton(for: .box), rightModeButton: rightButton, missingUUID: $missingUUID)
                    .opacity(mode == .box ? 1 : 0)
                    .allowsHitTesting(mode == .box)
                    .accessibilityHidden(mode != .box)
            }
            if loadedModes.contains(.item) {
                QuickCreateView(mode: .item, isActive: mode == .item,
                                leftModeButton: leftButton(for: .item), rightModeButton: rightButton)
                    .opacity(mode == .item ? 1 : 0)
                    .allowsHitTesting(mode == .item)
                    .accessibilityHidden(mode != .item)
            }
            if loadedModes.contains(.location) {
                QuickCreateView(mode: .location, isActive: mode == .location,
                                leftModeButton: leftButton(for: .location), rightModeButton: rightButton)
                    .opacity(mode == .location ? 1 : 0)
                    .allowsHitTesting(mode == .location)
                    .accessibilityHidden(mode != .location)
            }
        }
    }

    private func leftButton(for form: CreateMode) -> AnyView {
        AnyView(
            modeButton(leftMode) { exchange(left: true) }
                // Nur das sichtbare Formular zeigt den Tipp, sobald eine Kiste vorhanden ist.
                .popoverTip(mode == form && hasExistingBox ? createModesTip : nil, arrowEdge: .bottom)
        )
    }

    private var rightButton: AnyView {
        AnyView(modeButton(rightMode) { exchange(left: false) })
    }

    private func modeButton(_ target: CreateMode, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(target.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(10)
                .foregroundStyle(UserDefaultsManager.loadAccentColor())
        }
        .buttonStyle(.plain)
        .modifier(CreateControlSurface())
        .accessibilityLabel(target.title)
    }

    private func rememberMode() {
        let defaults = UserDefaults.standard
        // All three forms belong to the Create page, including when the form has not changed.
        if defaults.string(forKey: "lastState") != "create" {
            UserDefaultsManager.shared.saveLastState("create")
        }
        guard defaults.string(forKey: CreateFormPreferences.lastModeKey) != mode.rawValue else { return }
        defaults.set(mode.rawValue, forKey: CreateFormPreferences.lastModeKey)
    }

    private func activate(_ target: CreateMode) {
        guard mode != target else { return }
        exchange(left: leftMode == target)
    }

    private func exchange(left: Bool) {
        createModesTip.invalidate(reason: .actionPerformed)
        hideKeyboard()
        let previous = mode
        if left {
            mode = leftMode
            leftMode = previous
        } else {
            mode = rightMode
            rightMode = previous
        }
        loadedModes.insert(mode)
        rememberMode()
    }
}
