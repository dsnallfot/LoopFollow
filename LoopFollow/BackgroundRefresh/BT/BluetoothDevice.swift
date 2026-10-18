//
//  BluetoothDevice.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-04.

//

import Foundation
import CoreBluetooth
import os
import UIKit

class BluetoothDevice: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    public weak var bluetoothDeviceDelegate: BluetoothDeviceDelegate?
    private(set) var deviceAddress:String
    private(set) var deviceName:String?
    private let CBUUID_Advertisement:String?
    private let servicesCBUUIDs:[CBUUID]?
    private let CBUUID_ReceiveCharacteristic:String
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var timeStampLastStatusUpdate:Date
    private var receiveCharacteristic:CBCharacteristic?
    private var shouldMaintainConnection = true
    var lastHeartbeatTime: Date?
    // --- Begin Dexcom force-disconnect watchdog additions ---
    private var lastConnectTime: Date?
    private var forceDisconnectWorkItem: DispatchWorkItem?
    // --- End Dexcom force-disconnect watchdog additions ---
    
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    init(address:String, name:String?, CBUUID_Advertisement:String?, servicesCBUUIDs:[CBUUID]?, CBUUID_ReceiveCharacteristic:String, bluetoothDeviceDelegate: BluetoothDeviceDelegate) {
        self.lastHeartbeatTime = nil
        self.deviceAddress = address
        self.deviceName = name

        self.servicesCBUUIDs = servicesCBUUIDs
        self.CBUUID_Advertisement = CBUUID_Advertisement
        self.CBUUID_ReceiveCharacteristic = CBUUID_ReceiveCharacteristic

        timeStampLastStatusUpdate = Date()

        self.bluetoothDeviceDelegate = bluetoothDeviceDelegate

        super.init()

        initialize()
    }

    deinit {
        // --- Begin Dexcom force-disconnect watchdog cleanup ---
        forceDisconnectWorkItem?.cancel()
        forceDisconnectWorkItem = nil
        // --- End Dexcom force-disconnect watchdog cleanup ---
        disconnect()
    }
    
    func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    func connect() {
        shouldMaintainConnection = true
        guard let central = centralManager, central.state == .poweredOn else { return }
        if let peripheral {
            resumeConnection(central, peripheral: peripheral)
        } else if !retrievePeripherals(central) {
            _ = startScanning()
        }
    }

    func disconnect() {
        shouldMaintainConnection = false
        forceDisconnectWorkItem?.cancel()
        forceDisconnectWorkItem = nil
        lastConnectTime = nil
        endBackgroundTask()
        centralManager?.stopScan()
        if let peripheral = peripheral {
            if let centralManager = centralManager {
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }

    func disconnectAndForget() {
        disconnect()

        peripheral = nil
        deviceName = nil
        //deviceAddress = nil
    }

    func stopScanning() {
        self.centralManager?.stopScan()
    }

    func isScanning() -> Bool {
        if let centralManager = centralManager {
            return centralManager.isScanning
        }
        return false
    }

    func startScanning() -> BluetoothDevice.startScanningResult {
        LogManager.shared.log(category: .bluetooth, message: "Start Scanning", isDebug: true, isTempDebug: true)

        var returnValue = BluetoothDevice.startScanningResult.unknown

        if let peripheral = peripheral {
            switch peripheral.state {
            case .connected:
                return .alreadyConnected
            case .connecting:
                // A pending CoreBluetooth connection survives suspension and can
                // wake/relaunch us when the sensor returns. Do not time it out.
                return .connecting
            default:()
            }
        }

        var services:[CBUUID]?
        if let CBUUID_Advertisement = CBUUID_Advertisement {
            services = [CBUUID(string: CBUUID_Advertisement)]
        }

        if let centralManager = centralManager {
            if centralManager.isScanning {
                return .alreadyScanning
            }
            switch centralManager.state {
            case .poweredOn:
                centralManager.scanForPeripherals(withServices: services, options: nil)
                returnValue = .success
            case .poweredOff:
                return .poweredOff
            case .unknown:
                return .unknown
            case .unauthorized:
                return .unauthorized
            default:
                return returnValue
            }
        } else {
            returnValue = .other(reason:"centralManager is nil, can not start scanning")
        }

        return returnValue
    }

    func readValueForCharacteristic(for characteristic: CBCharacteristic) {
        peripheral?.readValue(for: characteristic)
    }

    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        if let peripheral = peripheral {
            peripheral.setNotifyValue(enabled, for: characteristic)
        }
    }

    fileprivate func stopScanAndconnect(to peripheral: CBPeripheral) {
        LogManager.shared.log(category: .bluetooth, message: "Stop Scan And Connect", isDebug: true, isTempDebug: true)

        self.centralManager?.stopScan()
        self.deviceAddress = peripheral.identifier.uuidString
        self.deviceName = peripheral.name
        peripheral.delegate = self
        self.peripheral = peripheral

        if let central = centralManager { resumeConnection(central, peripheral: peripheral) }
    }

    private func resumeConnection(_ central: CBCentralManager, peripheral: CBPeripheral) {
        guard shouldMaintainConnection, central.state == .poweredOn else { return }
        peripheral.delegate = self
        switch peripheral.state {
        case .disconnected:
            central.connect(peripheral, options: nil)
        case .connected:
            // Restored connections need discovery/delegates, not another connect().
            if lastConnectTime == nil { centralManager(central, didConnect: peripheral) }
        case .connecting, .disconnecting:
            break // Preserve the pending operation and await its delegate callback.
        @unknown default:
            break
        }
    }

    fileprivate func retrievePeripherals(_ central:CBCentralManager) -> Bool {
        if let uuid = UUID(uuidString: deviceAddress) {
            //trace("    uuid is not nil", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
            let peripheralArr = central.retrievePeripherals(withIdentifiers: [uuid])
            if peripheralArr.count > 0 {
                peripheral = peripheralArr[0]
                if let peripheral = peripheral {
                    peripheral.delegate = self
                    resumeConnection(central, peripheral: peripheral)
                    return true
                }
            }
        }
        return false
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        LogManager.shared.log(category: .bluetooth, message: "[BLE] didDiscover", isDebug: true, isTempDebug: true)

        timeStampLastStatusUpdate = Date()

        if peripheral.identifier.uuidString == deviceAddress {
            stopScanAndconnect(to: peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard shouldMaintainConnection else {
            central.cancelPeripheralConnection(peripheral)
            return
        }
        self.peripheral = peripheral
        peripheral.delegate = self
        endBackgroundTask()
        // A finite execution allowance, not a guarantee against suspension.
        self.backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "DexcomWatchdog") { [weak self] in
            // Denna kod körs om tiden tar slut (t.ex. iOS tvingar vila)
            self?.endBackgroundTask()
        }

        timeStampLastStatusUpdate = Date()

        // --- Begin Dexcom force-disconnect watchdog ---
        lastConnectTime = Date()

        // Dexcom should normally connect briefly and then disconnect.
        // If iOS/CB stack gets stuck in a long-lived connected state, we proactively force a disconnect
        // so the next heartbeat cycle can occur and background tasks can keep running.
        forceDisconnectWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self, weak peripheral] in
            guard let self = self, let peripheral = peripheral else { return }
            // Only act if this is still our active peripheral (avoid stale work items after reconnects)
            if let current = self.peripheral, current.identifier != peripheral.identifier {
                return
            }
            if peripheral.state == .connected {
                let connectedFor = self.lastConnectTime.map { Date().timeIntervalSince($0) } ?? 0
                LogManager.shared.log(
                    category: .bluetooth,
                    message: "[BLE] Force-disconnecting after \(String(format: "%.1f", connectedFor))s connected (Dexcom expected short session)",
                    isDebug: true,
                    isTempDebug: true
                )
                // Ensure we call CoreBluetooth APIs on main (CBCentralManager queue is main for this class).
                DispatchQueue.main.async { [weak self] in
                    self?.centralManager?.cancelPeripheralConnection(peripheral)
                }
            }
            
            // OBS: Vi avslutar inte backgroundTask här inne.
            // Vi låter didDisconnect göra det, eftersom en force disconnect leder dit.
        }
        
        forceDisconnectWorkItem = workItem
        
        // CoreBluetooth operations must run on the same queue as the CBCentralManager was created on.
        // This BluetoothDevice creates CBCentralManager with `queue: nil` (main), so schedule on main.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0, execute: workItem)
        // --- End Dexcom force-disconnect watchdog ---

        bluetoothDeviceDelegate?.didConnectTo(bluetoothDevice: self)

        resumeDiscovery(peripheral)
    }

    private func resumeDiscovery(_ peripheral: CBPeripheral) {
        guard let services = peripheral.services, !services.isEmpty,
              servicesCBUUIDs?.allSatisfy({ expected in services.contains { $0.uuid == expected } }) ?? true else {
            peripheral.discoverServices(servicesCBUUIDs)
            return
        }
        for service in services {
            if service.characteristics == nil {
                peripheral.discoverCharacteristics(nil, for: service)
            } else {
                self.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: nil)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        timeStampLastStatusUpdate = Date()

        // --- Begin Dexcom force-disconnect watchdog cleanup ---
        forceDisconnectWorkItem?.cancel()
        forceDisconnectWorkItem = nil
        lastConnectTime = nil
        // --- End Dexcom force-disconnect watchdog cleanup ---

        let peripheralName = peripheral.name ?? "Unknown"
        let errorMessage = error?.localizedDescription ?? "No error details provided"

        LogManager.shared.log(category: .bluetooth, message: "Failed to connect to peripheral '\(peripheralName)' (UUID: \(peripheral.identifier.uuidString)). Error: \(errorMessage). Retrying...")

        endBackgroundTask()
        if shouldMaintainConnection, central.state == .poweredOn {
            central.connect(peripheral, options: nil)
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        LogManager.shared.log(category: .bluetooth, message: "Central Manager Did Update State", isDebug: true, isTempDebug: true)

        timeStampLastStatusUpdate = Date()

        if central.state == .poweredOn, shouldMaintainConnection {
            connect()
        } else if central.state == .resetting || central.state == .poweredOff {
            forceDisconnectWorkItem?.cancel()
            forceDisconnectWorkItem = nil
            lastConnectTime = nil
            receiveCharacteristic = nil
            peripheral = nil
            endBackgroundTask()
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        timeStampLastStatusUpdate = Date()
        
        // Avsluta bakgrundsuppgiften nu när vi är klara
        endBackgroundTask()

        // Connection ended; cancel any pending force-disconnect watchdog.
        forceDisconnectWorkItem?.cancel()
        forceDisconnectWorkItem = nil
        lastConnectTime = nil

        bluetoothDeviceDelegate?.didDisconnectFrom(bluetoothDevice: self)

        if let error = error {
            LogManager.shared.log(category: .bluetooth, message: "[BLE] didDisconnectPeripheral error: \(error.localizedDescription)", isDebug: true, isTempDebug: true)
        }

        if shouldMaintainConnection, central.state == .poweredOn, let ownPeripheral = self.peripheral {
            centralManager?.connect(ownPeripheral, options: nil)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        timeStampLastStatusUpdate = Date()

        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        } else {
            // A transient discovery error should reconnect, not disable monitoring.
            centralManager?.cancelPeripheralConnection(peripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        timeStampLastStatusUpdate = Date()

        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == CBUUID(string: CBUUID_ReceiveCharacteristic) {
                    receiveCharacteristic = characteristic
                    if !characteristic.isNotifying { peripheral.setNotifyValue(true, for: characteristic) }
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        timeStampLastStatusUpdate = Date()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        timeStampLastStatusUpdate = Date()

        if let error = error {
            LogManager.shared.log(category: .bluetooth, message: "[BLE] didUpdateNotificationState error: \(error.localizedDescription)", isDebug: true, isTempDebug: true)
        } else {
            LogManager.shared.log(category: .bluetooth, message: "[BLE] Notifications \(characteristic.isNotifying ? "ENABLED" : "DISABLED") for \(characteristic.uuid.uuidString)", isDebug: true, isTempDebug: true)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        timeStampLastStatusUpdate = Date()

        // Treat any notify update from the receive characteristic as a "heartbeat".
        // This is important because iOS may keep the peripheral connected for long periods,
        // which would otherwise prevent our disconnect-driven heartbeat from firing.
        if characteristic.uuid == CBUUID(string: CBUUID_ReceiveCharacteristic) {
            let now = Date()
            self.lastHeartbeatTime = now

            // Log lightly (temp debug) so we can correlate with background wakeups.
            LogManager.shared.log(
                category: .bluetooth,
                message: "[BLE] didUpdateValue (heartbeat) from: \(deviceName ?? "Unknown")",
                isDebug: true,
                isTempDebug: true
            )

            bluetoothDeviceDelegate?.heartBeat(source: "didUpdateValue")
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        guard let selected = restored.first(where: { $0.identifier.uuidString == deviceAddress }) else {
            LogManager.shared.log(category: .bluetooth, message: "BLE restoration: selected peripheral absent; retrieve/scan when powered on")
            return
        }
        peripheral = selected
        selected.delegate = self
        deviceName = selected.name ?? deviceName
        LogManager.shared.log(category: .bluetooth,
            message: "BLE restoration: adopted selected peripheral, state=\(selected.state.rawValue)")
        // willRestoreState can precede poweredOn. Retain/delegate now, perform
        // CoreBluetooth operations only once the central is ready.
        resumeConnection(central, peripheral: selected)
    }

    private func initialize() {
        var cBCentralManagerOptionRestoreIdentifierKeyToUse: String?

        cBCentralManagerOptionRestoreIdentifierKeyToUse = "LoopFollow-" + deviceAddress

        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true, CBCentralManagerOptionRestoreIdentifierKey: cBCentralManagerOptionRestoreIdentifierKeyToUse!])
    }

    enum startScanningResult: Equatable {
        case success
        case alreadyScanning
        case poweredOff
        case alreadyConnected
        case connecting
        case unknown
        case unauthorized
        case nfcScanNeeded
        case other(reason:String)

        func description() -> String {
            switch self {
            case .success:
                return "success"
            case .alreadyScanning:
                return "alreadyScanning"
            case .poweredOff:
                return "poweredOff"
            case .alreadyConnected:
                return "alreadyConnected"
            case .connecting:
                return "connecting"
            case .other(let reason):
                return "other reason : " + reason
            case .unknown:
                return "unknown"
            case .unauthorized:
                return "unauthorized"
            case .nfcScanNeeded:
                return "nfcScanNeeded"
            }
        }
    }

    func expectedHeartbeatInterval() -> TimeInterval? {
        return nil
    }
}
