import SwiftUI

/// Lightweight earnings simulator for Romania (Bucharest / Cluj / Brasov presets).
struct EarningsSimulatorROView: View {
    @EnvironmentObject var appState: AppState
    struct Defaults {
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
                return Defaults(guideBookingsPerSeller: 12, hostBookingsPerSeller: 14, guideAvgPriceRON: 140, hostAvgPriceRON: 360)
            case .cluj:
                return Defaults(guideBookingsPerSeller: 10, hostBookingsPerSeller: 12, guideAvgPriceRON: 130, hostAvgPriceRON: 340)
            case .brasov:
                return Defaults(guideBookingsPerSeller: 11, hostBookingsPerSeller: 13, guideAvgPriceRON: 150, hostAvgPriceRON: 380)
            }
        }
    }

    @State private var preset: CityPreset = .bucharest

    @State private var guideBookings: Int = 12
    @State private var hostBookings: Int = 14
    @State private var guidePrice: Int = 140
    @State private var hostPrice: Int = 360

    // Starter commission rates
    @State private var guideCommission: Double = 0.15
    @State private var hostCommission: Double = 0.18

    private var showGuide: Bool {
        appState.session.currentUser?.role != .host
    }
    private var showHost: Bool {
        appState.session.currentUser?.role != .guide
    }

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

                            if showGuide {
                                Stepper("Bookings/Guide: \(guideBookings)", value: $guideBookings, in: 0...200)
                            }
                            if showHost {
                                Stepper("Bookings/Host: \(hostBookings)", value: $hostBookings, in: 0...200)
                            }
                        }
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pricing")
                                .font(.headline)

                            if showGuide {
                                Stepper("Avg Tour Price (Guide): \(guidePrice) RON", value: $guidePrice, in: 0...5000, step: 10)
                            }
                            if showHost {
                                Stepper("Avg Experience Price (Host): \(hostPrice) RON", value: $hostPrice, in: 0...8000, step: 10)
                            }

                            Divider().opacity(0.15)

                            if showGuide {
                                HStack {
                                    Text("Guide commission")
                                    Spacer()
                                    Text("\(Int(guideCommission * 100))%")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $guideCommission, in: 0.05...0.30, step: 0.01)
                            }

                            if showHost {
                                HStack {
                                    Text("Host commission")
                                    Spacer()
                                    Text("\(Int(hostCommission * 100))%")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $hostCommission, in: 0.05...0.30, step: 0.01)
                            }
                        }
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Results (monthly)")
                                .font(.headline)

                            if showGuide {
                                resultRow("Guide earnings", valueRON: guideGMV)
                                resultRow("Total Guide earnings after comission", valueRON: guideGMV - (guideCommission * guideGMV))

                            }
                            if showHost {
                                resultRow("Host earnings", valueRON: hostGMV)
                                resultRow("Total Host earnings after commission", valueRON: hostGMV - (hostCommission * hostGMV))

                            }
                            Divider().opacity(0.15)
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
        Double(guideBookings * guidePrice)
    }
    private var hostGMV: Double {
        Double(hostBookings * hostPrice)
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
