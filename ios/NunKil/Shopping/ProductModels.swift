import Foundation

// Mirrors src/nunkil/schemas.py. The backend speaks snake_case; LookupClient
// converts keys, so `spoken_name` ⇄ `spokenName`.

enum Region: String, Codable {
  case jp
  case kr
}

struct ProductMatch: Codable, Identifiable, Hashable {
  var id = UUID()
  var name: String
  var price: Int?
  var currency: String
  var source: String
  var jan: String?
  var brand: String?
  var seller: String?
  var url: String?

  enum CodingKeys: String, CodingKey {
    case name, price, currency, source, jan, brand, seller, url
  }
}

struct ProductLookup: Codable {
  var query: String
  var region: Region
  var identity: ProductMatch?
  var cheapest: ProductMatch?
  var spokenName: String?
  var matches: [ProductMatch]

  var isEmpty: Bool { matches.isEmpty }
}
