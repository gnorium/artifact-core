public struct RangeItem: Sendable {
  public let id: String
  public let type: String
}

#if SERVER
  extension RangeItem: Codable {}
#endif
