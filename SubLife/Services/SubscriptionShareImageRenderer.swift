import SwiftUI
import UIKit

@MainActor
struct SubscriptionShareImageRenderer {
  func renderImage(
    items: [SubscriptionItem],
    usdToJpy: Double,
    eurToJpy: Double,
    themeColorId: String,
    backgroundThemeId: String
  ) -> UIImage? {
    let view = SubscriptionShareCardView(
      items: items,
      usdToJpy: usdToJpy,
      eurToJpy: eurToJpy,
      themeColorId: themeColorId,
      backgroundThemeId: backgroundThemeId
    )
    .frame(width: 1080)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    return renderer.uiImage
  }
}

private struct SubscriptionShareCardView: View {
  let items: [SubscriptionItem]
  let usdToJpy: Double
  let eurToJpy: Double
  let themeColorId: String
  let backgroundThemeId: String

  private let japaneseLocale = Locale(identifier: "ja_JP")

  private var activeItems: [SubscriptionItem] {
    items.filter { $0.status != .canceled }
  }

  private var monthlyTotal: Double {
    activeItems.reduce(0) { partial, item in
      partial
        + item.chargeAmountInJPY(
          inMonthContaining: .now,
          usdToJpy: usdToJpy,
          eurToJpy: eurToJpy
        )
    }
  }

  private var generatedAtText: String {
    Date().formatted(
      .dateTime
        .locale(japaneseLocale)
        .year()
        .month()
        .day()
        .hour()
        .minute()
    )
  }

  var body: some View {
    ZStack {
      AppBackgroundView(option: AppBackgroundOption.option(for: backgroundThemeId))

      VStack(alignment: .leading, spacing: 28) {
        VStack(alignment: .leading, spacing: 10) {
          Text("サブスクぐらし!!")
            .font(.system(size: 62, weight: .black))
            .foregroundStyle(.white)

          Text("当月の支払額 \(monthlyTotal, format: .currency(code: "JPY"))")
            .font(.system(size: 42, weight: .bold))
            .foregroundStyle(AppThemeOption.color(for: themeColorId))

          Text("利用中 \(activeItems.count)件")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
        }

        VStack(spacing: 14) {
          ForEach(activeItems.prefix(12)) { item in
            HStack(spacing: 16) {
              ZStack {
                Circle()
                  .fill(item.effectiveAccentColor.opacity(0.22))
                  .frame(width: 52, height: 52)
                Image(systemName: item.effectiveSymbolName)
                  .font(.system(size: 25, weight: .bold))
                  .foregroundStyle(item.effectiveAccentColor)
              }

              VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                  .font(.system(size: 31, weight: .bold))
                  .foregroundStyle(.white)
                  .lineLimit(1)
                Text("\(item.category.label) • \(item.billingDescription)")
                  .font(.system(size: 24, weight: .medium))
                  .foregroundStyle(.white.opacity(0.72))
              }

              Spacer()

              Text(item.price, format: .currency(code: item.effectiveCurrencyCode))
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
              RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.33))
            )
            .overlay(
              RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
            )
          }
        }

        Text("作成日時: \(generatedAtText)")
          .font(.system(size: 22, weight: .medium))
          .foregroundStyle(.white.opacity(0.64))

        HStack(alignment: .bottom) {
          Text("Generated with サブスクぐらし!!. Download on the App Store.")
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(.white.opacity(0.58))
        }
      }
      .padding(48)
    }
  }
}
