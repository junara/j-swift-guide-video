// SVG ファイル (プロジェクトの assets/*.svg) を読んで、描画 DSL で描く。
// 道具などの静止した見た目を、ブラウザや Inkscape・Figma で見たり直したりできる形で持つため。動きは visual (Swift) で付ける。
//   - 対応する要素: svg g path rect circle ellipse line polyline polygon text(tspan) と、defs の linearGradient
//     (radialGradient は最初の色の単色で描く。image use clipPath mask filter などは描かずに警告する)
//   - 属性は presentation 属性・<style> のクラス (.名前 { … })・style 属性 の順に上書きする
//   - id (Inkscape のレイヤーは inkscape:label も) を付けた要素は、visual から隠す・透明度・変形・色を変えられる (SvgLayer)
//   - id が part- で始まる要素は描かずに、持つ所などの位置 (parts) にする。中心 (円なら中心、ほかは外接矩形の中心) を使う
//   - 原点は part-origin、無ければ viewBox の底の中心 (kit の道具と同じ)。parts の座標は原点からの位置
//   - fill・stroke に var(--名前, 代わりの色) と書くと、描くときに渡した色 (動画の配色の ink・primary など) で塗る。
//     ブラウザや描画ツールでは代わりの色で見える (グラデーションの stop-color の var は、配色ではなく代わりの色で描く)
import CoreGraphics
import Foundation

/// SVG の 1 つの要素 (id か inkscape:label で指す) の描き方の変更。transform は原点からの座標 (parts と同じ) で掛かる
public struct SvgLayer: Sendable {
  /// true で隠す / false で display:none の要素も出す / nil は SVG のまま
  public var hidden: Bool?
  public var opacity: Double
  public var transform: [Tf]
  /// 中のすべての図形の塗り・線をこの色にする
  public var fill: Paint?
  public var stroke: Paint?
  public init(hidden: Bool? = nil, opacity: Double = 1, transform: [Tf] = [], fill: Paint? = nil, stroke: Paint? = nil) {
    self.hidden = hidden
    self.opacity = opacity
    self.transform = transform
    self.fill = fill
    self.stroke = stroke
  }
  public static let hidden = SvgLayer(hidden: true)
  public static let shown = SvgLayer(hidden: false)
}

public final class SVGDocument: @unchecked Sendable {
  /// 解析した要素 (継承する属性は解決済み)
  final class Node {
    enum Kind {
      case group
      case shape(CGPath, canFill: Bool)
      case text(String, x: Double, y: Double)
    }
    var kind: Kind
    var names: [String]
    var transform: CGAffineTransform
    var opacity: Double
    var hidden: Bool
    var style: Computed
    var children: [Node] = []
    init(kind: Kind, names: [String], transform: CGAffineTransform, opacity: Double, hidden: Bool, style: Computed) {
      self.kind = kind
      self.names = names
      self.transform = transform
      self.opacity = opacity
      self.hidden = hidden
      self.style = style
    }
  }

  /// 継承する属性 (SVG の既定値から始める)
  struct Computed {
    var fill: Paint = .black
    var stroke: Paint = .none
    /// currentColor の色 (color 属性)
    var color: Paint = .black
    /// var(--名前) で指定した色の名前 (描くときに渡した色があればそれで塗る。無ければ fill / stroke の代わりの色)
    var fillVar: String? = nil
    var strokeVar: String? = nil
    var strokeWidth: Double = 1
    var linecap: LineCap = .butt
    var linejoin: LineJoin = .miter
    var dash: [Double] = []
    var dashOffset: Double = 0
    var fillOpacity: Double = 1
    var strokeOpacity: Double = 1
    var fillRule: FillRule = .nonzero
    var fontSize: Double = 16
    var fontFamily: String? = nil
    var fontWeight: Double = 400
    var textAnchor: TextAnchor = .start
    var visible = true
  }

  /// viewBox の左上と大きさ
  public let viewBox: CGRect
  /// 原点 (SVG の座標)
  public let origin: Pt
  /// 持つ所などの位置 (原点からの座標)。part-lidEdge → ("lidEdge", Pt)
  public let parts: [(String, Pt)]
  /// visual から指せる名前 (id と inkscape:label。Inkscape などが自動で付けた path123 のような id は除く)
  public let layerNames: [String]
  /// var(--名前) で使っている色の名前
  public let colorNames: [String]
  /// 描けない要素・属性の警告
  public let warnings: [String]
  let root: Node

