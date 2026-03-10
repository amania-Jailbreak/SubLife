import Foundation
import UserNotifications

actor NotificationScheduler {
    static let shared = NotificationScheduler()

    private struct NotificationPlan {
        let reminderDate: Date
        let chargeDate: Date
    }

    private let center = UNUserNotificationCenter.current()
    private let prefix = "sublife.billing."
    private let calendar = Calendar.current
    private let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "MM/dd"
        return formatter
    }()

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func reschedule(
        items: [SubscriptionItem],
        leadDays: Int,
        notifyOnDueDate: Bool,
        notifyInAdvance: Bool
    ) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let pending = await center.pendingNotificationRequests()
        let managedIds = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: managedIds)

        for item in items where item.status != .canceled {
            if notifyOnDueDate, let duePlan = await dueDatePlan(for: item) {
                let content = UNMutableNotificationContent()
                content.title = "\(item.name)のお支払日です!!"
                content.body = "本日お支払い予定日です"
                content.sound = .default

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: duePlan.reminderDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: prefix + item.id.uuidString + ".due",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            }

            if notifyInAdvance, leadDays > 0, let advancePlan = await advanceDatePlan(for: item, leadDays: leadDays) {
                let content = UNMutableNotificationContent()
                content.title = "\(item.name)のお支払日が迫っています!!"
                let chargeDay = monthDayFormatter.string(from: advancePlan.chargeDate)
                content.body = "準備はできましたか? お支払い予定日は\(chargeDay)です"
                content.sound = .default

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: advancePlan.reminderDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: prefix + item.id.uuidString + ".advance",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            }
        }
    }

    private func dueDatePlan(for item: SubscriptionItem) async -> NotificationPlan? {
        let now = Date()
        var nextCharge = await item.nextChargeDate(from: now, calendar: calendar)
        guard nextCharge != .distantFuture else { return nil }
        var dueDate = dateAtNineAM(for: nextCharge)

        if dueDate <= now {
            guard let nextCycleReference = calendar.date(byAdding: .day, value: 1, to: nextCharge) else {
                return nil
            }
            nextCharge = await item.nextChargeDate(from: nextCycleReference, calendar: calendar)
            guard nextCharge != .distantFuture else { return nil }
            dueDate = dateAtNineAM(for: nextCharge)
        }
        return NotificationPlan(reminderDate: dueDate, chargeDate: nextCharge)
    }

    private func advanceDatePlan(for item: SubscriptionItem, leadDays: Int) async -> NotificationPlan? {
        let clampedLead = max(1, leadDays)
        let now = Date()

        var nextCharge = await item.nextChargeDate(from: now, calendar: calendar)
        guard nextCharge != .distantFuture else { return nil }
        var reminder = calendar.date(byAdding: .day, value: -clampedLead, to: nextCharge) ?? nextCharge
        reminder = dateAtNineAM(for: reminder)

        guard reminder <= now else {
            return NotificationPlan(reminderDate: reminder, chargeDate: nextCharge)
        }

        guard let nextCycleReference = calendar.date(byAdding: .day, value: 1, to: nextCharge) else {
            return nil
        }
        nextCharge = await item.nextChargeDate(from: nextCycleReference, calendar: calendar)
        guard nextCharge != .distantFuture else { return nil }
        let nextReminder = calendar.date(byAdding: .day, value: -clampedLead, to: nextCharge) ?? nextCharge
        return NotificationPlan(reminderDate: dateAtNineAM(for: nextReminder), chargeDate: nextCharge)
    }

    private func dateAtNineAM(for source: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: source)
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components) ?? source
    }
}
