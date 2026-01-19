import SwiftUI

/// Lightweight earnings simulator for Romania (Bucharest / Cluj / Brasov presets).
struct EarningsSimulatorROView: View {
    struct Defaults {
        var guides: Int
        var hosts: Int
        var guideBookingsPerSeller: Int
        var hostBookingsPerSeller: Int
        var guideAvgPriceRON: Int
        var hostAvgPriceRON: Int
    }

    enum CityPreset: String, CaseIterable, Identifiable {
        case bucharest = "Bucharest"
        case cluj = "Cluj-Napoca"
        case brasov = "Brasov"

        var id: String { rawValue }

        var defaults: Defaults {
            switch self {
            case .bucharest:
                return Defaults(guides: 60, hosts: 30, guideBookingsPerSeller: 12, hostBookingsPerSeller: 14, guideAvgPriceRON: 140, hostAvgPriceRON: 360)
            case .cluj:
                return Defaults(guides: 35, hosts: 18, guideBookingsPerSeller: 10, hostBookingsPerSeller: 12, guideAvgPriceRON: 130, hostAvgPriceRON: 340)
            case .brasov:
                return Defaults(guides: 28, hosts: 14, guideBookingsPerSeller: 11, hostBookingsPerSeller: 13, guideAvgPriceRON: 150, hostAvgPriceRON: 380)
            }
        }
    }

    @State private var preset: CityPreset = .bucharest

    @State private var guides: Int = 60
    @State private var hosts: Int = 30
    @State private var guideBookings: Int = 12
    @State private var hostBookings: Int = 14
    @State private var guidePrice: Int = 140
    @State private var hostPrice: Int = 360

    // Starter commission rates
    @State private var guideCommission: Double = 0.15
    @State private var hostCommission: Double = 0.18

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Romania Earnings")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("Quick simulator for monthly earnings. Adjust the knobs to match your plan.")
                        .foregroundStyle(.white.opacity(0.7))

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preset").font(.headline)
                            Picker("City", selection: $preset) {
                                ForEach(CityPreset.allCases) { p in
                                    Text(p.rawValue).tag(p)
                                }
                            }
                            .pickerStyle(.menu)

                            Button("Apply preset") {
                                let d = preset.defaults
                                guides = d.guides
                                hosts = d.hosts
                                guideBookings = d.guideBookingsPerSeller
                                hostBookings = d.hostBookingsPerSeller
                                guidePrice = d.guideAvgPriceRON
                                hostPrice = d.hostAvgPriceRON
                                Haptics.light()
                            }
                            .buttonStyle(LuxurySecondaryButtonStyle())
                        }
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Supply")
                                .font(.headline)

                            Stepper("Guides: \(guides)", value: $guides, in: 0...2000)
                            Stepper("Hosts: \(hosts)", value: $hosts, in: 0...2000)

                            Divider().opacity(0.15)

                            Stepper("Bookings/Guide: \(guideBookings)", value: $guideBookings, in: 0...200)
                            Stepper("Bookings/Host: \(hostBookings)", value: $hostBookings, in: 0...200)
                        }
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pricing")
                                .font(.headline)

                            Stepper("Avg Tour Price (Guide): \(guidePrice) RON", value: $guidePrice, in: 0...5000, step: 10)
                            Stepper("Avg Experience Price (Host): \(hostPrice) RON", value: $hostPrice, in: 0...8000, step: 10)

                            Divider().opacity(0.15)

                            HStack {
                                Text("Guide commission")
                                Spacer()
                                Text("\(Int(guideCommission * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $guideCommission, in: 0.05...0.30, step: 0.01)

                            HStack {
                                Text("Host commission")
                                Spacer()
                                Text("\(Int(hostCommission * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $hostCommission, in: 0.05...0.30, step: 0.01)
                        }
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Results (monthly)")
                                .font(.headline)

                            resultRow("Guide GMV", valueRON: guideGMV)
                            resultRow("Host GMV", valueRON: hostGMV)
                            Divider().opacity(0.15)
                            resultRow("Total GMV", valueRON: totalGMV)

                            Divider().opacity(0.15)
                            resultRow("Your revenue (commission)", valueRON: platformRevenue)
                            Text("Tip: Stripe fees typically reduce net revenue by ~2–4% of GMV (depends on card & region).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .navigationTitle("Earnings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var guideGMV: Double {
        Double(guides * guideBookings * guidePrice)
    }
    private var hostGMV: Double {
        Double(hosts * hostBookings * hostPrice)
    }
    private var totalGMV: Double { guideGMV + hostGMV }
    private var platformRevenue: Double {
        (guideGMV * guideCommission) + (hostGMV * hostCommission)
    }

    private func resultRow(_ label: String, valueRON: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(Int(valueRON).formatted()) RON")
                .foregroundStyle(.secondary)
        }
    }
}
