import SwiftUI

struct VoiceRosterView: View {
    let viewModel: DashboardViewModel

    @Environment(\.openWindow) private var openWindow

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            if viewModel.voices.isEmpty {
                Spacer()
                Text("No voices loaded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(viewModel.voices) { voice in
                            voiceCell(voice)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Spacer()
            Button {
                openWindow(id: "voice-manager")
            } label: {
                Label("Manage…", systemImage: "slider.horizontal.3")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .glassEffect(.regular.interactive(), in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func voiceCell(_ voice: Voice) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(voice.swiftUIColor)
                .frame(width: 28, height: 28)
                .overlay {
                    Text(String(voice.name.prefix(1)).uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(voice.name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(voice.style)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(8)
        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
    }
}
