import Foundation

enum MigrationImportError: LocalizedError {
    case emptyInput
    case invalidBase64
    case invalidUTF8
    case invalidJSON
    case unsupportedVersion(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "インポート文字列が空です。"
        case .invalidBase64:
            return "Base64文字列の形式が不正です。"
        case .invalidUTF8:
            return "データの文字コードが不正です。"
        case .invalidJSON:
            return "JSON形式が不正です。"
        case .unsupportedVersion(let version):
            return "未対応のバージョンです: \(version)"
        }
    }
}

struct ImportedPayload: Decodable {
    let version: String
    let subscriptions: [ImportedSubscription]
}

struct ImportedSubscription: Decodable {
    let name: String?
    let amount: Double?
    let note: String?
    let billing_cycle: String?
    let date: String?

    enum CodingKeys: String, CodingKey {
        case name
        case amount
        case note
        case billing_cycle
        case date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = container.decodeLossyString(forKey: .name)
        note = container.decodeLossyString(forKey: .note)
        billing_cycle = container.decodeLossyString(forKey: .billing_cycle)
        date = container.decodeLossyString(forKey: .date)

        if let value = try? container.decode(Double.self, forKey: .amount) {
            amount = value
        } else if let intValue = try? container.decode(Int.self, forKey: .amount) {
            amount = Double(intValue)
        } else if let textValue = container.decodeLossyString(forKey: .amount), let parsed = Double(textValue) {
            amount = parsed
        } else {
            amount = nil
        }
    }
}

struct ImportResult {
    let validItems: [SubscriptionItem]
    let skippedCount: Int
    let errors: [String]
}

private extension KeyedDecodingContainer where K == ImportedSubscription.CodingKeys {
    func decodeLossyString(forKey key: K) -> String? {
        if let text = try? decode(String.self, forKey: key) {
            return text
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return String(doubleValue)
        }
        if let boolValue = try? decode(Bool.self, forKey: key) {
            return String(boolValue)
        }
        return nil
    }
}

struct MigrationImportService {
    func makeExportHandshakeKey(now: Date = .now) throws -> String {
        let unix = Int(now.timeIntervalSince1970)
        let payload = ExportHandshakePayload(version: "1.0.0", key: "\(unix)SL")
        let data = try JSONEncoder().encode(payload)
        return data.base64EncodedString().trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }

    func decodeImportPayload(from encoded: String) throws -> ImportedPayload {
        let normalized = normalizeBase64Input(encoded)
        guard !normalized.isEmpty else {
            throw MigrationImportError.emptyInput
        }

        let padded = padBase64(normalized)
        guard let data = Data(base64Encoded: padded) else {
            throw MigrationImportError.invalidBase64
        }

        guard let _ = String(data: data, encoding: .utf8) else {
            throw MigrationImportError.invalidUTF8
        }

        let payload: ImportedPayload
        do {
            payload = try JSONDecoder().decode(ImportedPayload.self, from: data)
        } catch {
            throw MigrationImportError.invalidJSON
        }

        guard payload.version == "1.0.0" else {
            throw MigrationImportError.unsupportedVersion(payload.version)
        }

        return payload
    }

    func mapToSubscriptionItems(_ payload: ImportedPayload) -> ImportResult {
        var validItems: [SubscriptionItem] = []
        var errors: [String] = []

        for (index, raw) in payload.subscriptions.enumerated() {
            do {
                let item = try mapRecord(raw)
                validItems.append(item)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                errors.append("行\(index + 1): \(message)")
            }
        }

        return ImportResult(
            validItems: validItems,
            skippedCount: payload.subscriptions.count - validItems.count,
            errors: errors
        )
    }

    private func mapRecord(_ record: ImportedSubscription) throws -> SubscriptionItem {
        let trimmedName = (record.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw RecordError.invalidName
        }

        guard let amount = record.amount, amount >= 0 else {
            throw RecordError.invalidAmount
        }

        let cycleRaw = (record.billing_cycle ?? "monthly").lowercased()
        let cycle: BillingCycle = cycleRaw == "yearly" ? .yearly : .monthly
        let dateRaw = (record.date ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let billingMonth: Int?
        let billingDay: Int

        switch cycle {
        case .monthly:
            guard let day = parseMonthlyDay(dateRaw) else {
                throw RecordError.invalidDate
            }
            billingMonth = nil
            billingDay = day
        case .yearly:
            guard let date = parseYearlyMonthDay(dateRaw) else {
                throw RecordError.invalidDate
            }
            billingMonth = date.month
            billingDay = date.day
        }

        var item = SubscriptionItem(
            id: UUID(),
            name: trimmedName,
            price: amount,
            currencyCode: "JPY",
            billingCycle: cycle,
            symbolName: "creditcard.fill",
            accentColorId: "blue",
            billingMonth: billingMonth,
            billingDayOfMonth: billingDay,
            nextBillingDate: .now,
            category: .other,
            status: .active,
            memo: record.note ?? ""
        )
        item.nextBillingDate = item.nextChargeDate()
        return item
    }

    private func normalizeBase64Input(_ input: String) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    }

    private func padBase64(_ base64: String) -> String {
        let remainder = base64.count % 4
        guard remainder != 0 else { return base64 }
        return base64 + String(repeating: "=", count: 4 - remainder)
    }

    private func parseMonthlyDay(_ text: String) -> Int? {
        guard let day = Int(text), (1...31).contains(day) else { return nil }
        return day
    }

    private func parseYearlyMonthDay(_ text: String) -> (month: Int, day: Int)? {
        let parts = text.split(separator: "/")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let day = Int(parts[1]),
              (1...12).contains(month),
              (1...31).contains(day) else {
            return nil
        }
        return (month, day)
    }

    private enum RecordError: LocalizedError {
        case invalidName
        case invalidAmount
        case invalidDate

        var errorDescription: String? {
            switch self {
            case .invalidName:
                return "name が空です。"
            case .invalidAmount:
                return "amount が不正です。"
            case .invalidDate:
                return "date が不正です。"
            }
        }
    }

    private struct ExportHandshakePayload: Encodable {
        let version: String
        let key: String
    }
}
