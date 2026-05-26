public struct IIIFContentResource: Sendable, Codable {
  public let id: String
  public let type: String
  public let format: String?
  public let width: Int?
  public let height: Int?
  public let duration: Double?
  public let label: IIIFLanguageMap?
  public let service: [IIIFImageService]?
  public let language: String?
}
