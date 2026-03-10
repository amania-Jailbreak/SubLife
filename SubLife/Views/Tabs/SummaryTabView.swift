import SwiftUI
import Charts

struct SummaryTabView: View {
    private enum AmountMode: String, CaseIterable, Identifiable {
        case monthly
        case yearly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .monthly: return "月額"
            case .yearly: return "年額"
            }
        }
    }

    @ObservedObject var store: SubscriptionStore
    let usdToJpy: Double
    let eurToJpy: Double
    let backgroundThemeId: String
    let onEditTapped: (SubscriptionItem) -> Void

    @State private var amountMode: AmountMode = .monthly
    @State private var selectedCategory: SubscriptionCategory?

    private var activeItems: [SubscriptionItem] {
        store.items.filter { $0.status != .canceled }
    }

    private var itemsForSelectedMode: [SubscriptionItem] {
        switch amountMode {
        case .monthly:
            return activeItems.filter { $0.billingCycle != .yearly }
        case .yearly:
            return activeItems
        }
    }

    private var totalAmount: Double {
        itemsForSelectedMode.reduce(0) { partial, item in
            partial + amountForSelectedMode(item)
        }
    }

    private var categorySpendEntries: [SummaryCategorySpendEntry] {
        let grouped = Dictionary(grouping: itemsForSelectedMode, by: \.category)
        return grouped.compactMap { category, items in
            let amount = items.reduce(0) { partial, item in
                partial + amountForSelectedMode(item)
            }
            guard amount > 0 else { return nil }
            return SummaryCategorySpendEntry(category: category, amount: amount)
        }
        .sorted { $0.amount > $1.amount }
    }

    private var filteredItems: [SubscriptionItem] {
        if let selectedCategory {
            return itemsForSelectedMode.filter { $0.category == selectedCategory }
        }
        return itemsForSelectedMode
    }

    private var selectedChartEntry: SummaryCategorySpendEntry? {
        guard let selectedCategory else { return nil }
        return categorySpendEntries.first(where: { $0.category == selectedCategory })
    }

    private func category(for angleValue: Double) -> SubscriptionCategory? {
        var runningTotal = 0.0
        for entry in categorySpendEntries {
            let nextTotal = runningTotal + entry.amount
            if angleValue >= runningTotal && angleValue < nextTotal {
                return entry.category
            }
            runningTotal = nextTotal
        }
        return nil
    }

    private func amountForSelectedMode(_ item: SubscriptionItem) -> Double {
        switch amountMode {
        case .monthly:
            return item.amountInJPY(item.price, usdToJpy: usdToJpy, eurToJpy: eurToJpy)
        case .yearly:
            if item.billingCycle != .yearly {
                return item.amountInJPY(item.price * 12, usdToJpy: usdToJpy, eurToJpy: eurToJpy)
            }
            return item.amountInJPY(item.price, usdToJpy: usdToJpy, eurToJpy: eurToJpy)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(option: AppBackgroundOption.option(for: backgroundThemeId))

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        chartSection
                        categoryFilterSection
                        subscriptionListSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("サマリー")
        }
        .background(Color.clear)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カテゴリ別の支払い")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))

            Picker("集計単位", selection: $amountMode) {
                ForEach(AmountMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: amountMode) { _, _ in
                selectedCategory = nil
            }

            if categorySpendEntries.isEmpty {
                Text("表示できるデータがありません")
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            } else {
                ZStack {
                    Chart(categorySpendEntries) { entry in
                        SectorMark(
                            angle: .value("金額", entry.amount),
                            innerRadius: .ratio(0.81),
                            outerRadius: .ratio(selectedChartEntry?.id == entry.id ? 1.0 : 0.96),
                            angularInset: 2
                        )
                        .foregroundStyle(entry.category.chartColor.gradient)
                        .opacity(selectedChartEntry == nil || selectedChartEntry?.id == entry.id ? 1 : 0.45)
                    }
                    .frame(height: 236)
                    .chartLegend(.hidden)
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    SpatialTapGesture().onEnded { tap in
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let frame = geometry[plotFrame]
                                        let center = CGPoint(x: frame.midX, y: frame.midY)
                                        let dx = tap.location.x - center.x
                                        let dy = tap.location.y - center.y
                                        let distance = hypot(dx, dy)
                                        let outerRadius = min(frame.width, frame.height) * 0.5
                                        let innerRadius = outerRadius * 0.81

                                        guard distance <= outerRadius + 6 else { return }
                                        guard distance >= innerRadius - 8 else { return }

                                        var angle = atan2(dx, -dy)
                                        if angle < 0 { angle += (.pi * 2) }
                                        let valueOnCircle = (angle / (.pi * 2)) * totalAmount
                                        guard let tappedCategory = category(for: valueOnCircle) else { return }

                                        selectedCategory = (selectedCategory == tappedCategory) ? nil : tappedCategory
                                    }
                                )
                        }
                    }

                    VStack(spacing: 4) {
                        if let selectedChartEntry {
                            Text(selectedChartEntry.category.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedChartEntry.category.chartColor)
                            Text(selectedChartEntry.amount, format: .currency(code: "JPY"))
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("合計支払い金額")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(totalAmount, format: .currency(code: "JPY"))
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture {
                        selectedCategory = nil
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "すべて", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(SubscriptionCategory.allCases) { category in
                    categoryChip(title: category.label, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : .secondary)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.35) : .white.opacity(0.1))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? Color.accentColor.opacity(0.9) : .white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var subscriptionListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedCategory?.label ?? "すべてのサブスク")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))

            if filteredItems.isEmpty {
                Text("該当するサブスクはありません")
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredItems) { item in
                        SubscriptionRow(item: item, usdToJpy: usdToJpy, eurToJpy: eurToJpy)
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(.white.opacity(0.1), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { onEditTapped(item) }
                    }
                }
            }
        }
    }
}

private struct SummaryCategorySpendEntry: Identifiable {
    let category: SubscriptionCategory
    let amount: Double

    var id: String { category.rawValue }
}
