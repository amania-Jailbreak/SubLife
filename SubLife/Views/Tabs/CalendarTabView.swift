import SwiftUI

struct CalendarTabView: View {
    let items: [SubscriptionItem]
    let usdToJpy: Double
    let eurToJpy: Double
    let backgroundThemeId: String

    @State private var displayedMonth = Date()
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current
    private let japaneseLocale = Locale(identifier: "ja_JP")
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
    private let gridSpacing: CGFloat = 6
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.locale(japaneseLocale).year().month(.wide))
    }

    private var monthDays: [Date] {
        calendar.monthGridDates(for: displayedMonth)
    }

    private var selectedItems: [SubscriptionItem] {
        let target = calendar.startOfDay(for: selectedDate)
        return items
            .filter { $0.status != .canceled && $0.occurs(on: target, calendar: calendar) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(option: AppBackgroundOption.option(for: backgroundThemeId))

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        monthHeader
                        weekdayHeader
                        monthGrid
                        selectedDaySection
                    }
                    .padding()
                }
            }
            .scrollIndicators(.hidden)
            .navigationTitle("カレンダー")
        }
        .background(Color.clear)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
            }

            Spacer()

            Text(monthTitle)
                .font(.headline)

            Spacer()

            Button {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.09), lineWidth: 1)
        )
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(monthDays, id: \.self) { date in
                CalendarDayCell(
                    date: date,
                    isCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                    isToday: calendar.isDateInToday(date),
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    itemCount: countForDay(date),
                    paymentColorIds: paymentColorIdsForDay(date)
                )
                .aspectRatio(1, contentMode: .fit)
                .onTapGesture {
                    selectedDate = calendar.startOfDay(for: date)
                }
            }
        }
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("選択日: \(selectedDate.formatted(.dateTime.locale(japaneseLocale).year().month().day()))")
                .font(.headline)

            if selectedItems.isEmpty {
                Text("この日の請求予定はありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(selectedItems) { item in
                    SubscriptionRow(item: item, usdToJpy: usdToJpy, eurToJpy: eurToJpy)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.09), lineWidth: 1)
        )
    }

    private func countForDay(_ date: Date) -> Int {
        items.filter { $0.status != .canceled && $0.occurs(on: date, calendar: calendar) }.count
    }

    private func paymentColorIdsForDay(_ date: Date) -> [String] {
        var unique: [String] = []
        for item in items where item.status != .canceled && item.occurs(on: date, calendar: calendar) {
            let colorId = item.effectiveAccentColorId
            if !unique.contains(colorId) {
                unique.append(colorId)
            }
        }
        return unique
    }
}

struct CalendarDayCell: View {
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let itemCount: Int
    let paymentColorIds: [String]

    private var hasPayment: Bool { itemCount > 0 }
    private var paymentColors: [Color] { paymentColorIds.map(colorForPaymentId) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(date.formatted(.dateTime.day()))
                    .font(.headline.weight(isSelected ? .semibold : .regular))
                Spacer()
            }

            Spacer(minLength: 0)

        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundStyle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderStyle, lineWidth: isSelected || hasPayment || isToday ? 1.5 : 1)
        )
        .opacity(isCurrentMonth ? 1 : 0.35)
    }

    private var backgroundStyle: some ShapeStyle {
        if isSelected {
            if paymentColors.count >= 2 {
                return AnyShapeStyle(
                    LinearGradient(
                        colors: paymentColors.map { $0.opacity(0.28) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            if let first = paymentColors.first {
                return AnyShapeStyle(first.opacity(0.28))
            }
            return AnyShapeStyle(Color.accentColor.opacity(0.14))
        }
        if hasPayment {
            if paymentColors.count >= 2 {
                return AnyShapeStyle(
                    LinearGradient(
                        colors: paymentColors.map { $0.opacity(0.16) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            if let first = paymentColors.first {
                return AnyShapeStyle(first.opacity(0.16))
            }
        }
        if isToday {
            return AnyShapeStyle(Color.accentColor.opacity(0.07))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    private var borderStyle: AnyShapeStyle {
        if paymentColors.count >= 2 {
            return AnyShapeStyle(
                LinearGradient(
                    colors: paymentColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        if isSelected {
            return AnyShapeStyle(Color.accentColor)
        }
        if hasPayment, let first = paymentColors.first {
            return AnyShapeStyle(first.opacity(0.95))
        }
        if isToday {
            return AnyShapeStyle(Color.accentColor.opacity(0.5))
        }
        return AnyShapeStyle(Color.secondary.opacity(0.15))
    }

    private func colorForPaymentId(_ id: String) -> Color {
        SubscriptionItem.color(for: id)
    }
}
