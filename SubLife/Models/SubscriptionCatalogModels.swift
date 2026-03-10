import Foundation

struct CatalogPlan: Identifiable, Codable, Equatable, Hashable {
  let id: String
  let name: String
  let price: Double
  let currencyCode: String
  let billingCycle: BillingCycle

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case price
    case currencyCode = "currency_code"
    case billingCycle = "billing_cycle"
  }
}

struct CatalogAppSummary: Identifiable, Codable, Equatable, Hashable {
  let id: String
  let name: String
  let company: String
  let iconURL: URL?
  let category: SubscriptionCategory?
  let symbolNameFallback: String?
  let plans: [CatalogPlan]

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case company
    case iconURL = "icon_url"
    case category
    case symbolNameFallback = "symbol_name_fallback"
    case plans
  }

  init(
    id: String,
    name: String,
    company: String,
    iconURL: URL?,
    category: SubscriptionCategory?,
    symbolNameFallback: String?,
    plans: [CatalogPlan]
  ) {
    self.id = id
    self.name = name
    self.company = company
    self.iconURL = iconURL
    self.category = category
    self.symbolNameFallback = symbolNameFallback
    self.plans = plans
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    company = try container.decode(String.self, forKey: .company)

    if let iconRaw = try container.decodeIfPresent(String.self, forKey: .iconURL),
      let parsedURL = URL(string: iconRaw)
    {
      iconURL = parsedURL
    } else {
      iconURL = nil
    }

    if let categoryRaw = try container.decodeIfPresent(String.self, forKey: .category) {
      category = SubscriptionCategory(rawValue: categoryRaw)
    } else {
      category = nil
    }

    symbolNameFallback = try container.decodeIfPresent(String.self, forKey: .symbolNameFallback)
    plans = try container.decodeIfPresent([CatalogPlan].self, forKey: .plans) ?? []
  }
}
