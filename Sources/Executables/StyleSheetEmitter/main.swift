import CSSBuilder
import Foundation
import ArtifactCore

@main
struct StyleSheetEmitter {
  static func main() throws {
    let args = CommandLine.arguments
    let publicDir: String
    if let i = args.firstIndex(of: "--public-dir"), i + 1 < args.count {
      publicDir = args[i + 1]
    } else {
      publicDir = "Public"
    }
    StaticStyleSheetEmitter.begin(publicDirectory: publicDir)
    // ArtifactCore catalogue — add representative instances as needed.
    // Example: _ = ArtifactView(...).build()
    let paths = StaticStyleSheetEmitter.finish()
    guard !paths.isEmpty else { throw E.missing }
    for p in paths { print("Emitted /\(p)") }
  }
  enum E: Error { case missing }
}
