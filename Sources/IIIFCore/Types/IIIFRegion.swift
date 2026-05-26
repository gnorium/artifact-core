public enum IIIFRegion: Sendable {
  case full
  case square
  case xywh(Int, Int, Int, Int)
  case pct(Double, Double, Double, Double)

  public var stringValue: String {
    switch self {
    case .full: return "full"
    case .square: return "square"
    case let .xywh(x, y, w, h): return "\(x),\(y),\(w),\(h)"
    case let .pct(x, y, w, h): return "pct:\(x),\(y),\(w),\(h)"
    }
  }
}
