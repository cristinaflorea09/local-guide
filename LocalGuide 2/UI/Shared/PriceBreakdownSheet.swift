import SwiftUI

struct PriceBreakdownSheet: View {
    let pricePerPerson: Double
    let peopleCount: Int
    let isPremium: Bool

    var base: Double { Double(peopleCount) * pricePerPerson }
    var discount: Double { isPremium ? base * 0.10 : 0 }
    var serviceFee: Double { 0 } // keep 0 for now (add later if desired)
    var total: Double { base - discount + serviceFee }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("Price breakdown")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                LuxuryCard {
                    VStack(spacing: 10) {
                        row("€\(String(format: "%.2f", pricePerPerson)) × \(peopleCount)", base)
                        row("Service fee", serviceFee)
                        if isPremium {
                            row("Premium discount", -discount)
                        }
                        Divider().opacity(0.15)
                        row("Total", total, isTotal: true)
                    }
                }

                Text("No hidden fees. You’ll see the final amount before paying.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
            }
            .padding(18)
        }
    }

    @Environment(\.dismiss) private var dismiss

    @ViewBuilder
    private func row(_ label: String, _ value: Double, isTotal: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(isTotal ? .primary : .secondary)
            Spacer()
            Text("€\(value, specifier: "%.2f")")
                .foregroundStyle(isTotal ? .primary : .secondary)
                .font(isTotal ? .headline : .body)
        }
    }
}
