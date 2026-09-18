import Foundation

/// Turns a lookup into one short sentence. This is heard, not read: every extra
/// word costs the wearer time while standing in a shop aisle.
enum ProductSpeech {
  static let notFound = "무슨 상품인지 못 찾았어요."
  static let noBarcode = "바코드를 못 찾았어요. 포장을 카메라 쪽으로 돌려 주세요."

  /// "堅あげポテト うすしお. 온라인 최저 500엔."
  static func describe(_ lookup: ProductLookup) -> String {
    guard let name = lookup.spokenName ?? lookup.identity?.name, !name.isEmpty else {
      return notFound
    }
    guard let price = lookup.cheapest?.price, let currency = lookup.cheapest?.currency else {
      return name
    }
    return "\(name). 온라인 최저 \(money(price, currency))."
  }

  /// Compares what the shelf asks with what it costs online. Shipping is always
  /// mentioned: an online price that ignores it makes the wrong purchase look right.
  static func compare(_ lookup: ProductLookup, shelfPrice: Int) -> String {
    guard let online = lookup.cheapest?.price, let currency = lookup.cheapest?.currency else {
      return describe(lookup)
    }
    let name = lookup.spokenName ?? lookup.identity?.name ?? ""
    let prefix = name.isEmpty ? "" : "\(name). "
    let shelf = money(shelfPrice, currency)

    if online < shelfPrice {
      let saving = money(shelfPrice - online, currency)
      return "\(prefix)여기 \(shelf), 온라인 \(money(online, currency)). \(saving) 싸요. 배송비는 별도예요."
    }
    if online > shelfPrice {
      return "\(prefix)여기 \(shelf), 온라인 \(money(online, currency)). 여기가 더 싸요."
    }
    return "\(prefix)여기 \(shelf), 온라인도 같아요."
  }

  static func money(_ amount: Int, _ currency: String) -> String {
    let number = NumberFormatter.localizedString(from: NSNumber(value: amount), number: .decimal)
    switch currency {
    case "JPY": return "\(number)엔"
    case "KRW": return "\(number)원"
    default: return "\(number) \(currency)"
    }
  }
}
