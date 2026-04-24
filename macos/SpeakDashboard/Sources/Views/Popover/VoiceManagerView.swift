import AppKit
import SwiftUI

// MARK: - Manager Window

struct VoiceManagerView: View {
    let viewModel: DashboardViewModel

    @State private var selection: Voice.ID?
    @State private var editing: EditTarget?
    @State private var pendingDelete: Voice?
    @State private var errorMessage: String?
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    enum EditTarget: Identifiable {
        case new
        case edit(Voice)

        var id: String {
            switch self {
            case .new: "__new__"
            case .edit(let v): v.name
            }
        }
    }

    var body: some View {
        NavigationStack {
            voicesList
                .navigationTitle("Voice Manager")
                .toolbar { toolbar }
                .overlay(alignment: .bottom) { toastOverlay }
        }
        .frame(minWidth: 520, minHeight: 400)
        .sheet(item: $editing) { target in
            VoiceFormView(
                viewModel: viewModel,
                initial: target
            ) { message in
                if let message {
                    errorMessage = message
                } else {
                    editing = nil
                }
            }
        }
        .confirmationDialog(
            "Delete voice?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { voice in
            Button("Delete \(voice.name)", role: .destructive) {
                Task { await performDelete(voice) }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { voice in
            Text("\(voice.name) will be removed from voices.json. This can’t be undone.")
        }
        .alert(
            "Voice Manager",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { message in
            Text(message)
        }
        .task {
            await viewModel.refreshVoices()
        }
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - List

    @ViewBuilder
    private var voicesList: some View {
        if viewModel.voices.isEmpty {
            ContentUnavailableView(
                "No voices",
                systemImage: "person.2.slash",
                description: Text("Add a voice to get started.")
            )
        } else {
            List(selection: $selection) {
                ForEach(viewModel.voices) { voice in
                    VoiceManagerRow(
                        voice: voice,
                        portraitManager: viewModel.portraitManager,
                        onEdit: { editing = .edit(voice) },
                        onDelete: { pendingDelete = voice },
                        onRegenerate: { copyRegenerateCommand(for: voice) }
                    )
                    .tag(voice.id)
                    .contextMenu {
                        Button("Edit…") { editing = .edit(voice) }
                        Button("Copy Regenerate Portraits Command") {
                            copyRegenerateCommand(for: voice)
                        }
                        Divider()
                        Button("Delete", role: .destructive) { pendingDelete = voice }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                editing = .new
            } label: {
                Label("Add Voice", systemImage: "plus")
            }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toastMessage {
            Text(toastMessage)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.secondary.opacity(0.2)))
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    private func performDelete(_ voice: Voice) async {
        pendingDelete = nil
        do {
            try await viewModel.deleteVoice(name: voice.name)
            if selection == voice.id { selection = nil }
            showToast("Deleted \(voice.name)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyRegenerateCommand(for voice: Voice) {
        let instruction = "Regenerate voice portraits for the \"\(voice.name)\" voice. Use the generate-voice-portrait skill (nested under the speak skill). name: \(voice.name); style: \(voice.style); kind: \(voice.kind)."
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(instruction, forType: .string)
        showToast("Copied regenerate instructions for \(voice.name)")
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            toastMessage = message
        }
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) {
                toastMessage = nil
            }
        }
    }
}

// MARK: - Row

private struct VoiceManagerRow: View {
    let voice: Voice
    let portraitManager: PortraitManager
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onRegenerate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PortraitView(
                voiceName: voice.name,
                amplitude: 0,
                size: 44,
                voiceColor: voice.swiftUIColor,
                portraitManager: portraitManager
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(voice.name)
                        .font(.headline)
                    KindBadge(kind: voice.kind)
                    if !voice.hasPortrait {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("No portrait yet — run Regenerate Portraits")
                    }
                }

                Text(voice.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !voice.style.isEmpty {
                    Text(voice.style)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(voice.swiftUIColor)
                .frame(width: 16, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(.secondary.opacity(0.3), lineWidth: 0.5)
                )
                .help(voice.color)

            Menu {
                Button("Edit…", action: onEdit)
                Button("Copy Regenerate Portraits Command", action: onRegenerate)
                Divider()
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
    }
}

private struct KindBadge: View {
    let kind: String

    var body: some View {
        Text(kind)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
    }

    private var background: Color {
        switch kind {
        case "default": .blue.opacity(0.18)
        case "codex": .purple.opacity(0.18)
        case "user": .green.opacity(0.18)
        case "custom": .orange.opacity(0.18)
        default: .gray.opacity(0.18)
        }
    }

    private var foreground: Color {
        switch kind {
        case "default": .blue
        case "codex": .purple
        case "user": .green
        case "custom": .orange
        default: .primary
        }
    }
}

// MARK: - Form

struct VoiceFormView: View {
    let viewModel: DashboardViewModel
    let initial: VoiceManagerView.EditTarget
    let onFinish: (String?) -> Void

    @State private var name: String = ""
    @State private var elevenID: String = ""
    @State private var colorPick: Color = .blue
    @State private var colorHex: String = "#3b82f6"
    @State private var style: String = ""
    @State private var kindSelection: KindChoice = .defaultKind
    @State private var customKind: String = ""
    @State private var isSaving: Bool = false

    @Environment(\.dismiss) private var dismiss

    enum KindChoice: String, CaseIterable, Identifiable {
        case defaultKind = "default"
        case codex
        case user
        case custom
        case other = "Other…"

        var id: String { rawValue }
        var label: String {
            switch self {
            case .defaultKind: "default"
            case .codex: "codex"
            case .user: "user"
            case .custom: "custom"
            case .other: "Other…"
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = initial { true } else { false }
    }

    private var effectiveKind: String {
        switch kindSelection {
        case .other:
            return customKind.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            return kindSelection.label
        }
    }

    private var colorValid: Bool {
        colorHex.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil
    }

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedID = elevenID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || trimmedID.isEmpty { return false }
        if !colorValid { return false }
        if kindSelection == .other, effectiveKind.isEmpty { return false }
        return true
    }

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $name)
                    .disableAutocorrection(true)

                TextField("ElevenLabs Voice ID", text: $elevenID)
                    .font(.body.monospaced())
                    .disableAutocorrection(true)
            }

            Section("Appearance") {
                HStack {
                    ColorPicker("Color", selection: $colorPick, supportsOpacity: false)
                        .onChange(of: colorPick) { _, newColor in
                            if let hex = newColor.toHexString() { colorHex = hex }
                        }

                    TextField("Hex", text: $colorHex)
                        .font(.body.monospaced())
                        .frame(width: 100)
                        .onChange(of: colorHex) { _, newHex in
                            if let c = Color(hex: newHex) { colorPick = c }
                        }
                }

                if !colorValid {
                    Text("Color must match #rrggbb")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Style") {
                TextEditor(text: $style)
                    .font(.body)
                    .frame(minHeight: 80)
                    .overlay(alignment: .topLeading) {
                        if style.isEmpty {
                            Text("Describe the voice’s persona, cadence, mood…")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section("Kind") {
                Picker("Kind", selection: $kindSelection) {
                    ForEach(KindChoice.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                .pickerStyle(.menu)

                if kindSelection == .other {
                    TextField("Custom kind", text: $customKind)
                        .disableAutocorrection(true)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 440)
        .navigationTitle(isEditing ? "Edit Voice" : "New Voice")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onFinish(nil); dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Add") { Task { await save() } }
                    .disabled(!isValid || isSaving)
            }
        }
        .onAppear(perform: primeForm)
    }

    private func primeForm() {
        if case .edit(let voice) = initial {
            name = voice.name
            elevenID = voice.id
            colorHex = voice.color
            if let c = Color(hex: voice.color) { colorPick = c }
            style = voice.style

            switch voice.kind {
            case "default": kindSelection = .defaultKind
            case "codex": kindSelection = .codex
            case "user": kindSelection = .user
            case "custom": kindSelection = .custom
            default:
                kindSelection = .other
                customKind = voice.kind
            }
        }
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedID = elevenID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStyle = style.trimmingCharacters(in: .whitespacesAndNewlines)
        let kindValue = effectiveKind

        isSaving = true
        defer { isSaving = false }

        do {
            switch initial {
            case .new:
                try await viewModel.createVoice(
                    name: trimmedName,
                    id: trimmedID,
                    color: colorHex,
                    style: trimmedStyle,
                    kind: kindValue
                )
            case .edit(let voice):
                var patch: [String: Any] = [:]
                if trimmedName != voice.name { patch["name"] = trimmedName }
                if trimmedID != voice.id { patch["id"] = trimmedID }
                if colorHex != voice.color { patch["color"] = colorHex }
                if trimmedStyle != voice.style { patch["style"] = trimmedStyle }
                if kindValue != voice.kind { patch["kind"] = kindValue }
                if !patch.isEmpty {
                    try await viewModel.updateVoice(currentName: voice.name, patch: patch)
                }
            }
            onFinish(nil)
            dismiss()
        } catch {
            onFinish(error.localizedDescription)
        }
    }
}
