public struct IIIFExternal: Sendable, Codable {
  public let id: String
  public let type: String
  public let format: String?
  public let label: IIIFLanguageMap?
}
