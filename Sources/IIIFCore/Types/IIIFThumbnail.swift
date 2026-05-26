public struct IIIFThumbnail: Sendable {
  public let id: String
  public let type: String
  public let format: String?
  public let width: Int?
  public let height: Int?
  public let service: [IIIFImageService]?
}

#if SERVER
  extension IIIFThumbnail: Codable {}
#endif
