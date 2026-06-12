import Foundation
import CoreFoundation

// Температуры из двух источников:
//  1) HID-сенсоры SoC (usage page 0xff00 / usage 5) — CPU die и др.
//  2) SMC-ключи "T*" — на Apple Silicon дают GPU ("Tg*"), которого нет в HID.
// Имена различаются между поколениями чипов, поэтому CPU/GPU определяются
// по паттернам, а полный список виден в настройках.

struct ThermalSensor: Identifiable, Equatable {
    let id: String
    let name: String
    let value: Double
}

// Доступ только с очереди сэмплера; клиенты неизменяемы после init
final class ThermalReader: @unchecked Sendable {

    private var client: UnsafeMutableRawPointer?
    private let smc = SMCReader()

    init() {
        guard let create = PrivateAPI.hidClientCreate,
              let setMatching = PrivateAPI.hidSetMatching,
              let client = create(kCFAllocatorDefault) else { return }
        // AppleARMIODevice temperature sensors
        let matching: [String: Int] = [
            "PrimaryUsagePage": 0xff00,
            "PrimaryUsage": 5,
        ]
        _ = setMatching(client, matching as CFDictionary)
        self.client = client
    }

    var isAvailable: Bool { client != nil || smc != nil }

    func readAll() -> [ThermalSensor] {
        var raw: [(name: String, value: Double)] = readHID()
        if let smc {
            raw += smc.readAll().map { ("SMC \($0.name)", $0.value) }
        }
        raw.sort { $0.name < $1.name }

        // Уникальные id для дубликатов имён (у HID бывает по два клиента на сенсор)
        var seen: [String: Int] = [:]
        return raw.map { item in
            let n = (seen[item.name] ?? 0) + 1
            seen[item.name] = n
            return ThermalSensor(
                id: n == 1 ? item.name : "\(item.name)#\(n)",
                name: item.name,
                value: item.value
            )
        }
    }

    private func readHID() -> [(name: String, value: Double)] {
        guard let client,
              let copyServices = PrivateAPI.hidCopyServices,
              let copyProperty = PrivateAPI.hidCopyProperty,
              let copyEvent = PrivateAPI.hidCopyEvent,
              let getFloat = PrivateAPI.hidGetFloatValue,
              let services = copyServices(client)?.takeRetainedValue() else { return [] }

        var result: [(String, Double)] = []
        let count = CFArrayGetCount(services)
        for i in 0..<count {
            guard let rawPtr = CFArrayGetValueAtIndex(services, i) else { continue }
            let service = UnsafeMutableRawPointer(mutating: rawPtr)

            guard let nameRef = copyProperty(service, "Product" as CFString)?.takeRetainedValue(),
                  let name = nameRef as? String else { continue }

            guard let event = copyEvent(service, PrivateAPI.kIOHIDEventTypeTemperature, 0, 0) else { continue }
            let value = getFloat(event, PrivateAPI.temperatureField)
            // Балансируем +1 retain от Copy-функции
            Unmanaged<AnyObject>.fromOpaque(event).release()

            // Отсекаем мусорные показания
            guard value > 0, value < 130 else { continue }
            result.append((name, value))
        }
        return result
    }

    /// Сводка: горячая точка CPU и GPU по паттернам имён сенсоров.
    func summary(from sensors: [ThermalSensor]) -> (cpu: Double?, gpu: Double?) {
        var cpuValues: [Double] = []
        var gpuValues: [Double] = []

        for s in sensors {
            let n = s.name.lowercased()
            if n.contains("gpu") || n.hasPrefix("smc tg") {
                gpuValues.append(s.value)
            } else if n.contains("tdie") || n.contains("cpu")
                        || n.hasPrefix("pacc") || n.hasPrefix("eacc")
                        || n.contains("soc mtr temp") {
                cpuValues.append(s.value)
            }
        }

        // Fallback'и, если основные паттерны не нашлись на этом чипе
        if cpuValues.isEmpty {
            cpuValues = sensors
                .filter { $0.name.lowercased().hasPrefix("smc tp") || $0.name.lowercased().hasPrefix("smc tc") }
                .map(\.value)
        }
        if cpuValues.isEmpty {
            cpuValues = sensors
                .filter {
                    let n = $0.name.lowercased()
                    return !n.contains("battery") && !n.contains("nand") && !n.contains("gas gauge")
                }
                .map(\.value)
        }
        return (cpuValues.max(), gpuValues.max())
    }
}
