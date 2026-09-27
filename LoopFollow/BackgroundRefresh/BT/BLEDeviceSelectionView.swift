//
//  BLEDeviceSelectionView.swift
//  LoopFollow
//

import SwiftUI

struct BLEDeviceSelectionView: View {
    // The parent observes BLEManager and supplies the shared hit calculation.
    let bleManager: BLEManager
    var devices: [BLEDevice]
    var selectedDeviceID: UUID?
    var selectedFilter: BackgroundRefreshType
    var hitDeviceIDs: Set<UUID>
    var onSelectDevice: (BLEDevice) -> Void

    // MARK: - Constants for Activation Date thresholds
    let daysOld = 60
    let manyDaysOld = 75

    // MARK: - Constants for BG delay thresholds
    let goodDelay = 90
    let okDelay = 180
    
    // Shared formatter for activation dates
    private static let activationFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }()

    // MARK: - Computed Property for Filtered Devices
    var filteredDevices: [BLEDevice] {
        devices.filter { selectedFilter.matches($0) && $0.id != selectedDeviceID }
    }

    @State private var showConfirmAlert: Bool = false
    @State private var pendingDevice: BLEDevice?

    // MARK: - Body
    var body: some View {
        let dexcomMode = Storage.shared.backgroundRefreshType.value == .dexcom
        let filteredDevices = self.filteredDevices

        return VStack(alignment: .leading, spacing: 0) {
            if filteredDevices.isEmpty {
                Text("Inga enheter funna ännu. De dyker upp här när de har identifierats.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredDevices, id: \.id) { (device: BLEDevice) in
                        VStack(alignment: .leading, spacing: 2) {
                            // Device Name
                            let deviceName = device.name ?? "Okänd"
                            let isHit = hitDeviceIDs.contains(device.id)
                            Text(isHit ? "* \(deviceName)" : deviceName)

                            // RSSI
                            Text("RSSI: \(device.rssi) dBm")
                                .foregroundColor(.secondary)
                                .font(.footnote)

                            // Sensor Activation Date with color logic
                            if let sensorID = device.name,
                               let activationDateStr = Storage.shared.latestActivationDate(for: sensorID) {
                                Group {
                                    let formatter = Self.activationFormatter

                                    if let activationDate = formatter.date(from: activationDateStr) {
                                        // Compute threshold dates
                                        let orangeThreshold = Calendar.current.date(byAdding: .day, value: -daysOld, to: Date())!
                                        let redThreshold = Calendar.current.date(byAdding: .day, value: -manyDaysOld, to: Date())!

                                        // Determine the color
                                        let activationColor: Color = activationDate < redThreshold ? .red : (activationDate < orangeThreshold ? .orange : .secondary)
                                        HStack {
                                            Text("Aktiverades:")
                                                .foregroundColor(.secondary)
                                                .font(.footnote)
                                            Text("\(activationDateStr)")
                                                .foregroundColor(activationColor)
                                                .font(.footnote)
                                        }
                                    } else {
                                        Text("Aktiverades: \(activationDateStr)")
                                            .foregroundColor(.secondary)
                                            .font(.footnote)
                                    }
                                }
                            }

                            // Expected BG Delay with color logic (for Dexcom devices only)
                            if dexcomMode,
                               let offsetStr = BLEManager.shared.expectedSensorFetchOffsetString(for: device) {
                                Group {
                                    // Expect offset string like "120 sek" – get the number portion.
                                    let offsetNumberString = offsetStr.components(separatedBy: " ").first ?? ""
                                    if let offsetInt = Int(offsetNumberString) {
                                        let offsetColor: Color = offsetInt > okDelay ? .red : (offsetInt > goodDelay ? .orange : .green)
                                        HStack {
                                            Text("Förväntad fördröjning BG:")
                                                .foregroundColor(.secondary)
                                                .font(.footnote)
                                            Text("\(offsetInt) sek")
                                                .foregroundColor(offsetColor)
                                                .font(.footnote)
                                        }

                                        // Offset you should enter in SyncNewSensorView so the *new* sensor reports ~30s before THIS device.
                                        // We want: (deviceDelay + pairingOffset) % 300 == 30
                                        let targetDelay = 50
                                        let optimalPairingOffset = ((targetDelay - offsetInt) % 300 + 300) % 300

                                        HStack {
                                            Text("Optimal offset nästa sensorbyte:")
                                                .foregroundColor(.secondary)
                                                .font(.footnote)

                                            Text("\(optimalPairingOffset) sek")
                                                .foregroundColor(.secondary)
                                                .font(.footnote)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            pendingDevice = device
                            showConfirmAlert = true
                        }
                        .alert("Ställ in enhet för heartbeat", isPresented: $showConfirmAlert) {
                            Button("Ja") {
                                if let device = pendingDevice {
                                    onSelectDevice(device)
                                }
                                pendingDevice = nil
                            }
                            Button("Avbryt", role: .cancel) {
                                pendingDevice = nil
                            }
                        } message: {
                            if let name = pendingDevice?.name {
                                Text("\nVill du använda \(name) för att väcka appen i bakgrunden?")
                            }
                        }

                        // Divider between rows
                        Divider().opacity(0.8)
                    }
                }
            }
        }
        .onAppear {
            bleManager.startScanning()
        }
        .onDisappear {
            bleManager.stopScanning()
        }
    }

}
