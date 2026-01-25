import SwiftUI

struct GuideAvailabilityView: View {
    @EnvironmentObject var appState: AppState
    @State private var slots: [AvailabilitySlot] = []
    @State private var tours: [Tour] = []
    @State private var selectedTourId: String = ""
    @State private var start = Date()
    @State private var end = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        Form {
                Section("Tour") {
                    if tours.isEmpty {
                        Text("No tours yet.").foregroundStyle(.secondary)
                    } else {
                        Picker("Select tour", selection: $selectedTourId) {
                            Text("Select…").tag("")
                            ForEach(tours) { t in
                                Text(t.title).tag(t.id)
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
                    .disabled(isLoading || end <= start || selectedTourId.isEmpty)
                }

                if let message {
                    Section { Text(message).foregroundStyle(.secondary) }
                }

                Section("Upcoming slots") {
                    if slots.isEmpty {
                        Text(selectedTourId.isEmpty ? "Select a tour to manage availability." : "No slots yet. Add some availability.")
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
            .onAppear { Task { await load() } }
            .onChange(of: selectedTourId) { _, _ in Task { await loadSlots() } }
    }

    private func load() async {
        guard let email = appState.session.firebaseUser?.email else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            tours = try await FirestoreService.shared.getToursForGuide(guideEmail: email)
            if selectedTourId.isEmpty, let first = tours.first { selectedTourId = first.id }
            await loadSlots()
        } catch {
            tours = []
            slots = []
        }
    }

    private func loadSlots() async {
        guard !selectedTourId.isEmpty else { slots = []; return }
        do {
            slots = try await FirestoreService.shared.getAvailabilityForListing(listingType: "tour", listingId: selectedTourId)
        } catch {
            slots = []
        }
    }

    private func addSlot() async {
        guard let email = appState.session.firebaseUser?.email else { return }
        isLoading = true
        message = nil
        do {
            let slot = AvailabilitySlot(
                id: UUID().uuidString,
                email: email,
                listingType: "tour",
                listingId: selectedTourId,
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
        isLoading = false
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
