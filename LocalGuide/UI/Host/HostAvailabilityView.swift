import SwiftUI

/// Host availability manager (per experience).
///
/// Availability slots are stored in the shared `availability` collection.
/// For hosts we keep using the existing `guideId` field to store the host identifier
/// (backward compatible), but **slots are scoped to a specific experience** via
/// `listingType = "experience"` and `listingId = <experienceId>`.
struct HostAvailabilityView: View {
    @EnvironmentObject var appState: AppState

    @State private var experiences: [Experience] = []
    @State private var selectedExperienceId: String = ""

    @State private var slots: [AvailabilitySlot] = []
    @State private var start = Date()
    @State private var end = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        Form {
            Section("Experience") {
                if experiences.isEmpty {
                    Text("No experiences yet.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Select experience", selection: $selectedExperienceId) {
                        Text("Select…").tag("")
                        ForEach(experiences) { e in
                            Text(e.title).tag(e.id)
                        }
                    }
                }
            }

            Section("Add availability slot") {
                DatePicker("Start", selection: $start, displayedComponents: [.date, .hourAndMinute])
                DatePicker("End", selection: $end, displayedComponents: [.date, .hourAndMinute])

                Button("Add slot") {
                    Task { await addSlot() }
                }
                .disabled(isLoading || end <= start || selectedExperienceId.isEmpty)
            }

            if let message {
                Section {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Upcoming slots") {
                if slots.isEmpty {
                    Text(selectedExperienceId.isEmpty ? "Select an experience to manage availability." : "No slots yet. Add some availability.")
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
        .onChange(of: selectedExperienceId) { _, _ in
            Task { await loadSlots() }
        }
    }

    private func load() async {
        guard let hostEmail = appState.session.firebaseUser?.email else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            experiences = try await FirestoreService.shared.getExperiencesForHost(hostEmail: hostEmail)
            if selectedExperienceId.isEmpty, let first = experiences.first {
                selectedExperienceId = first.id
            }
            await loadSlots()
        } catch {
            experiences = []
            slots = []
        }
    }

    private func loadSlots() async {
        guard !selectedExperienceId.isEmpty else { slots = []; return }
        do {
            slots = try await FirestoreService.shared.getAvailabilityForListing(listingType: "experience", listingId: selectedExperienceId)
        } catch {
            slots = []
        }
    }

    private func addSlot() async {
        guard let hostEmail = appState.session.firebaseUser?.email else { return }
        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            let slot = AvailabilitySlot(
                id: UUID().uuidString,
                email: hostEmail,
                listingType: "experience",
                listingId: selectedExperienceId,
                start: start,
                end: end,
                status: .open,
                bookingId: nil,
                createdAt: Date()
            )
            try await FirestoreService.shared.createAvailability(slot)
            message = "Slot added ✅"
            await loadSlots()
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
            await loadSlots()
        } catch { }
    }
}
