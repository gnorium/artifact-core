public struct IIIFImageService: Sendable, Codable {
  public let id: String
  public let type: String
  public let profile: String?
  public let width: Int?
  public let height: Int?
  public let tiles: [IIIFTileInfo]?
  public let maxWidth: Int?
  public let maxHeight: Int?
  public let sizes: [IIIFSize]?
  public let formats: [String]?
  public let qualities: [String]?
}
