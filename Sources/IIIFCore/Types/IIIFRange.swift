public struct IIIFRange: Sendable, Codable {
  public let id: String
  public let type: String
  public let label: IIIFLanguageMap?
  public let items: [IIIFRangeItem]?
  public let behavior: String?
}
