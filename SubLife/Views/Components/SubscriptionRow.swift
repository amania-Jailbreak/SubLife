import SwiftUI

struct SubscriptionRow: View {
    let item: SubscriptionItem
    let usdToJpy: Double
    let eurToJpy: Double
    private let japaneseLocale = Locale(identifier: "ja_JP")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ZStack {
                    Circle()
                        .fill(item.effectiveAccentColor.opacity(0.2))
                        .frame(width: 30, height: 30)
                    Image(systemName: item.effectiveSymbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.effectiveAccentColor)
                }

                Text(item.name)
                    .font(.headline)
                Spacer()
                Text(item.status.label)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }

            HStack {
                Text(item.category.label)
                Text("•")
                Text(item.billingDescription)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.price, format: .currency(code: item.effectiveCurrencyCode))
                    if item.effectiveCurrency != .jpy {
                        Text(item.amountInJPY(item.price, usdToJpy: usdToJpy, eurToJpy: eurToJpy), format: .currency(code: "JPY"))
                            .font(.caption2)
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if item.billingCycle == .installment {
                let remainingMonths = item.remainingInstallmentMonths()
                if remainingMonths > 0 {
                    Text(
                        "残り\(remainingMonths)ヶ月・残高 \(item.remainingInstallmentBalance(usdToJpy: usdToJpy, eurToJpy: eurToJpy), format: .currency(code: "JPY"))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text("完済")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            if item.nextChargeDate() != .distantFuture {
                Text("次回請求: \(item.nextChargeDate().formatted(.dateTime.locale(japaneseLocale).year().month().day()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("次回請求: なし")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch item.status {
        case .active: return .green
        case .cancelPlanned: return .orange
        case .canceled: return .gray
        }
    }
}
