import SwiftUI

struct AvailabilityPickerView: View {
    let guideId: String
    let selectedDate: Date
    @Binding var selectedSlot: AvailabilitySlot?

    @State private var slots: [AvailabilitySlot] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Available time slots").font(.headline)

            if isLoading {
                ProgressView("Loading slots…").tint(Lx.gold)
            } else if slots.isEmpty {
                Text("No availability for this day. Try another date or message the guide.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(slots) { slot in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                selectedSlot = slot
                            }
                            Haptics.light()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(slot.start.formatted(date: .omitted, time: .shortened)) → \(slot.end.formatted(date: .omitted, time: .shortened))")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Tap to select")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedSlot?.id == slot.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedSlot?.id == slot.id ? Lx.gold : .secondary)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.10))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Lx.gold.opacity(selectedSlot?.id == slot.id ? 0.35 : 0.18), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task { await load() }
        .onChange(of: selectedDate) { _ in Task { await load() } }
    }

    private func load() async {
        isLoading = true
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: selectedDate)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? selectedDate
        do {
            slots = try await FirestoreService.shared.getAvailabilityForGuide(guideId: guideId)
        } catch {
            slots = []
        }
        isLoading = false
    }
}
