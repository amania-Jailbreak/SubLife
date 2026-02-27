import Foundation
import Combine

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published var items: [SubscriptionItem] = [] {
        didSet { save() }
    }

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        fileURL = documents.appendingPathComponent("subscriptions.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    func add(_ item: SubscriptionItem) {
        items.append(item)
        sortItems()
    }

    func update(_ item: SubscriptionItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        sortItems()
    }

    func importMerge(_ importedItems: [SubscriptionItem]) {
        guard !importedItems.isEmpty else { return }
        items.append(contentsOf: importedItems)
        sortItems()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            items.remove(at: index)
        }
    }

    private func sortItems() {
        items.sort { $0.nextBillingDate < $1.nextBillingDate }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            items = []
            return
        }
        items = (try? decoder.decode([SubscriptionItem].self, from: data)) ?? []
        sortItems()
    }

    private func save() {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
