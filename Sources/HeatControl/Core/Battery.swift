import Foundation
import IOKit

// Параметры батареи из реестра AppleSmartBattery — тот же источник,
// что у coconutBattery. Читается без root.

struct BatteryInfo: Equatable {
    var percent: Int                 // заряд, %
    var isCharging: Bool
    var externalConnected: Bool
    var fullyCharged: Bool
    var timeRemainingMinutes: Int?   // до полного / до пустого, по состоянию

    var currentCapacitymAh: Int      // AppleRawCurrentCapacity
    var fullChargeCapacitymAh: Int   // NominalChargeCapacity (фактическая ёмкость)
    var designCapacitymAh: Int
    var cycleCount: Int

    var temperature: Double          // °C
    var voltage: Double              // V
    var amperage: Double             // A, знак: + заряд, − разряд
    var batteryWatts: Double         // V × A, знаковая мощность батареи
    var systemWatts: Double?         // потребление системы (телеметрия SMC)

    var adapterWatts: Int?
    var adapterName: String?
    var adapterVolts: Double?
    var adapterAmps: Double?

    var serial: String
    var deviceName: String

    var healthPercent: Double {
        designCapacitymAh > 0
            ? Double(fullChargeCapacitymAh) / Double(designCapacitymAh) * 100
            : 0
    }
}

// Доступ только с очереди сэмплера; сервис неизменяем после init
final class BatteryReader: @unchecked Sendable {

    private var service: io_registry_entry_t = 0

    init() {
        service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
    }

    deinit {
        if service != 0 { IOObjectRelease(service) }
    }

    var isAvailable: Bool { service != 0 }

    func sample() -> BatteryInfo? {
        guard service != 0 else { return nil }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { return nil }

        func int(_ key: String) -> Int? { dict[key] as? Int }
        func bool(_ key: String) -> Bool { dict[key] as? Bool ?? false }

        guard dict["BatteryInstalled"] as? Bool ?? true else { return nil }

        let percent = int("CurrentCapacity") ?? 0
        let isCharging = bool("IsCharging")
        let external = bool("ExternalConnected")
        let fullyCharged = bool("FullyCharged")

        // 65535 — сентинел "неизвестно/вычисляется"
        func minutes(_ key: String) -> Int? {
            guard let v = int(key), v > 0, v < 65535 else { return nil }
            return v
        }
        let timeRemaining = isCharging
            ? (minutes("AvgTimeToFull") ?? minutes("TimeRemaining"))
            : (external ? nil : (minutes("AvgTimeToEmpty") ?? minutes("TimeRemaining")))

        let rawCurrent = int("AppleRawCurrentCapacity") ?? 0
        let rawMax = int("AppleRawMaxCapacity") ?? 0
        let nominal = int("NominalChargeCapacity") ?? rawMax
        let design = int("DesignCapacity") ?? 0
        let cycles = int("CycleCount") ?? 0

        let temperature = Double(int("Temperature") ?? 0) / 100.0
        let voltage = Double(int("Voltage") ?? 0) / 1000.0
        let amperage = Double(int("Amperage") ?? 0) / 1000.0
        let batteryWatts = voltage * amperage

        // Телеметрия SMC: реальное потребление системы.
        // На питании — от адаптера (SystemPowerIn), на батарее — BatteryPower.
        var systemWatts: Double?
        if let telemetry = dict["PowerTelemetryData"] as? [String: Any] {
            let key = external ? "SystemPowerIn" : "BatteryPower"
            if let mw = telemetry[key] as? Int, mw > 0 {
                systemWatts = Double(mw) / 1000.0
            }
        }
        if systemWatts == nil, !external, batteryWatts < 0 {
            systemWatts = -batteryWatts
        }

        var adapterWatts: Int?
        var adapterName: String?
        var adapterVolts: Double?
        var adapterAmps: Double?
        if external, let adapter = dict["AdapterDetails"] as? [String: Any] {
            adapterWatts = adapter["Watts"] as? Int
            if let desc = adapter["Description"] as? String, !desc.isEmpty {
                adapterName = desc
            } else if let name = adapter["Name"] as? String, !name.isEmpty {
                adapterName = name
            }
            if let mv = adapter["AdapterVoltage"] as? Int { adapterVolts = Double(mv) / 1000.0 }
            if let ma = adapter["Current"] as? Int { adapterAmps = Double(ma) / 1000.0 }
        }

        return BatteryInfo(
            percent: percent,
            isCharging: isCharging,
            externalConnected: external,
            fullyCharged: fullyCharged,
            timeRemainingMinutes: timeRemaining,
            currentCapacitymAh: rawCurrent,
            fullChargeCapacitymAh: nominal,
            designCapacitymAh: design,
            cycleCount: cycles,
            temperature: (temperature * 10).rounded() / 10,
            voltage: (voltage * 100).rounded() / 100,
            amperage: (amperage * 100).rounded() / 100,
            batteryWatts: (batteryWatts * 10).rounded() / 10,
            systemWatts: systemWatts.map { ($0 * 10).rounded() / 10 },
            adapterWatts: adapterWatts,
            adapterName: adapterName,
            adapterVolts: adapterVolts,
            adapterAmps: adapterAmps,
            serial: dict["Serial"] as? String ?? "—",
            deviceName: dict["DeviceName"] as? String ?? "—"
        )
    }
}
