public struct IIIFTileInfo: Sendable {
  public let width: Int?
  public let height: Int?
  public let scaleFactors: [Int]?
}

#if SERVER
  extension IIIFTileInfo: Codable {}
#endif
