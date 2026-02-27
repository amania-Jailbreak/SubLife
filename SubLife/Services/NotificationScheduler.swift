import Foundation
import UserNotifications

actor NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let prefix = "sublife.billing."

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func reschedule(items: [SubscriptionItem], leadDays: Int) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let pending = await center.pendingNotificationRequests()
        let managedIds = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: managedIds)

        for item in items where item.status != .canceled {
            guard let reminderDate = reminderDate(for: item, leadDays: leadDays) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "サブスクの請求日"
            content.body = "\(item.name) の請求予定日です（\(formattedAmount(for: item))）"
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: prefix + item.id.uuidString,
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }
    }

    private func formattedAmount(for item: SubscriptionItem) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = item.effectiveCurrencyCode
        return formatter.string(from: NSNumber(value: item.price)) ?? "\(item.price)"
    }

    private func reminderDate(for item: SubscriptionItem, leadDays: Int) -> Date? {
        let clampedLead = max(0, leadDays)
        let calendar = Calendar.current
        let now = Date()

        var nextCharge = item.nextChargeDate(from: now, calendar: calendar)
        var reminder = calendar.date(byAdding: .day, value: -clampedLead, to: nextCharge) ?? nextCharge

        if reminder <= now {
            guard let nextCycleReference = calendar.date(byAdding: .day, value: 1, to: nextCharge) else {
                return nil
            }
            nextCharge = item.nextChargeDate(from: nextCycleReference, calendar: calendar)
            reminder = calendar.date(byAdding: .day, value: -clampedLead, to: nextCharge) ?? nextCharge
        }

        var components = calendar.dateComponents([.year, .month, .day], from: reminder)
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components)
    }
}
