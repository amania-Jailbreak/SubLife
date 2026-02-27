import SwiftUI

struct SubscriptionColorOption: Identifiable {
    let id: String
    let name: String
    let color: Color
}

enum SubscriptionCurrency: String, Codable, CaseIterable, Identifiable {
    case jpy = "JPY"
    case usd = "USD"
    case eur = "EUR"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .jpy: return "日本円 (JPY)"
        case .usd: return "米ドル (USD)"
        case .eur: return "ユーロ (EUR)"
        }
    }
}

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monthly: return "月額"
        case .yearly: return "年額"
        }
    }
}

enum SubscriptionStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case cancelPlanned
    case canceled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .active: return "利用中"
        case .cancelPlanned: return "解約予定"
        case .canceled: return "解約済み"
        }
    }
}

enum SubscriptionCategory: String, Codable, CaseIterable, Identifiable {
    case video
    case music
    case productivity
    case ai
    case game
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .video: return "動画"
        case .music: return "音楽"
        case .productivity: return "仕事"
        case .ai: return "AI"
        case .game: return "ゲーム"
        case .other: return "その他"
        }
    }

    var chartColor: Color {
        switch self {
        case .video: return .red
        case .music: return .blue
        case .productivity: return .indigo
        case .ai: return .teal
        case .game: return .orange
        case .other: return .gray
        }
    }
}

struct SubscriptionItem: Identifiable, Codable, Equatable {
    static let availableSymbolNames: [String] = [
        "play.rectangle.fill",
        "music.note",
        "briefcase.fill",
        "sparkles",
        "gamecontroller.fill",
        "book.fill",
        "shippingbox.fill",
        "heart.fill",
        "cart.fill",
        "star.fill"
    ]

    static let colorOptions: [SubscriptionColorOption] = [
        .init(id: "blue", name: "ブルー", color: .blue),
        .init(id: "teal", name: "ティール", color: .teal),
        .init(id: "green", name: "グリーン", color: .green),
        .init(id: "orange", name: "オレンジ", color: .orange),
        .init(id: "red", name: "レッド", color: .red),
        .init(id: "pink", name: "ピンク", color: .pink),
        .init(id: "purple", name: "パープル", color: .purple),
        .init(id: "indigo", name: "インディゴ", color: .indigo),
        .init(id: "brown", name: "ブラウン", color: .brown),
        .init(id: "gray", name: "グレー", color: .gray)
    ]

    var id: UUID
    var name: String
    var price: Double
    var currencyCode: String?
    var billingCycle: BillingCycle
    var symbolName: String?
    var accentColorId: String?
    var billingMonth: Int?
    var billingDayOfMonth: Int?
    var nextBillingDate: Date
    var category: SubscriptionCategory
    var status: SubscriptionStatus
    var memo: String

    var monthlyEquivalent: Double {
        switch billingCycle {
        case .monthly: return price
        case .yearly: return price / 12.0
        }
    }

    var effectiveCurrency: SubscriptionCurrency {
        SubscriptionCurrency(rawValue: currencyCode ?? "") ?? .jpy
    }

    var effectiveCurrencyCode: String {
        effectiveCurrency.rawValue
    }

    var effectiveBillingDayOfMonth: Int {
        let sourceDay = billingDayOfMonth ?? Calendar.current.component(.day, from: nextBillingDate)
        return min(max(sourceDay, 1), 31)
    }

    var effectiveBillingMonth: Int {
        let sourceMonth = billingMonth ?? Calendar.current.component(.month, from: nextBillingDate)
        return min(max(sourceMonth, 1), 12)
    }

    var effectiveSymbolName: String {
        symbolName ?? "creditcard.fill"
    }

    var effectiveAccentColorId: String {
        accentColorId ?? "blue"
    }

    var effectiveAccentColor: Color {
        Self.colorOptions.first(where: { $0.id == effectiveAccentColorId })?.color ?? .blue
    }

    static func color(for colorId: String) -> Color {
        colorOptions.first(where: { $0.id == colorId })?.color ?? .blue
    }

    var billingDescription: String {
        switch billingCycle {
        case .monthly:
            return "毎月\(effectiveBillingDayOfMonth)日"
        case .yearly:
            return "毎年\(effectiveBillingMonth)月\(effectiveBillingDayOfMonth)日"
        }
    }

