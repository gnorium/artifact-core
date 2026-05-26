public struct IIIFRangeItem: Sendable {
  public let id: String
  public let type: String
}

#if SERVER
  extension IIIFRangeItem: Codable {}
#endif
