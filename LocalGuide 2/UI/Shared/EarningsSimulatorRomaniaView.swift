import SwiftUI

struct EarningsSimulatorRomaniaView: View {
    struct CityPreset: Identifiable {
        let id = UUID()
        let city: String
        let avgTourRON: Double
        let avgExperienceRON: Double
        let guideBookingsPerMonth: Int
        let hostBookingsPerMonth: Int
    }

    private let presets: [CityPreset] = [
        .init(city: "Bucharest", avgTourRON: 140, avgExperienceRON: 350, guideBookingsPerMonth: 12, hostBookingsPerMonth: 14),
        .init(city: "Cluj-Napoca", avgTourRON: 130, avgExperienceRON: 320, guideBookingsPerMonth: 10, hostBookingsPerMonth: 12),
        .init(city: "Brașov", avgTourRON: 150, avgExperienceRON: 380, guideBookingsPerMonth: 14, hostBookingsPerMonth: 16),
        .init(city: "Timișoara", avgTourRON: 120, avgExperienceRON: 300, guideBookingsPerMonth: 9, hostBookingsPerMonth: 10)
    ]

    @State private var selected = 0
    @State private var guides = 50
    @State private var hosts = 25
    @State private var guideCommission = 0.15
    @State private var hostCommission = 0.18

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Romania Earnings Simulator")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("City", selection: $selected) {
                                ForEach(Array(presets.enumerated()), id: \.offset) { idx, p in
                                    Text(p.city).tag(idx)
                                }
                            }
                            .pickerStyle(.menu)

                            Stepper("Guides: \(guides)", value: $guides, in: 0...2000)
                            Stepper("Hosts: \(hosts)", value: $hosts, in: 0...2000)

                            HStack {
                                Text("Guide commission")
                                Spacer()
                                Text("\(Int(guideCommission * 100))%")
                            }
                            Slider(value: $guideCommission, in: 0.05...0.25, step: 0.01)

                            HStack {
                                Text("Host commission")
                                Spacer()
                                Text("\(Int(hostCommission * 100))%")
                            }
                            Slider(value: $hostCommission, in: 0.08...0.30, step: 0.01)
                        }
                    }

                    let p = presets[selected]
                    let guideGMV = Double(guides * p.guideBookingsPerMonth) * p.avgTourRON
                    let hostGMV = Double(hosts * p.hostBookingsPerMonth) * p.avgExperienceRON
                    let totalGMV = guideGMV + hostGMV
                    let revenue = guideGMV * guideCommission + hostGMV * hostCommission

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Assumptions for \(p.city)")
                                .font(.headline)
                            Text("Avg tour: \(Int(p.avgTourRON)) RON • Bookings/guide: \(p.guideBookingsPerMonth)/mo")
                                .foregroundStyle(.secondary)
                            Text("Avg experience: \(Int(p.avgExperienceRON)) RON • Bookings/host: \(p.hostBookingsPerMonth)/mo")
                                .foregroundStyle(.secondary)
                            Divider().opacity(0.15)
                            HStack { Text("Guide GMV"); Spacer(); Text(String(format: "%.0f RON", guideGMV)).foregroundStyle(.secondary) }
                            HStack { Text("Host GMV"); Spacer(); Text(String(format: "%.0f RON", hostGMV)).foregroundStyle(.secondary) }
                            HStack { Text("Total GMV"); Spacer(); Text(String(format: "%.0f RON", totalGMV)).foregroundStyle(.secondary) }
                            Divider().opacity(0.15)
                            HStack {
                                Text("Est. platform revenue")
                                    .font(.headline)
                                Spacer()
                                Text(String(format: "%.0f RON / month", revenue))
                                    .font(.headline)
                                    .foregroundStyle(Lx.gold)
                            }
                        }
                    }

                    Text("Tip: for Romania, Hosts often drive more revenue due to higher average price and group bookings.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))

                    Spacer(minLength: 10)
                }
                .padding(18)
            }
        }
        .navigationTitle("Simulator")
        .navigationBarTitleDisplayMode(.inline)
    }
}
