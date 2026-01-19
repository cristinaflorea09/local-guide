import SwiftUI

/// Host availability manager.
///
/// This reuses the existing `availability` collection and `AvailabilitySlot` model.
/// To stay backward compatible (and avoid a Firestore migration), we store the host uid
/// in the existing `guideId` field.
struct HostAvailabilityView: View {
    @EnvironmentObject var appState: AppState

    @State private var slots: [AvailabilitySlot] = []
    @State private var start = Date()
    @State private var end = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Add availability slot") {
                    DatePicker("Start", selection: $start, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End", selection: $end, displayedComponents: [.date, .hourAndMinute])

                    Button("Add slot") {
                        Task { await addSlot() }
                    }
                    .disabled(isLoading || end <= start)
                }

                if let message {
                    Section {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Upcoming slots") {
                    if slots.isEmpty {
                        Text("No slots yet. Add some availability.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(slots) { s in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(s.start.formatted(date: .abbreviated, time: .shortened)) → \(s.end.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.headline)
                                Text("Status: \(s.status.rawValue)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { idx in
                            Task { await deleteSlots(idx) }
                        }
                    }
                }
            }
            .navigationTitle("Availability")
            .toolbar { EditButton() }
            .task { await load() }
        }
    }

    private func load() async {
        guard let hostId = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            slots = try await FirestoreService.shared.getAvailabilityForGuide(guideId: hostId)
        } catch {
            slots = []
        }
    }

    private func addSlot() async {
        guard let hostId = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            let slot = AvailabilitySlot(
                id: UUID().uuidString,
                guideId: hostId,
                listingType: nil,
                listingId: nil,
                capacity: nil,
                isReserved: nil,
                reservedBy: nil,
                reservedCount: nil,
                start: start,
                end: end,
                status: .open,
                bookingId: nil,
                createdAt: Date()
            )
            try await FirestoreService.shared.createAvailability(slot)
            message = "Slot added ✅"
            await load()
        } catch {
            message = error.localizedDescription
        }
    }

    private func deleteSlots(_ offsets: IndexSet) async {
        let ids = offsets.map { slots[$0].id }
        do {
            for id in ids {
                try await FirestoreService.shared.deleteAvailability(slotId: id)
            }
            await load()
        } catch {
            // ignore
        }
    }
}
