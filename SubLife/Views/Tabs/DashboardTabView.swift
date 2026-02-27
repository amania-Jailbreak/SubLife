import SwiftUI
import Charts

struct DashboardTabView: View {
    @ObservedObject var store: SubscriptionStore
    let upcomingWindowDays: Int
    let usdToJpy: Double
    let eurToJpy: Double
    let backgroundThemeId: String
    let onAddTapped: () -> Void
    let onEditTapped: (SubscriptionItem) -> Void

    private var activeItems: [SubscriptionItem] {
        store.items.filter { $0.status != .canceled }
    }

    private var monthlyTotal: Double {
        activeItems.reduce(0) { $0 + $1.monthlyEquivalentInJPY(usdToJpy: usdToJpy, eurToJpy: eurToJpy) }
    }

    private var upcomingCount: Int {
        let limit = Calendar.current.date(byAdding: .day, value: upcomingWindowDays, to: .now) ?? .now
        return activeItems.filter { $0.nextChargeDate() <= limit }.count
    }

    private var monthlySpendEntries: [MonthlySpendEntry] {
        let calendar = Calendar.current
        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now

        return (0..<6).compactMap { offset in
            guard let targetMonth = calendar.date(byAdding: .month, value: offset, to: startOfCurrentMonth) else {
                return nil
            }
            let amount = activeItems.reduce(0) { partial, item in
                partial + item.chargeAmountInJPY(
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
                Label("利用中（解約予定含む）: \(activeItems.count)件", systemImage: "checkmark.circle")
                Label("\(upcomingWindowDays)日以内の請求予定: \(upcomingCount)件", systemImage: "calendar.badge.clock")

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("月額換算合計")
                    Spacer()
                    Text(monthlyTotal, format: .currency(code: "JPY"))
                        .font(.title3.bold())
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
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
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
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
