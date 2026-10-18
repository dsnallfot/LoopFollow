#!/usr/bin/env python3
"""Exercise production BLE owners against a deterministic CoreBluetooth substitute.
Radio delivery/relaunch remains a physical-device test; no real BLE or alarms used.
"""
from pathlib import Path
import os, re, subprocess, tempfile
repo = Path(__file__).resolve().parents[1]
base = repo / 'LoopFollow/BackgroundRefresh/BT'
files = ['BLEDevice.swift', 'BluetoothDeviceDelegate.swift', 'BluetoothDevice.swift',
         'Devices/DexcomHeartbeatBluetoothDevice.swift', 'Devices/RileyLinkHeartbeatBluetoothDevice.swift', 'BLEManager.swift']
sources = []
for file in files:
    source = (base / file).read_text()
    if file == 'BLEManager.swift':
        source = source[:source.index('\nextension BLEManager {')]
    sources.append(re.sub(r'^import (CoreBluetooth|UIKit|AVFoundation|os)\n', '', source, flags=re.M))
stubs = r'''
import Foundation
import Combine
protocol CBCentralManagerDelegate: AnyObject {}
protocol CBPeripheralDelegate: AnyObject {}
struct CBUUID: Equatable { var uuidString: String; init(string: String) { uuidString = string } }
enum CBManagerState: Int { case unknown, resetting, unsupported, unauthorized, poweredOff, poweredOn }
enum CBPeripheralState: Int { case disconnected, connecting, connected, disconnecting }
let CBCentralManagerOptionShowPowerAlertKey = "show"
let CBCentralManagerOptionRestoreIdentifierKey = "restore"
let CBCentralManagerRestoredStatePeripheralsKey = "peripherals"
let CBCentralManagerRestoredStateScanServicesKey = "services"
let CBAdvertisementDataServiceUUIDsKey = "advertisement"
class CBCharacteristic {
    let uuid: CBUUID
    var isNotifying = false
    var value: Data?
    init(_ uuid: String) { self.uuid = CBUUID(string: uuid) }
}
class CBService {
    let uuid: CBUUID
    var characteristics: [CBCharacteristic]?
    init(_ uuid: String, characteristics: [CBCharacteristic]? = nil) {
        self.uuid = CBUUID(string: uuid); self.characteristics = characteristics
    }
}
class CBPeripheral {
    let identifier: UUID
    var name: String? = "Dexcom"
    weak var delegate: CBPeripheralDelegate?
    var state = CBPeripheralState.disconnected
    var services: [CBService]?
    var serviceDiscoveries = 0, characteristicDiscoveries = 0, subscriptions = 0
    init(_ id: UUID = UUID()) { identifier = id }
    func discoverServices(_ ids: [CBUUID]?) { serviceDiscoveries += 1 }
    func discoverCharacteristics(_ ids: [CBUUID]?, for service: CBService) { characteristicDiscoveries += 1 }
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) { subscriptions += 1; characteristic.isNotifying = enabled }
    func readValue(for characteristic: CBCharacteristic) {}
}
class CBCentralManager {
    static var created: [CBCentralManager] = []
    var state = CBManagerState.unknown
    var isScanning = false
    weak var delegate: CBCentralManagerDelegate?
    let options: [String: Any]?
    var retrieved: [CBPeripheral] = []
    var connects = 0, cancels = 0
    init(delegate: CBCentralManagerDelegate, queue: DispatchQueue?, options: [String: Any]?) {
        self.delegate = delegate; self.options = options; Self.created.append(self)
    }
    func retrievePeripherals(withIdentifiers: [UUID]) -> [CBPeripheral] { retrieved }
    func connect(_ peripheral: CBPeripheral, options: [String: Any]?) { connects += 1; peripheral.state = .connecting }
    func cancelPeripheralConnection(_ peripheral: CBPeripheral) { cancels += 1; peripheral.state = .disconnecting }
    func scanForPeripherals(withServices: [CBUUID]?, options: [String: Any]?) { isScanning = true }
    func stopScan() { isScanning = false }
}
struct UIBackgroundTaskIdentifier: Hashable { let value: Int; static let invalid = Self(value: -1) }
class UIApplication {
    static let shared = UIApplication()
    var next = 0
    var live = Set<UIBackgroundTaskIdentifier>()
    func beginBackgroundTask(withName: String, expirationHandler: @escaping () -> Void) -> UIBackgroundTaskIdentifier {
        next += 1; let id = UIBackgroundTaskIdentifier(value: next); live.insert(id); return id
    }
    func endBackgroundTask(_ id: UIBackgroundTaskIdentifier) { precondition(live.remove(id) != nil) }
}
class LogManager {
    enum Category { case bluetooth }
    static let shared = LogManager()
    func log(category: Category, message: String, isDebug: Bool = false, isTempDebug: Bool = false) {}
}
class Value<T> { var value: T; init(_ value: T) { self.value = value } }
enum BackgroundRefreshType: CaseIterable {
    case dexcom, rileyLink, silentTune, none
    func matches(_ device: BLEDevice) -> Bool { self == .dexcom }
}
class Storage {
    static let shared = Storage()
    let selectedBLEDevice = Value<BLEDevice?>(nil)
    let backgroundRefreshType = Value(BackgroundRefreshType.dexcom)
    func recordBluetoothPing(date: Date) {}
}
class TaskScheduler { static let shared = TaskScheduler(); func checkTasksNow() {} }
class Delegate: BluetoothDeviceDelegate {
    var connections = 0
    func didConnectTo(bluetoothDevice: BluetoothDevice) { connections += 1 }
    func didDisconnectFrom(bluetoothDevice: BluetoothDevice) {}
    func heartBeat(source: String) {}
}
@main struct Tests {
    @MainActor static func main() async {
        let delegate = Delegate()
        let id = UUID()
        let device = DexcomHeartbeatBluetoothDevice(address: id.uuidString, name: "Dexcom", bluetoothDeviceDelegate: delegate)
        let central = CBCentralManager.created.last!
        device.connect() // Not powered on: no illegal retrieve/connect/scan.
        precondition(central.connects == 0 && !central.isScanning)
        let pending = CBPeripheral(id); pending.state = .connecting
        device.centralManager(central, willRestoreState: [CBCentralManagerRestoredStatePeripheralsKey: [pending]])
        precondition(pending.delegate === device && central.connects == 0)
        central.state = .poweredOn
        device.centralManagerDidUpdateState(central)
        device.connect()
        precondition(central.connects == 0 && central.cancels == 0 && !central.isScanning)
        precondition(device.startScanning() == .connecting)
        // A connected restore adopts existing services/subscription without reconnect.
        pending.state = .connected
        let receive = CBCharacteristic("F8083535-849E-531C-C594-30F1F86A4EA5")
        receive.isNotifying = true
        pending.services = [CBService("F8083532-849E-531C-C594-30F1F86A4EA5", characteristics: [receive])]
        device.centralManager(central, willRestoreState: [CBCentralManagerRestoredStatePeripheralsKey: [pending]])
        device.centralManagerDidUpdateState(central)
        device.connect()
        precondition(delegate.connections == 1 && central.connects == 0)
        precondition(pending.serviceDiscoveries == 0 && pending.subscriptions == 0)
        precondition(UIApplication.shared.live.count == 1)
        // Disconnect rearms the long-lived connection; an explicit stop does not.
        pending.state = .disconnected
        device.centralManager(central, didDisconnectPeripheral: pending, error: nil)
        precondition(central.connects == 1 && UIApplication.shared.live.isEmpty)
        device.disconnect()
        pending.state = .disconnected
        device.centralManager(central, didDisconnectPeripheral: pending, error: nil)
        device.centralManagerDidUpdateState(central)
        precondition(central.connects == 1)
        // Bluetooth reset loses cached objects; poweredOn can recover via a filtered scan.
        device.connect()
        central.state = .resetting
        device.centralManagerDidUpdateState(central)
        central.state = .poweredOn
        device.centralManagerDidUpdateState(central)
        precondition(central.isScanning)
        let discovered = CBPeripheral(id)
        device.centralManager(central, didDiscover: discovered, advertisementData: [:], rssi: -50)
        precondition(discovered.state == .connecting && !central.isScanning)
        discovered.state = .connected
        device.centralManager(central, didConnect: discovered)
        precondition(discovered.serviceDiscoveries == 1) // Missing cached services.
        device.disconnect()
        // Actual BLEManager init + poweredOn + repeated selection must retain one owner.
        let selected = BLEDevice(id: UUID(), name: "Dexcom", rssi: -50)
        Storage.shared.selectedBLEDevice.value = selected
        let count = CBCentralManager.created.count
        let manager = BLEManager.shared
        let scanner = CBCentralManager.created[count]
        let owner = manager.activeDevice!
        precondition(scanner.options?[CBCentralManagerOptionRestoreIdentifierKey] == nil)
        scanner.state = .poweredOn
        for _ in 0..<10 { manager.centralManagerDidUpdateState(scanner); manager.connect(device: selected) }
        try! await Task.sleep(nanoseconds: 30_000_000)
        precondition(manager.activeDevice === owner)
        precondition(CBCentralManager.created.count == count + 2)
        manager.disconnect()
        print("PASS: pending/connected restoration, delegates/subscriptions, discovery, explicit stop, reset/scan, single connection owner")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='lf-ble-tests-') as tmp:
    source = Path(tmp) / 'Tests.swift'
    source.write_text(stubs + '\n'.join(sources))
    binary = Path(tmp) / 'tests'
    env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(Path(tmp) / 'modules'))
    subprocess.run(['swiftc', '-swift-version', '5', '-parse-as-library', str(source), '-o', str(binary)], check=True, env=env)
    subprocess.run([str(binary)], check=True, env=env, timeout=30)
