import Foundation

extension Calendar {
    func monthGridDates(for referenceDate: Date) -> [Date] {
        guard let monthInterval = dateInterval(of: .month, for: referenceDate) else { return [] }
        let monthStart = startOfDay(for: monthInterval.start)
        let daysInMonth = range(of: .day, in: .month, for: monthStart)?.count ?? 0
        let firstWeekdayOfMonth = component(.weekday, from: monthStart)
        let leadingDays = (firstWeekdayOfMonth - firstWeekday + 7) % 7
        let totalVisibleDays = ((leadingDays + daysInMonth + 6) / 7) * 7

        let gridStart = date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart
        return (0..<totalVisibleDays).compactMap { offset in
            date(byAdding: .day, value: offset, to: gridStart)
        }
    }
}
