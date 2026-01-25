import SwiftUI

struct SellerFinanceSettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var vatRegistered: Bool = false
    @State private var vatRate: Int = 19
    @State private var toast: String?

    var body: some View {
        Form {
            Section("VAT") {
                Toggle("VAT registered", isOn: $vatRegistered)
                Stepper("VAT rate: \(vatRate)%", value: $vatRate, in: 0...30)
                    .disabled(!vatRegistered)
                Text("If your prices include VAT, the report will compute the VAT component from gross.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Save") {
                    Task { await save() }
                }
            }
        }
        .navigationTitle("Tax settings")
        .onAppear { loadInitial() }
        .alert("", isPresented: Binding(get: { toast != nil }, set: { if !$0 { toast = nil } })) {
            Button("OK", role: .cancel) { toast = nil }
        } message: {
            Text(toast ?? "")
        }
    }

    private func loadInitial() {
        vatRegistered = appState.session.currentUser?.vatRegistered ?? false
        vatRate = appState.session.currentUser?.vatRate ?? 19
    }

    private func save() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        let docId = appState.session.currentUser?.id ?? uid
        do {
            try await FirestoreService.shared.updateUser(uid: docId, fields: [
                "vatRegistered": vatRegistered,
                "vatRate": vatRate
            ])
            // Update session copy
            appState.session.currentUser?.vatRegistered = vatRegistered
            appState.session.currentUser?.vatRate = vatRate
            toast = "Saved ✅"
            await MainActor.run { dismiss() }
        } catch {
            toast = error.localizedDescription
        }
    }
}