  init(viewBox: CGRect, origin: Pt, parts: [(String, Pt)], layerNames: [String], colorNames: [String], warnings: [String], root: Node) {
    self.viewBox = viewBox
    self.origin = origin
    self.parts = parts
    self.layerNames = layerNames
    self.colorNames = colorNames
    self.warnings = warnings
    self.root = root
  }

  // ---------- 読み込み ----------

  /// 要素の入れ子の上限 (ふつうの SVG は 10 段ほど)
  static let maxDepth = 32

  nonisolated(unsafe) private static var cache: [String: (Date, SVGDocument)] = [:]
  /// 読めなかったファイル (毎フレーム・全スレッドで読み直さないよう、変更されるまでは同じエラーを返す)
  nonisolated(unsafe) private static var failed: [String: (Date, Error)] = [:]
  private static let lock = NSLock()

  /// ファイルを読む (同じファイルは変更されるまで読み直さない)
  public static func load(_ url: URL) throws -> SVGDocument {
    let mtime = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? .distantPast
    lock.lock()
    if let (t, doc) = cache[url.path], t == mtime { lock.unlock(); return doc }
    if let (t, e) = failed[url.path], t == mtime { lock.unlock(); throw e }
    lock.unlock()
    do {
      let data = try Data(contentsOf: url)
      let doc = try parse(data, name: url.lastPathComponent)
      lock.lock()
      cache[url.path] = (mtime, doc)
      failed[url.path] = nil
      lock.unlock()
      return doc
    } catch {
      lock.lock()
      failed[url.path] = (mtime, error)
      lock.unlock()
      throw error
    }
  }

  /// XML を要素の木にする
  final class Element {
    let name: String
    let attrs: [String: String]
    var children: [Element] = []
    var text = ""
    init(name: String, attrs: [String: String]) { self.name = name; self.attrs = attrs }
    func attr(_ k: String) -> String? { attrs[k] }
  }