    func amountInJPY(_ amount: Double, usdToJpy: Double, eurToJpy: Double) -> Double {
        switch effectiveCurrency {
        case .jpy:
            return amount
        case .usd:
            return amount * max(0, usdToJpy)
        case .eur:
            return amount * max(0, eurToJpy)
        }
    }

    func monthlyEquivalentInJPY(usdToJpy: Double, eurToJpy: Double) -> Double {
        amountInJPY(monthlyEquivalent, usdToJpy: usdToJpy, eurToJpy: eurToJpy)
    }

    func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        let target = calendar.startOfDay(for: date)
        let occurrence: Date

        switch billingCycle {
        case .monthly:
            occurrence = monthlyOccurrence(inMonthContaining: target, calendar: calendar)
        case .yearly:
            occurrence = yearlyOccurrence(inYearContaining: target, calendar: calendar)
        }

        return calendar.isDate(occurrence, inSameDayAs: target)
    }

    func nextChargeDate(from referenceDate: Date = .now, calendar: Calendar = .current) -> Date {
        let base = calendar.startOfDay(for: referenceDate)

        switch billingCycle {
        case .monthly:
            var candidate = monthlyOccurrence(inMonthContaining: base, calendar: calendar)
            if candidate < base, let nextMonth = calendar.date(byAdding: .month, value: 1, to: base) {
                candidate = monthlyOccurrence(inMonthContaining: nextMonth, calendar: calendar)
            }
            return candidate
        case .yearly:
            var candidate = yearlyOccurrence(inYearContaining: base, calendar: calendar)
            if candidate < base, let nextYear = calendar.date(byAdding: .year, value: 1, to: base) {
                candidate = yearlyOccurrence(inYearContaining: nextYear, calendar: calendar)
            }
            return candidate
        }
    }

    func chargeAmount(inMonthContaining date: Date, calendar: Calendar = .current) -> Double {
        let monthStartComponents = calendar.dateComponents([.year, .month], from: date)
        guard let monthStart = calendar.date(from: monthStartComponents) else { return 0 }
        let monthKey = calendar.dateComponents([.year, .month], from: monthStart)

        switch billingCycle {
        case .monthly:
            return price
        case .yearly:
            let chargeDate = yearlyOccurrence(inYearContaining: monthStart, calendar: calendar)
            let chargeKey = calendar.dateComponents([.year, .month], from: chargeDate)
            return chargeKey == monthKey ? price : 0
        }
    }

    func chargeAmountInJPY(
        inMonthContaining date: Date,
        calendar: Calendar = .current,
        usdToJpy: Double,
        eurToJpy: Double
    ) -> Double {
        let originalAmount = chargeAmount(inMonthContaining: date, calendar: calendar)
        return amountInJPY(originalAmount, usdToJpy: usdToJpy, eurToJpy: eurToJpy)
    }

    private func monthlyOccurrence(inMonthContaining date: Date, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month], from: date)
        let daysInMonth = daysInMonth(of: date, calendar: calendar)
        comps.day = min(effectiveBillingDayOfMonth, daysInMonth)
        return calendar.date(from: comps) ?? date
    }

    private func yearlyOccurrence(inYearContaining date: Date, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year], from: date)
        comps.month = effectiveBillingMonth
        comps.day = min(
            effectiveBillingDayOfMonth,
            daysInMonth(
                year: comps.year ?? calendar.component(.year, from: date),
                month: effectiveBillingMonth,
                calendar: calendar
            )
        )
        return calendar.date(from: comps) ?? date
    }

    private func daysInMonth(of date: Date, calendar: Calendar) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 31
    }

    private func daysInMonth(year: Int, month: Int, calendar: Calendar) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let date = calendar.date(from: comps) ?? .now
        return daysInMonth(of: date, calendar: calendar)
    }

    static let sample = SubscriptionItem(
        id: UUID(),
        name: "Netflix",
        price: 1490,
        currencyCode: "JPY",
        billingCycle: .monthly,
        symbolName: "play.rectangle.fill",
        accentColorId: "red",
        billingMonth: nil,
        billingDayOfMonth: 26,
        nextBillingDate: .now,
        category: .video,
        status: .active,
        memo: ""
    )
}

struct CategorySpendEntry: Identifiable {
    let category: SubscriptionCategory
    let amount: Double

    var id: String { category.rawValue }
}

struct MonthlySpendEntry: Identifiable {
    let monthStart: Date
    let amount: Double

    var id: Date { monthStart }
}
