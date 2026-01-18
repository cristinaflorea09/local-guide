import SwiftUI

struct ReportSheetView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let targetType: FeedReport.TargetType
    let targetId: String
    let postId: String?

    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var errorText: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 14) {
                    Text("Report")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Reason")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextEditor(text: $reason)
                                .frame(minHeight: 140)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if let errorText {
                        Text(errorText).foregroundStyle(.red)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting { ProgressView().tint(.black) } else { Text("Submit") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isSubmitting || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding(18)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
    }

    private func submit() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await FirestoreService.shared.report(
                targetType: targetType,
                targetId: targetId,
                postId: postId,
                reporterId: uid,
                reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