  final class TreeBuilder: NSObject, XMLParserDelegate {
    var stack: [Element] = []
    var root: Element?
    var tooDeep = false
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
      // 解析も描画も要素の深さだけ再帰する (書き出しのスレッドのスタックは 512 KB)。入れ子が深すぎる SVG は、スタックがあふれる前に止める
      if stack.count >= SVGDocument.maxDepth { tooDeep = true; parser.abortParsing(); return }
      let e = Element(name: elementName, attrs: attributeDict)
      if let top = stack.last { top.children.append(e) } else { root = e }
      stack.append(e)
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
      if !stack.isEmpty { stack.removeLast() }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
      append(string)
    }
    /// <style><![CDATA[ … ]]></style> (Illustrator などが書く) の中身も文字として受け取る
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
      append(String(decoding: CDATABlock, as: UTF8.self))
    }
    func append(_ string: String) {
      guard let top = stack.last else { return }
      top.text += string
      // <text>A <tspan>B</tspan> C</text> のように文字と子要素が混ざるとき、順番を保つために文字も子 (#text) として持つ
      if let last = top.children.last, last.name == "#text" { last.text += string } else {
        let t = Element(name: "#text", attrs: [:])
        t.text = string
        top.children.append(t)
      }
    }
  }

  public static func parse(_ data: Data, name: String = "svg") throws -> SVGDocument {
    let p = XMLParser(data: data)
    p.shouldProcessNamespaces = true
    let b = TreeBuilder()
    p.delegate = b
    let ok = p.parse()
    if b.tooDeep { throw JGVError("\(name) は要素の入れ子が深すぎます (\(maxDepth) 段まで)") }
    guard ok, let top = b.root, top.name == "svg" else {
      throw JGVError("\(name) を SVG として読めません\(p.parserError.map { " (\($0.localizedDescription))" } ?? "")")
    }
    var builder = Builder(top)
    return builder.build()
  }

  /// 要素の木から、描く木と parts を作る
  struct Builder {
    let top: Element
    var gradients: [String: Element] = [:]
    var classRules: [String: [String: String]] = [:]
    var warnings: [String] = []
    var parts: [(String, Pt)] = []
    var names: [String] = []
    var colorNames: [String] = []

    init(_ top: Element) { self.top = top }

    mutating func build() -> SVGDocument {
      collect(top)
      let vb = viewBoxOf(top)
      let root = node(top, Computed(), .identity) ?? Node(kind: .group, names: [], transform: .identity, opacity: 1, hidden: false, style: Computed())
      root.transform = .identity // svg 要素の x / y などは使わない
      let origin = parts.first { $0.0 == "origin" }?.1 ?? Pt(vb.midX, vb.maxY)
      let rel = parts.filter { $0.0 != "origin" }.map { ($0.0, Pt($0.1.x - origin.x, $0.1.y - origin.y)) }
      var seen = Set<String>()
      let ws = warnings.filter { seen.insert($0).inserted }
      var seenColors = Set<String>()
      return SVGDocument(viewBox: vb, origin: origin, parts: rel, layerNames: names, colorNames: colorNames.filter { seenColors.insert($0).inserted }, warnings: ws, root: root)
    }

    /// グラデーションと <style> のクラスを集める
    mutating func collect(_ e: Element) {
      if e.name == "linearGradient" || e.name == "radialGradient", let id = e.attr("id") { gradients[id] = e }
      if e.name == "style" { parseCSS(e.text) }
      if e.name == "stop", ((e.attr("stop-color") ?? "") + (e.attr("style") ?? "")).contains("var(") {
        warnings.append("グラデーションの stop-color の var(--…) は配色の色にならない (代わりの色で描く)")
      }
      for c in e.children { collect(c) }
    }

    mutating func parseCSS(_ css: String) {
      let noComments = css.replacingOccurrences(of: "/\\*[\\s\\S]*?\\*/", with: "", options: .regularExpression)
      for rule in noComments.components(separatedBy: "}") {
        let parts = rule.components(separatedBy: "{")
        guard parts.count == 2 else { continue }
        let decls = SVGDocument.declarations(parts[1])
        for sel in parts[0].split(separator: ",") {
          let s = sel.trimmingCharacters(in: .whitespacesAndNewlines)
          if s.hasPrefix("."), s.dropFirst().allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) {
            classRules[String(s.dropFirst()), default: [:]].merge(decls) { $1 }
          } else if !s.isEmpty {
            warnings.append("<style> のセレクタ \(s) (クラス .名前 だけに対応)")
          }
        }
      }
    }

    func viewBoxOf(_ e: Element) -> CGRect {
      if let v = e.attr("viewBox") {
        let n = SVGDocument.numbers(v)
        if n.count == 4, n[2] > 0, n[3] > 0 { return CGRect(x: n[0], y: n[1], width: n[2], height: n[3]) }
      }
      let w = e.attr("width").flatMap(SVGDocument.length) ?? 100
      let h = e.attr("height").flatMap(SVGDocument.length) ?? 100
      return CGRect(x: 0, y: 0, width: w, height: h)
    }

    /// 要素の属性 (presentation 属性 < クラス < style 属性)
    func props(_ e: Element) -> [String: String] {
      var out = e.attrs
      for c in (e.attr("class") ?? "").split(separator: " ") { if let r = classRules[String(c)] { out.merge(r) { $1 } } }
      if let st = e.attr("style") { out.merge(SVGDocument.declarations(st)) { $1 } }
      return out
    }

    /// 塗りの値と、var(--名前) ならその名前。inherit は親の値 (parent / parentVar)、currentColor は color 属性の色
    mutating func paintRef(_ raw: String, _ parent: Paint, _ parentVar: String?, color: Paint) -> (Paint, String?) {
      let s = raw.trimmingCharacters(in: .whitespaces)
      if s == "inherit" { return (parent, parentVar) }
      if s == "currentColor" { return (color, nil) }
      if let (key, fallback) = SVGDocument.varRef(s) {
        guard let key else { return (paint(fallback, color), nil) }
        colorNames.append(key)
        if fallback.isEmpty { warnings.append("var(--\(key)) に代わりの色が無い (ブラウザでは黒になる。var(--\(key), #色) と書く)") }
        // 代わりの色がさらに var(…) なら、その代わりの色 (ブラウザでも外の変数は無いので同じになる)
        return (fallback.isEmpty ? .black : paint(SVGDocument.varFallback(fallback), color), key)
      }
      return (paint(s, color), nil)
    }

    /// 塗りの値 (current は currentColor の色)
    func paint(_ raw: String, _ current: Paint) -> Paint {
      let s = raw.trimmingCharacters(in: .whitespaces)
      if s == "currentColor" { return current }
      if s.hasPrefix("url(") {
        let id = s.dropFirst(4).prefix { $0 != ")" }.trimmingCharacters(in: CharacterSet(charactersIn: "#'\" "))
        if let g = gradients[id] { return gradientPaint(g) }
        // url(#x) の後ろの代わりの色
        let fallback = s.drop { $0 != ")" }.dropFirst().trimmingCharacters(in: .whitespaces)
        return fallback.isEmpty ? .none : Paint(fallback)
      }
      return Paint(s)
    }

    /// グラデーションの色 (xlink:href で別のグラデーションの色を使うものも)
    func stops(_ g: Element, depth: Int = 0) -> [(Double, Paint)] {
      let own = g.children.filter { $0.name == "stop" }.map { st -> (Double, Paint) in
        let p = props(st)
        let off = p["offset"].map { $0.hasSuffix("%") ? (Double($0.dropLast()) ?? 0) / 100 : Double($0) ?? 0 } ?? 0
        let op = p["stop-opacity"].flatMap { Double($0) } ?? 1
        return (off, Paint(SVGDocument.varFallback(p["stop-color"] ?? "black")).opacity(op))
      }
      if !own.isEmpty || depth > 4 { return own }
      if let href = g.attr("xlink:href") ?? g.attr("href"), let other = gradients[String(href.drop { $0 == "#" })] { return stops(other, depth: depth + 1) }
      return []
    }

    func gradientPaint(_ g: Element) -> Paint {
      let st = stops(g)
      guard !st.isEmpty else { return .none }
      if g.name == "radialGradient" || st.count == 1 { return st[0].1 }
      let user = g.attr("gradientUnits") == "userSpaceOnUse"
      func v(_ k: String, _ d: Double) -> Double {
        guard let s = g.attr(k) else { return d }
        if s.hasSuffix("%") { return (Double(s.dropLast()) ?? 0) / 100 }
        return SVGDocument.length(s) ?? d
      }
      // gradientTransform (Inkscape が図形を動かす・伸ばすと付ける) はグラデーションの座標に掛かる
      let gt = g.attr("gradientTransform").map(SVGDocument.transform) ?? .identity
      return .linear(LinearGradient(x1: v("x1", 0), y1: v("y1", 0), x2: v("x2", user ? 0 : 1), y2: v("y2", 0), stops: st,
                                    units: user ? .userSpaceOnUse : .objectBoundingBox, transform: gt))
    }

    /// 継承する属性を解決する
    mutating func computed(_ p: [String: String], _ parent: Computed) -> Computed {
      var c = parent
      if let v = p["color"], v != "inherit" { c.color = paint(SVGDocument.varFallback(v), parent.color) }
      if let v = p["fill"] { (c.fill, c.fillVar) = paintRef(v, parent.fill, parent.fillVar, color: c.color) }
      if let v = p["stroke"] { (c.stroke, c.strokeVar) = paintRef(v, parent.stroke, parent.strokeVar, color: c.color) }
      if let v = p["stroke-width"].flatMap(SVGDocument.length) { c.strokeWidth = v }
      if let v = p["stroke-linecap"] { c.linecap = v == "round" ? .round : v == "square" ? .square : .butt }
      if let v = p["stroke-linejoin"] { c.linejoin = v == "round" ? .round : v == "bevel" ? .bevel : .miter }
      if let v = p["stroke-dasharray"] { c.dash = v == "none" ? [] : v.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { SVGDocument.length(String($0)) } }
      if let v = p["stroke-dashoffset"].flatMap(SVGDocument.length) { c.dashOffset = v }
      if let v = p["fill-opacity"].flatMap({ Double($0) }) { c.fillOpacity = v }
      if let v = p["stroke-opacity"].flatMap({ Double($0) }) { c.strokeOpacity = v }
      if let v = p["fill-rule"] { c.fillRule = v == "evenodd" ? .evenodd : .nonzero }
      if let v = p["font-size"].flatMap(SVGDocument.length) { c.fontSize = v }
      if let v = p["font-family"] { c.fontFamily = v.split(separator: ",").first.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'\" ")) } }
      if let v = p["font-weight"] { c.fontWeight = v == "bold" ? 700 : v == "normal" ? 400 : Double(v) ?? c.fontWeight }
      if let v = p["text-anchor"] { c.textAnchor = v == "middle" ? .middle : v == "end" ? .end : .start }
      if let v = p["visibility"] { c.visible = v == "visible" }
      return c
    }

    /// 要素を描く木の節にする。parent は親までの変形 (SVG の座標へ)
    mutating func node(_ e: Element, _ inherited: Computed, _ parent: CGAffineTransform) -> Node? {
      let skip: Set<String> = ["defs", "metadata", "title", "desc", "namedview", "style", "linearGradient", "radialGradient", "stop", "script", "#text"]
      if skip.contains(e.name) { return nil }
      let p = props(e)
      let style = computed(p, inherited)
      let tf = p["transform"].map(SVGDocument.transform) ?? .identity
      let ctm = tf.concatenating(parent)
      let id = e.attr("id")
      let label = e.attr("inkscape:label") ?? e.attr("label")
      let nodeNames = [id, label].compactMap { $0 }
      for a in ["clip-path", "mask", "filter"] where p[a] != nil && p[a] != "none" { warnings.append("\(a) 属性 (無視して描く)") }

      let shape: CGPath?
      var canFill = true
      switch e.name {
      case "svg", "g", "a", "switch":
        let n = Node(kind: .group, names: nodeNames, transform: tf, opacity: p["opacity"].flatMap { Double($0) } ?? 1, hidden: p["display"] == "none", style: style)
        for c in e.children { if let k = node(c, style, ctm) { n.children.append(k) } }
        if id.map(isAutoId) == false || label != nil { names.append(label ?? id!) }
        return n
      case "path": shape = SVGPath.parse(e.attr("d") ?? "")
      case "rect":
        let w = num(e, "width"), h = num(e, "height")
        let rx = e.attr("rx").flatMap(SVGDocument.length), ry = e.attr("ry").flatMap(SVGDocument.length)
        shape = roundedRectPath(num(e, "x"), num(e, "y"), w, h, rx ?? ry ?? 0, ry ?? rx ?? 0)
      case "circle":
        // r が 0 以下の円は描かない (SVG と同じ。負の r を CGRect に渡すと正の円になってしまう)
        let r = num(e, "r")
        shape = r > 0 ? CGPath(ellipseIn: CGRect(x: num(e, "cx") - r, y: num(e, "cy") - r, width: 2 * r, height: 2 * r), transform: nil) : CGMutablePath()
      case "ellipse":
        let rx = num(e, "rx"), ry = num(e, "ry")
        shape = rx > 0 && ry > 0 ? CGPath(ellipseIn: CGRect(x: num(e, "cx") - rx, y: num(e, "cy") - ry, width: 2 * rx, height: 2 * ry), transform: nil) : CGMutablePath()
      case "line":
        let m = CGMutablePath()
        m.move(to: CGPoint(x: num(e, "x1"), y: num(e, "y1")))
        m.addLine(to: CGPoint(x: num(e, "x2"), y: num(e, "y2")))
        shape = m
        canFill = false
      case "polyline", "polygon":
        let n = SVGDocument.numbers(e.attr("points") ?? "")
        let m = CGMutablePath()
        for i in stride(from: 0, to: n.count - 1, by: 2) {
          let q = CGPoint(x: n[i], y: n[i + 1])
          if i == 0 { m.move(to: q) } else { m.addLine(to: q) }
        }
        if e.name == "polygon" { m.closeSubpath() }
        shape = m
      case "text":
        let s = textOf(e).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        let x = e.attr("x").flatMap { $0.split(separator: " ").first.flatMap { SVGDocument.length(String($0)) } } ?? 0
        let y = e.attr("y").flatMap { $0.split(separator: " ").first.flatMap { SVGDocument.length(String($0)) } } ?? 0
        if let id, id.hasPrefix("part-") {
          let q = CGPoint(x: x, y: y).applying(ctm)
          parts.append((String(id.dropFirst(5)), Pt(q.x, q.y)))
          return nil
        }
        if id.map(isAutoId) == false || label != nil { names.append(label ?? id!) }
        return Node(kind: .text(s, x: x, y: y), names: nodeNames, transform: tf, opacity: p["opacity"].flatMap { Double($0) } ?? 1, hidden: p["display"] == "none", style: style)
      default:
        warnings.append("<\(e.name)> (描かない)")
        return nil
      }
      guard let shape else { return nil }
      if let id, id.hasPrefix("part-") {
        let b = shape.boundingBoxOfPath
        let q = CGPoint(x: b.midX, y: b.midY).applying(ctm)
        parts.append((String(id.dropFirst(5)), Pt(q.x, q.y)))
        return nil
      }
      if id.map(isAutoId) == false || label != nil { names.append(label ?? id!) }
      return Node(kind: .shape(shape, canFill: canFill), names: nodeNames, transform: tf, opacity: p["opacity"].flatMap { Double($0) } ?? 1, hidden: p["display"] == "none", style: style)
    }

    func num(_ e: Element, _ k: String) -> Double { e.attr(k).flatMap(SVGDocument.length) ?? 0 }

    /// 要素の中の文字 (文字と tspan が混ざっていても、書かれた順に)
    func textOf(_ e: Element) -> String { e.children.map { $0.name == "#text" ? $0.text : textOf($0) }.joined() }

    /// 描画ツールが自動で付けた id (path123・g45・rect7・layer1 など)
    func isAutoId(_ id: String) -> Bool {
      id.range(of: "^(path|g|rect|circle|ellipse|line|polyline|polygon|text|tspan|layer|svg|use|image)[-_]?[0-9]+(-[0-9]+)*$", options: .regularExpression) != nil
    }
  }

  // ---------- 値の読み方 ----------

  /// "var(--名前, 代わり)" を (名前, 代わり) に。名前が -- で始まらなければ名前は nil。var(…) でなければ nil
  static func varRef(_ s: String) -> (String?, String)? {
    guard s.hasPrefix("var("), let close = s.lastIndex(of: ")") else { return nil }
    let inner = s[s.index(s.startIndex, offsetBy: 4)..<close]
    let comma = inner.firstIndex(of: ",")
    let name = inner[..<(comma ?? inner.endIndex)].trimmingCharacters(in: .whitespaces)
    let fallback = comma.map { inner[inner.index(after: $0)...].trimmingCharacters(in: .whitespaces) } ?? ""
    return (name.hasPrefix("--") ? String(name.dropFirst(2)) : nil, fallback)
  }

  /// var(…) なら代わりの色 (入れ子も外す)、そうでなければそのまま
  static func varFallback(_ s: String) -> String {
    var t = s.trimmingCharacters(in: .whitespaces)
    while let (_, fb) = varRef(t) { t = fb }
    return t
  }

  /// "a: b; c: d" を辞書に
  static func declarations(_ s: String) -> [String: String] {
    var out: [String: String] = [:]
    for d in s.split(separator: ";") {
      guard let i = d.firstIndex(of: ":") else { continue }
      out[d[..<i].trimmingCharacters(in: .whitespacesAndNewlines)] = d[d.index(after: i)...].trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return out
  }

  /// 長さ ("12", "12px", "12.5")。px 以外の単位は数だけを使う
  static func length(_ s: String) -> Double? {
    let t = s.trimmingCharacters(in: .whitespaces)
    var num = t.prefix { $0.isNumber || $0 == "." || $0 == "-" || $0 == "+" || $0 == "e" || $0 == "E" }
    // "1.5em" の e は単位の頭なので、数として読めなければ外す
    if Double(num) == nil, num.last == "e" || num.last == "E" { num = num.dropLast() }
    guard let v = Double(num), v.isFinite else { return nil }
    return v
  }

  /// 数の並び ("10 20", "10,20", 区切りを省いた "10-5" や "1.5.5" (svgo などが書く) も) を読む
  static func numbers(_ s: String) -> [Double] {
    numberRegex.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { Range($0.range, in: s).flatMap { Double(s[$0]) }.flatMap { $0.isFinite ? $0 : nil } }
  }
  /// 数の正規表現 (要素ごとに作り直さない。NSRegularExpression はスレッドをまたいで使える)
  private static let numberRegex = try! NSRegularExpression(pattern: "[-+]?(?:[0-9]+\\.?[0-9]*|\\.[0-9]+)(?:[eE][-+]?[0-9]+)?")

  /// transform 属性を行列に (左の項目から順に掛かる)
  static func transform(_ s: String) -> CGAffineTransform {
    var tfs: [Tf] = []
    let re = try! NSRegularExpression(pattern: "(matrix|translate|scale|rotate|skewX|skewY)\\s*\\(([^)]*)\\)")
    for m in re.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
      let name = String(s[Range(m.range(at: 1), in: s)!])
      let a = numbers(String(s[Range(m.range(at: 2), in: s)!]))
      switch (name, a.count) {
      case ("matrix", 6): tfs.append(.matrix(CGAffineTransform(a: a[0], b: a[1], c: a[2], d: a[3], tx: a[4], ty: a[5])))
      case ("translate", 1...): tfs.append(.translate(a[0], a.count > 1 ? a[1] : 0))
      case ("scale", 1...): tfs.append(.scale(a[0], a.count > 1 ? a[1] : a[0]))
      case ("rotate", 1...): tfs.append(.rotate(a[0], a.count > 2 ? a[1] : 0, a.count > 2 ? a[2] : 0))
      case ("skewX", 1...): tfs.append(.skewX(a[0]))
      case ("skewY", 1...): tfs.append(.skewY(a[0]))
      default: break
      }
    }
    return affineOf(tfs)
  }

  // ---------- 描画 ----------

  /// SVG の座標のまま描く (原点などへの移動は呼ぶ側の g で)。layers は id か inkscape:label → 変更、
  /// colors は var(--名前) の名前 → 色
  public func draw(layers: [String: SvgLayer] = [:], colors: [String: Paint] = [:]) {
    // 外側の g (道具の Placed の輪郭線など) の属性を引き継がないように、SVG の既定値に戻してから描く
    g(fill: .black, stroke: Paint.none, strokeWidth: 1, strokeLinecap: .butt, strokeLinejoin: .miter, strokeDasharray: [], strokeDashoffset: 0, fillRule: .nonzero) {
      for c in root.children { drawNode(c, .identity, layers, colors, nil, nil) }
    }
  }

  func drawNode(_ n: Node, _ parent: CGAffineTransform, _ layers: [String: SvgLayer], _ colors: [String: Paint], _ fillO: Paint?, _ strokeO: Paint?) {
    let layer = n.names.lazy.compactMap { layers[$0] }.first
    if layer?.hidden ?? n.hidden { return }
    var m = n.transform
    if let layer, !layer.transform.isEmpty {
      // 原点からの座標で掛ける変形を、この要素の親の座標に直す: 親 → SVG → (原点基準の変形) → SVG → 親
      let l = affineOf([.translate(origin.x, origin.y)] + layer.transform + [.translate(-origin.x, -origin.y)])
      m = n.transform.concatenating(parent).concatenating(l).concatenating(parent.inverted())
    }
    let opacity = n.opacity * (layer?.opacity ?? 1)
    let fill = layer?.fill ?? fillO
    let stroke = layer?.stroke ?? strokeO
    var st = n.style
    if let v = st.fillVar, let c = colors[v] { st.fill = c }
    if let v = st.strokeVar, let c = colors[v] { st.stroke = c }
    switch n.kind {
    case .group:
      let ctm = m.concatenating(parent)
      g(opacity: opacity, transform: [.matrix(m)]) {
        for c in n.children { drawNode(c, ctm, layers, colors, fill, stroke) }
      }
    case let .shape(p, canFill):
      if !st.visible { return }
      path(cgPath: p, fill: canFill ? (fill ?? st.fill) : Paint.none, stroke: stroke ?? st.stroke, strokeWidth: st.strokeWidth,
           strokeLinecap: st.linecap, strokeLinejoin: st.linejoin, strokeDasharray: st.dash, strokeDashoffset: st.dashOffset,
           opacity: opacity, fillOpacity: st.fillOpacity, strokeOpacity: st.strokeOpacity, fillRule: st.fillRule, transform: [.matrix(m)])
    case let .text(s, x, y):
      if !st.visible { return }
      text(s, x: x, y: y, fontSize: st.fontSize, fontWeight: st.fontWeight, fontFamily: st.fontFamily,
           fill: (fill ?? st.fill).opacity(st.fillOpacity), stroke: stroke ?? st.stroke, strokeWidth: st.strokeWidth,
           textAnchor: st.textAnchor, opacity: opacity, transform: [.matrix(m)])
    }
  }
}
