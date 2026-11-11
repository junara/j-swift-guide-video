// プロジェクトの assets/*.svg を道具として描く。原点は part-origin (無ければ viewBox の底の中心)、
// 持つ所は part-<名前> の要素 (svgParts で読む)。描き方の細部は JGVCore/SVGDocument.swift
import Foundation
import JGVCore

/// assets のフォルダ ($JGV_ASSETS、無ければ実行したフォルダ (プロジェクト) の assets/)
public func assetsDir() -> URL {
  if let s = ProcessInfo.processInfo.environment["JGV_ASSETS"], !s.isEmpty { return URL(fileURLWithPath: s) }
  return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("assets")
}

nonisolated(unsafe) private var warned = Set<String>()
private let warnLock = NSLock()

/// 1 回だけ警告を出す (フレームごとに同じ警告を出さないように)
private func warnOnce(_ s: String) {
  warnLock.lock()
  defer { warnLock.unlock() }
  if warned.insert(s).inserted { FileHandle.standardError.write("WARN: \(s)\n".data(using: .utf8)!) }
}

/// assets/<name>.svg を読む (読めなければ警告して nil)
public func svgDocument(_ name: String) -> SVGDocument? {
  let url = assetsDir().appendingPathComponent(name.hasSuffix(".svg") ? name : "\(name).svg")
  do {
    let doc = try SVGDocument.load(url)
    for w in doc.warnings { warnOnce("assets/\(url.lastPathComponent): \(w)") }
    return doc
  } catch {
    warnOnce(FileManager.default.fileExists(atPath: url.path) ? error.localizedDescription : "assets/\(url.lastPathComponent) がありません")
    return nil
  }
}

/// assets/<name>.svg の持つ所 (part-<名前> の位置。原点からの座標)。place(x, y, scale, angle, svgParts("cup").rim) のように使う
public func svgParts(_ name: String) -> Parts {
  Parts(svgDocument(name)?.parts ?? [])
}

/// assets/<name>.svg を、原点を (x, y) に合わせて描く。scale で拡大、angle (度, 時計回り) で傾け、flip で左右反転する。
/// layers で id (Inkscape のレイヤーは名前でも) を指して、隠す・透明度・変形 (原点からの座標)・色を変える:
///   Svg("cup", x: 900, y: 760, layers: ["lid": SvgLayer(transform: [.rotate(-30 * peel, 112, -236)]), "steam": .hidden])
/// SVG の var(--ink) などは動画の配色の色で塗る (colors で名前ごとに上書き・追加できる)。
/// 末尾の { } の中は原点からの座標 (svgParts と同じ) で描き、SVG と一緒に拡大・回転・反転する (変わる文字・数字など):
///   Svg("timer", x: 680, y: 760) { text(display, x: 0, y: -70, fontSize: 32, textAnchor: .middle) }
/// ファイルが無いときは赤い破線の枠を描く
public func Svg(_ name: String, x: Double, y: Double, scale: Double = 1, angle: Double = 0, flip: Bool = false, opacity: Double = 1,
                layers: [String: SvgLayer] = [:], colors: [String: Paint] = [:], _ content: () -> Void = {}) {
  let place: [Tf] = [.translate(x, y), .rotate(angle), .scale(flip ? -scale : scale, scale)]
  guard let doc = svgDocument(name) else {
    g(opacity: opacity, transform: place) {
      rect(x: -60, y: -120, width: 120, height: 120, fill: Paint.none, stroke: "#d9534f", strokeWidth: 4, strokeDasharray: [10, 8])
      text(name, x: 0, y: -52, fontSize: 18, fill: "#d9534f", stroke: Paint.none, textAnchor: .middle)
      content()
    }
    return
  }
  for k in layers.keys where !doc.layerNames.contains(k) { warnOnce("assets/\(name).svg に \(k) という id・レイヤーがありません (あるのは \(doc.layerNames.joined(separator: ", ")))") }
  let palette = useGuide().palette.colors.merging(colors) { $1 }
  for k in doc.colorNames where palette[k] == nil { warnOnce("assets/\(name).svg の var(--\(k)) は配色にない名前です (代わりの色で塗る。使える名前: \(palette.keys.sorted().joined(separator: ", ")))") }
  g(opacity: opacity, transform: place) {
    g(transform: [.translate(-doc.origin.x, -doc.origin.y)]) { doc.draw(layers: layers, colors: palette) }
    content()
  }
}
