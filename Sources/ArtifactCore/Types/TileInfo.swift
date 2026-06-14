public struct TileInfo: Sendable {
  public let width: Int?
  public let height: Int?
  public let scaleFactors: [Int]?
}

#if SERVER
  extension TileInfo: Codable {}
#endif
