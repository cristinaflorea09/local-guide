import SwiftUI

struct TermsView: View {
    @Environment(\.dismiss) var dismiss

    let markdown: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(.init(markdown))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(18)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Terms & Conditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Lx.gold)
                }
            }
        }
    }
}
