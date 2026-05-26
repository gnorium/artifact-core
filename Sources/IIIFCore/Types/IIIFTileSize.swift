#if CLIENT
  import EmbeddedSwiftUtilities
#endif

public enum IIIFTileSize: Sendable {
  case max
  case exact(Int, Int?)
  case pct(Double)
  case scaled(Int)

  public var stringValue: String {
    switch self {
    case .max: return "max"
    case let .exact(w, h):
      if let h { return "\(w),\(h)" }
      return "\(w),"
    case let .pct(n): return "pct:\(n)"
    case let .scaled(n): return "\(n),"
    }
  }
}
