import Charts
import SwiftUI

struct DashboardTabView: View {
    @ObservedObject var store: SubscriptionStore
    let upcomingWindowDays: Int
    let usdToJpy: Double
    let eurToJpy: Double
    let backgroundThemeId: String
    let onAddTapped: () -> Void
    let onShareTapped: () -> Void
    let onEditTapped: (SubscriptionItem) -> Void
  private let japaneseLocale = Locale(identifier: "ja_JP")

  private var activeItems: [SubscriptionItem] {
    store.items.filter { $0.status != .canceled }
  }

    private var monthlyTotal: Double {
        activeItems.reduce(0) { $0 + $1.monthlyEquivalentInJPY(usdToJpy: usdToJpy, eurToJpy: eurToJpy) }
    }

    private var estimatedYearlyTotal: Double {
        monthlyTotal * 12
    }

  private var thisMonthEstimatedTotal: Double {
    let calendar = Calendar.current
    return activeItems.reduce(0) { partial, item in
      partial
        + item.chargeAmountInJPY(
          inMonthContaining: .now,
          calendar: calendar,
          usdToJpy: usdToJpy,
          eurToJpy: eurToJpy
        )
    }
  }

  private var thisMonthRemainingTotal: Double {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let currentMonth = calendar.dateComponents([.year, .month], from: today)

    return activeItems.reduce(0) { partial, item in
      let nextDate = item.nextChargeDate(from: today, calendar: calendar)
      let nextMonth = calendar.dateComponents([.year, .month], from: nextDate)
      guard nextMonth == currentMonth else { return partial }
      return partial + item.amountInJPY(item.price, usdToJpy: usdToJpy, eurToJpy: eurToJpy)
    }
  }

  private var thisMonthPaidTotal: Double {
    max(0, thisMonthEstimatedTotal - thisMonthRemainingTotal)
  }

  private var upcomingCount: Int {
    let limit = Calendar.current.date(byAdding: .day, value: upcomingWindowDays, to: .now) ?? .now
    return activeItems.filter { $0.nextChargeDate() <= limit }.count
  }

  private var monthlySpendEntries: [MonthlySpendEntry] {
    let calendar = Calendar.current
    let startOfCurrentMonth =
      calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now

    return (0..<6).compactMap { offset in
      guard
        let targetMonth = calendar.date(byAdding: .month, value: offset, to: startOfCurrentMonth)
      else {
        return nil
      }
      let amount = activeItems.reduce(0) { partial, item in
        partial
          + item.chargeAmountInJPY(
            inMonthContaining: targetMonth,
            calendar: calendar,
            usdToJpy: usdToJpy,
            eurToJpy: eurToJpy
          )
      }
      return MonthlySpendEntry(monthStart: targetMonth, amount: amount)
    }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AppBackgroundView(option: AppBackgroundOption.option(for: backgroundThemeId))

        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            summarySection
            chartSection
            subscriptionListSection
          }
          .padding(.horizontal, 16)
          .padding(.top, 8)
          .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
      }
            .navigationTitle("サブスクぐらし!!")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onShareTapped) {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAddTapped) {
                        Label("追加", systemImage: "plus")
                    }
                }
      }
    }
    .background(Color.clear)
    .toolbarBackground(.clear, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
  }

  private var summarySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("サマリー")
        .font(.headline)
        .foregroundStyle(.white.opacity(0.9))

      VStack(alignment: .leading, spacing: 10) {
        metricRow(
          title: "今月の支払推定額",
          value: thisMonthEstimatedTotal,
          icon: "calendar"
        )

        metricRow(
          title: "今月の推定支払残額",
          value: thisMonthRemainingTotal,
          icon: "checkmark.seal"
        )

        Divider()
          .overlay(.white.opacity(0.2))
          .padding(.vertical, 2)

        HStack(spacing: 12) {
          Label("利用中: \(activeItems.count)件", systemImage: "checkmark.circle")
          Spacer()
          Label("\(upcomingWindowDays)日以内: \(upcomingCount)件", systemImage: "calendar.badge.clock")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("推定年間合計")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(estimatedYearlyTotal, format: .currency(code: "JPY"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
      }
      .padding(14)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(.white.opacity(0.1), lineWidth: 1)
      )
    }
  }

  private func metricRow(title: String, value: Double, icon: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.body.weight(.semibold))
        .foregroundStyle(.white.opacity(0.85))
        .frame(width: 24)

      Text(title)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.82)

      Spacer()

      if value <= 0 {
        Text("支払い済")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.green.opacity(0.95))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      } else {
        Text(value, format: .currency(code: "JPY"))
          .font(.title3.weight(.bold))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
    }
  }

  private var chartSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("月別の支払い見込み")
        .font(.headline)
        .foregroundStyle(.white.opacity(0.9))

      if monthlySpendEntries.isEmpty {
        Text("データがありません")
          .foregroundStyle(.secondary)
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(.white.opacity(0.1), lineWidth: 1)
          )
      } else {
        VStack {
          Chart(monthlySpendEntries) { entry in
            BarMark(
              x: .value("月", entry.monthStart, unit: .month),
              y: .value("金額", entry.amount)
            )
            .foregroundStyle(Color.accentColor.gradient)
            .annotation(position: .top) {
              Text(entry.amount, format: .currency(code: "JPY"))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
          .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
              AxisGridLine()
              AxisValueLabel(format: .dateTime.locale(japaneseLocale).month(.abbreviated))
            }
          }
          .chartYAxis {
            AxisMarks(position: .leading)
          }
          .frame(height: 220)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(.white.opacity(0.1), lineWidth: 1)
        )
      }
    }
  }

  private var subscriptionListSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("サブスク一覧")
        .font(.headline)
        .foregroundStyle(.white.opacity(0.9))

      if store.items.isEmpty {
        ContentUnavailableView(
          "まだ登録がありません",
          systemImage: "tray",
          description: Text("右上の追加ボタンから登録してください")
        )
      } else {
        LazyVStack(spacing: 10) {
          ForEach(store.items) { item in
            SubscriptionRow(item: item, usdToJpy: usdToJpy, eurToJpy: eurToJpy)
              .padding(12)
              .background(
                .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .stroke(.white.opacity(0.1), lineWidth: 1)
              )
              .contentShape(Rectangle())
              .onTapGesture { onEditTapped(item) }
              .contextMenu {
                Button(role: .destructive) {
                  delete(item)
                } label: {
                  Label("削除", systemImage: "trash")
                }
              }
          }
        }
      }
    }
  }

  private func delete(_ item: SubscriptionItem) {
    guard let index = store.items.firstIndex(where: { $0.id == item.id }) else { return }
    store.delete(at: IndexSet(integer: index))
  }
}
