// 描画 DSL の図形: g (グループ) / path / rect / circle / ellipse / line / polygon / text。
// SVG の要素と属性をそのまま関数と引数にしたもの。座標は動画のピクセル (y は下向き)。
// 引数の順番: 形 (d / x y width height rx / cx cy r …) → fill → stroke → strokeWidth → strokeLinecap → strokeLinejoin
//   → strokeDasharray → strokeDashoffset → opacity → fillOpacity → strokeOpacity → fillRule → transform → filter
// nil の属性は外側の g から引き継ぐ (SVG と同じ。塗りの既定は黒、線の既定は無し)
import CoreGraphics
import CoreText
import Foundation

// ---------- 変形 ----------

/// SVG の transform の 1 項目。[.translate(x, y), .rotate(a), .scale(s)] のように左から順に掛かる
public enum Tf: Sendable {
  case translate(Double, Double)
  case rotate(Double, Double, Double)
  case scale(Double, Double)
  case skewX(Double)
  case skewY(Double)
  case matrix(CGAffineTransform)

  /// 回転 (度、時計回り)
  public static func rotate(_ deg: Double) -> Tf { .rotate(deg, 0, 0) }
  public static func scale(_ s: Double) -> Tf { .scale(s, s) }
  public static func translate(_ x: Double) -> Tf { .translate(x, 0) }
}

func applyTransforms(_ cg: CGContext, _ tfs: [Tf]) {
  for t in tfs {
    switch t {
    case let .translate(x, y): cg.translateBy(x: x, y: y)
    case let .rotate(a, cx, cy):
      if cx != 0 || cy != 0 { cg.translateBy(x: cx, y: cy) }
      cg.rotate(by: a * .pi / 180)
      if cx != 0 || cy != 0 { cg.translateBy(x: -cx, y: -cy) }
    case let .scale(sx, sy): cg.scaleBy(x: sx, y: sy)
    case let .skewX(a): cg.concatenate(CGAffineTransform(a: 1, b: 0, c: tan(a * .pi / 180), d: 1, tx: 0, ty: 0))
    case let .skewY(a): cg.concatenate(CGAffineTransform(a: 1, b: tan(a * .pi / 180), c: 0, d: 1, tx: 0, ty: 0))
    case let .matrix(m): cg.concatenate(m)
    }
  }
}

/// 変形の並びを 1 つの行列にする (g の transform と同じ順番)
public func affineOf(_ tfs: [Tf]) -> CGAffineTransform {
  var m = CGAffineTransform.identity
  for t in tfs {
    switch t {
    case let .translate(x, y): m = m.translatedBy(x: x, y: y)
    case let .rotate(a, cx, cy): m = m.translatedBy(x: cx, y: cy).rotated(by: a * .pi / 180).translatedBy(x: -cx, y: -cy)
    case let .scale(sx, sy): m = m.scaledBy(x: sx, y: sy)
    case let .skewX(a): m = CGAffineTransform(a: 1, b: 0, c: tan(a * .pi / 180), d: 1, tx: 0, ty: 0).concatenating(m)
    case let .skewY(a): m = CGAffineTransform(a: 1, b: tan(a * .pi / 180), c: 0, d: 1, tx: 0, ty: 0).concatenating(m)
    case let .matrix(mm): m = mm.concatenating(m)
    }
  }
  return m
}

/// 変形を点に掛ける (place などで使う)
public func transformPoint(_ p: Pt, _ tfs: [Tf]) -> Pt {
  let q = CGPoint(x: p.x, y: p.y).applying(affineOf(tfs))
  return Pt(q.x, q.y)
}

// ---------- クリップ ----------

/// g の clip に渡す切り抜きの形 (SVG の clipPath)
public enum Clip {
  case rect(x: Double, y: Double, width: Double, height: Double, rx: Double = 0)
  case circle(cx: Double, cy: Double, r: Double)
  case ellipse(cx: Double, cy: Double, rx: Double, ry: Double)
  case path(String)
  case cgPath(CGPath)

  var cgPath: CGPath {
    switch self {
    case let .rect(x, y, w, h, rx): return roundedRectPath(x, y, w, h, rx, rx)
    case let .circle(cx, cy, r): return CGPath(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r), transform: nil)
    case let .ellipse(cx, cy, rx, ry): return CGPath(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry), transform: nil)
    case let .path(d): return SVGPath.parse(d)
    case let .cgPath(p): return p
    }
  }
}

func roundedRectPath(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ rxIn: Double, _ ryIn: Double) -> CGPath {
  guard w > 0, h > 0 else { return CGMutablePath() }
  let rx = min(max(0, rxIn), w / 2)
  let ry = min(max(0, ryIn), h / 2)
  let rect = CGRect(x: x, y: y, width: w, height: h)
  if rx <= 0 || ry <= 0 { return CGPath(rect: rect, transform: nil) }
  return CGPath(roundedRect: rect, cornerWidth: rx, cornerHeight: ry, transform: nil)
}

// ---------- グループ ----------

/// SVG の <g>。transform・opacity・clip・filter を中身にまとめて掛け、塗り・線の属性を中身に引き継ぐ
public func g(
  fill: Paint? = nil,
  stroke: Paint? = nil,
  strokeWidth: Double? = nil,
  strokeLinecap: LineCap? = nil,
  strokeLinejoin: LineJoin? = nil,
  strokeDasharray: [Double]? = nil,
  strokeDashoffset: Double? = nil,
  opacity: Double = 1,
  fillRule: FillRule? = nil,
  fontFamily: String? = nil,
  fontSize: Double? = nil,
  fontWeight: Double? = nil,
  textAnchor: TextAnchor? = nil,
  transform: [Tf] = [],
  clip: Clip? = nil,
  filter: Filter? = nil,
  _ content: () -> Void
) {
  if !(opacity > 0) { return }
  let c = RenderContext.current
  let cg = c.cg
  // jgv check の枠の記録 (書き出しは並列に描くので、記録していないときは共有の値に触らない)
  let probing = LayoutProbe.active
  let alpha = LayoutProbe.alpha
  if probing { LayoutProbe.alpha *= min(1, opacity) }
  defer { if probing { LayoutProbe.alpha = alpha } }
  c.pushStyle()
  cg.saveGState()
  defer {
    cg.restoreGState()
    c.popStyle()
  }
  if let v = fill { c.style.fill = v }
  if let v = stroke { c.style.stroke = v }
  if let v = strokeWidth { c.style.strokeWidth = v }
  if let v = strokeLinecap { c.style.strokeLinecap = v }
  if let v = strokeLinejoin { c.style.strokeLinejoin = v }
  if let v = strokeDasharray { c.style.strokeDasharray = v }
  if let v = strokeDashoffset { c.style.strokeDashoffset = v }
  if let v = fillRule { c.style.fillRule = v }
  if let v = fontFamily { c.style.fontFamily = v }
  if let v = fontSize { c.style.fontSize = v }
  if let v = fontWeight { c.style.fontWeight = v }
  if let v = textAnchor { c.style.textAnchor = v }
  applyTransforms(cg, transform)
  if let clip {
    let p = clip.cgPath
    // 空のパスで cg.clip() を呼んでも切り抜きは変わらない (何も描かないのではなく全部描いてしまう) ので、
    // 幅や高さが 0 以下の枠 (出てくる途中の rect など) は何も描かないようにする
    if p.isEmpty { cg.clip(to: .zero) } else { cg.addPath(p); cg.clip() }
  }
  let layered = opacity < 1 || filter != nil
  if layered {
    if let filter { applyFilter(c, filter, fallback: c.style.stroke.rgba ?? c.style.fill.rgba) }
    cg.setAlpha(min(1, opacity))
    cg.beginTransparencyLayer(auxiliaryInfo: nil)
    cg.setShadow(offset: .zero, blur: 0, color: nil)
    cg.setAlpha(1)
  }
  content()
  if layered { cg.endTransparencyLayer() }
}

func applyFilter(_ c: RenderContext, _ f: Filter, fallback: RGBA?) {
  let k = c.ctmScale
  switch f {
  case let .dropShadow(dx, dy, std, color):
    // 影のずれは描き先の座標 (y は上向き) で指定する
    c.cg.setShadow(offset: CGSize(width: dx * k, height: -dy * k), blur: 2 * std * k, color: color.cgColor)
  case let .glow(std, color):
    let col = color ?? fallback ?? RGBA(1, 1, 1)
    c.cg.setShadow(offset: .zero, blur: 2 * std * k, color: col.cgColor)
  }
}

// ---------- 図形 ----------

/// 図形 1 つを、今の属性 (引き継いだもの + 引数) で塗って線を引く
func drawShape(
  _ path: CGPath,
  fill: Paint?, stroke: Paint?, strokeWidth: Double?, strokeLinecap: LineCap?, strokeLinejoin: LineJoin?,
  strokeDasharray: [Double]?, strokeDashoffset: Double?, opacity: Double, fillOpacity: Double, strokeOpacity: Double,
  fillRule: FillRule?, transform: [Tf], filter: Filter?, canFill: Bool = true
) {
  // 空のパス (path("") など) は何も描かない。グラデーションは形で切り抜いて描くが、空のパスでは切り抜けず画面全体を塗ってしまう
  if !(opacity > 0) || path.isEmpty { return }
  let c = RenderContext.current
  let cg = c.cg
  let st = c.style
  let fillP = canFill ? (fill ?? st.fill) : Paint.none
  let strokeP = stroke ?? st.stroke
  let sw = strokeWidth ?? st.strokeWidth
  let hasFill = !fillP.isNone && fillOpacity > 0
  let hasStroke = !strokeP.isNone && sw > 0 && strokeOpacity > 0
  if !hasFill && !hasStroke { return }

  cg.saveGState()
  defer { cg.restoreGState() }
  applyTransforms(cg, transform)
  let layered = filter != nil || (opacity < 1 && hasFill && hasStroke)
  var alpha = min(1, opacity)
  if layered {
    if let filter { applyFilter(c, filter, fallback: (hasStroke ? strokeP : fillP).rgba) }
    cg.setAlpha(alpha)
    cg.beginTransparencyLayer(auxiliaryInfo: nil)
    cg.setShadow(offset: .zero, blur: 0, color: nil)
    cg.setAlpha(1)
    alpha = 1
  }
  if hasFill {
    let rule: CGPathFillRule = (fillRule ?? st.fillRule) == .evenodd ? .evenOdd : .winding
    paint(cg, fillP, alpha: alpha * fillOpacity, bbox: path.boundingBoxOfPath) {
      cg.addPath(path)
      return rule
    }
  }
  if hasStroke {
    cg.setLineWidth(sw)
    switch strokeLinecap ?? st.strokeLinecap {
    case .butt: cg.setLineCap(.butt)
    case .round: cg.setLineCap(.round)
    case .square: cg.setLineCap(.square)
    }
    switch strokeLinejoin ?? st.strokeLinejoin {
    case .miter: cg.setLineJoin(.miter)
    case .round: cg.setLineJoin(.round)
    case .bevel: cg.setLineJoin(.bevel)
    }
    cg.setMiterLimit(4)
    if var dash = strokeDasharray ?? st.strokeDasharray, dash.contains(where: { $0 > 0 }), !dash.contains(where: { $0 < 0 }) {
      if dash.count % 2 == 1 { dash += dash }
      // CoreGraphics の破線は、ずらし ÷ 周期 と 線の長さ ÷ 周期 に比例して時間がかかる (stroke-dashoffset="1e15" などで描画が終わらなくなる)。
      // ずらしは周期の中に畳み (見た目は同じ)、線に対して周期が極端に短い・値が有限でない破線は実線で描く
      let period = dash.reduce(0, +)
      let offset = strokeDashoffset ?? st.strokeDashoffset
      let box = path.boundingBoxOfPath
      let reach = Double(max(box.width, box.height))
      if period.isFinite, period > 0, offset.isFinite, reach.isFinite, reach / period <= 100_000 {
        cg.setLineDash(phase: CGFloat(offset.truncatingRemainder(dividingBy: period)), lengths: dash.map { CGFloat($0) })
      }
    }
    if case .linear = strokeP {
      cg.addPath(path)
      cg.replacePathWithStrokedPath()
      let outline = cg.path ?? path
      paint(cg, strokeP, alpha: alpha * strokeOpacity, bbox: path.boundingBoxOfPath) {
        cg.addPath(outline)
        return .winding
      }
    } else if let col = strokeP.rgba {
      cg.setStrokeColor(RGBA(col.r, col.g, col.b, col.a * alpha * strokeOpacity).cgColor)
      cg.addPath(path)
      cg.strokePath()
    }
  }
  if layered { cg.endTransparencyLayer() }
}

/// 塗る (単色はそのまま、グラデーションは形で切り抜いて描く)。addPath はパスを足して塗りの規則を返す
func paint(_ cg: CGContext, _ p: Paint, alpha: Double, bbox: CGRect, addPath: () -> CGPathFillRule) {
  switch p {
  case .none: return
  case let .color(col):
    cg.setFillColor(RGBA(col.r, col.g, col.b, col.a * alpha).cgColor)
    let rule = addPath()
    cg.fillPath(using: rule)
  case let .linear(gr):
    cg.saveGState()
    let rule = addPath()
    cg.clip(using: rule)
    let colors = gr.stops.map { RGBA($0.color.r, $0.color.g, $0.color.b, $0.color.a * alpha).cgColor } as CFArray
    // 位置は 0〜1 に収め、前の位置より手前なら前の位置にそろえる (SVG と同じ。CGGradient は昇順でないと形が決まらない)
    var locs: [CGFloat] = []
    for st in gr.stops { locs.append(max(locs.last ?? 0, CGFloat(min(1, max(0, st.offset))))) }
    if let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: locs) {
      let s: CGPoint, e: CGPoint
      if !gr.transform.isIdentity {
        // gradientTransform があるときは、グラデーションの座標 (外接矩形なら 0〜1) を座標系ごと図形の座標に合わせる
        if gr.units == .objectBoundingBox {
          cg.concatenate(CGAffineTransform(a: bbox.width, b: 0, c: 0, d: bbox.height, tx: bbox.minX, ty: bbox.minY))
        }
        cg.concatenate(gr.transform)
        s = CGPoint(x: gr.x1, y: gr.y1)
        e = CGPoint(x: gr.x2, y: gr.y2)
      } else if gr.units == .objectBoundingBox {
        s = CGPoint(x: bbox.minX + gr.x1 * bbox.width, y: bbox.minY + gr.y1 * bbox.height)
        e = CGPoint(x: bbox.minX + gr.x2 * bbox.width, y: bbox.minY + gr.y2 * bbox.height)
      } else {
        s = CGPoint(x: gr.x1, y: gr.y1)
        e = CGPoint(x: gr.x2, y: gr.y2)
      }
      cg.drawLinearGradient(grad, start: s, end: e, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
    cg.restoreGState()
  }
}

/// SVG の <path d="…">
public func path(
  _ d: String,
  fill: Paint? = nil, stroke: Paint? = nil, strokeWidth: Double? = nil,
  strokeLinecap: LineCap? = nil, strokeLinejoin: LineJoin? = nil,
  strokeDasharray: [Double]? = nil, strokeDashoffset: Double? = nil,
  opacity: Double = 1, fillOpacity: Double = 1, strokeOpacity: Double = 1,
  fillRule: FillRule? = nil, transform: [Tf] = [], filter: Filter? = nil
) {
  drawShape(SVGPath.parse(d), fill: fill, stroke: stroke, strokeWidth: strokeWidth, strokeLinecap: strokeLinecap, strokeLinejoin: strokeLinejoin,
            strokeDasharray: strokeDasharray, strokeDashoffset: strokeDashoffset, opacity: opacity, fillOpacity: fillOpacity,
            strokeOpacity: strokeOpacity, fillRule: fillRule, transform: transform, filter: filter)
}

/// CGPath をそのまま描く
public func path(
  cgPath: CGPath,
  fill: Paint? = nil, stroke: Paint? = nil, strokeWidth: Double? = nil,
  strokeLinecap: LineCap? = nil, strokeLinejoin: LineJoin? = nil,
  strokeDasharray: [Double]? = nil, strokeDashoffset: Double? = nil,
  opacity: Double = 1, fillOpacity: Double = 1, strokeOpacity: Double = 1,
  fillRule: FillRule? = nil, transform: [Tf] = [], filter: Filter? = nil
) {
  drawShape(cgPath, fill: fill, stroke: stroke, strokeWidth: strokeWidth, strokeLinecap: strokeLinecap, strokeLinejoin: strokeLinejoin,
            strokeDasharray: strokeDasharray, strokeDashoffset: strokeDashoffset, opacity: opacity, fillOpacity: fillOpacity,
            strokeOpacity: strokeOpacity, fillRule: fillRule, transform: transform, filter: filter)
}

/// SVG の <rect>。rx で角を丸める (ry を省くと rx と同じ)
public func rect(
  x: Double = 0, y: Double = 0, width: Double, height: Double, rx: Double = 0, ry: Double? = nil,
  fill: Paint? = nil, stroke: Paint? = nil, strokeWidth: Double? = nil,
  strokeLinecap: LineCap? = nil, strokeLinejoin: LineJoin? = nil,
  strokeDasharray: [Double]? = nil, strokeDashoffset: Double? = nil,
  opacity: Double = 1, fillOpacity: Double = 1, strokeOpacity: Double = 1,
  transform: [Tf] = [], filter: Filter? = nil
) {
  guard width > 0, height > 0 else { return }
  drawShape(roundedRectPath(x, y, width, height, rx, ry ?? rx), fill: fill, stroke: stroke, strokeWidth: strokeWidth, strokeLinecap: strokeLinecap,
            strokeLinejoin: strokeLinejoin, strokeDasharray: strokeDasharray, strokeDashoffset: strokeDashoffset, opacity: opacity,
            fillOpacity: fillOpacity, strokeOpacity: strokeOpacity, fillRule: nil, transform: transform, filter: filter)
}

/// SVG の <circle>
public func circle(
  cx: Double = 0, cy: Double = 0, r: Double,
  fill: Paint? = nil, stroke: Paint? = nil, strokeWidth: Double? = nil,
  strokeLinecap: LineCap? = nil, strokeLinejoin: LineJoin? = nil,
  strokeDasharray: [Double]? = nil, strokeDashoffset: Double? = nil,
  opacity: Double = 1, fillOpacity: Double = 1, strokeOpacity: Double = 1,
  transform: [Tf] = [], filter: Filter? = nil
) {
  guard r > 0 else { return }
  // SVG の円は 3 時の位置から時計回りに描く (破線の始まりを合わせる)
  let p = CGMutablePath()
  p.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
  p.closeSubpath()
  drawShape(p, fill: fill, stroke: stroke, strokeWidth: strokeWidth, strokeLinecap: strokeLinecap, strokeLinejoin: strokeLinejoin,
            strokeDasharray: strokeDasharray, strokeDashoffset: strokeDashoffset, opacity: opacity, fillOpacity: fillOpacity,
            strokeOpacity: strokeOpacity, fillRule: nil, transform: transform, filter: filter)
}

/// SVG の <ellipse>
public func ellipse(
  cx: Double = 0, cy: Double = 0, rx: Double, ry: Double,
  fill: Paint? = nil, stroke: Paint? = nil, strokeWidth: Double? = nil,
  strokeLinecap: LineCap? = nil, strokeLinejoin: LineJoin? = nil,
  strokeDasharray: [Double]? = nil, strokeDashoffset: Double? = nil,
  opacity: Double = 1, fillOpacity: Double = 1, strokeOpacity: Double = 1,
  transform: [Tf] = [], filter: Filter? = nil
) {
  guard rx > 0, ry > 0 else { return }
  let p = CGPath(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry), transform: nil)
  drawShape(p, fill: fill, stroke: stroke, strokeWidth: strokeWidth, strokeLinecap: strokeLinecap, strokeLinejoin: strokeLinejoin,
            strokeDasharray: strokeDasharray, strokeDashoffset: strokeDashoffset, opacity: opacity, fillOpacity: fillOpacity,
            strokeOpacity: strokeOpacity, fillRule: nil, transform: transform, filter: filter)
}

/// SVG の <line> (塗りは無く、線だけ)
public func line(
  x1: Double = 0, y1: Double = 0, x2: Double = 0, y2: Double = 0,
  stroke: Paint? = nil, strokeWidth: Double? = nil,
  strokeLinecap: LineCap? = nil, strokeLinejoin: LineJoin? = nil,
  strokeDasharray: [Double]? = nil, strokeDashoffset: Double? = nil,
  opacity: Double = 1, strokeOpacity: Double = 1,
  transform: [Tf] = [], filter: Filter? = nil
) {
  let p = CGMutablePath()
  p.move(to: CGPoint(x: x1, y: y1))
  p.addLine(to: CGPoint(x: x2, y: y2))
  drawShape(p, fill: nil, stroke: stroke, strokeWidth: strokeWidth, strokeLinecap: strokeLinecap, strokeLinejoin: strokeLinejoin,
            strokeDasharray: strokeDasharray, strokeDashoffset: strokeDashoffset, opacity: opacity, fillOpacity: 1,
            strokeOpacity: strokeOpacity, fillRule: nil, transform: transform, filter: filter, canFill: false)
}

/// SVG の <polygon> (points は "x,y x,y …" か点の配列)
public func polygon(
  points: [Pt],
  fill: Paint? = nil, stroke: Paint? = nil, strokeWidth: Double? = nil,
  strokeLinecap: LineCap? = nil, strokeLinejoin: LineJoin? = nil,
  strokeDasharray: [Double]? = nil, strokeDashoffset: Double? = nil,
  opacity: Double = 1, fillOpacity: Double = 1, strokeOpacity: Double = 1,
  fillRule: FillRule? = nil, transform: [Tf] = [], filter: Filter? = nil
) {
  guard let first = points.first else { return }
  let p = CGMutablePath()
  p.move(to: CGPoint(x: first.x, y: first.y))
  for q in points.dropFirst() { p.addLine(to: CGPoint(x: q.x, y: q.y)) }
  p.closeSubpath()
  drawShape(p, fill: fill, stroke: stroke, strokeWidth: strokeWidth, strokeLinecap: strokeLinecap, strokeLinejoin: strokeLinejoin,
            strokeDasharray: strokeDasharray, strokeDashoffset: strokeDashoffset, opacity: opacity, fillOpacity: fillOpacity,
            strokeOpacity: strokeOpacity, fillRule: fillRule, transform: transform, filter: filter)
}

public func polygon(
  points: String,
  fill: Paint? = nil, stroke: Paint? = nil, strokeWidth: Double? = nil,
  strokeLinecap: LineCap? = nil, strokeLinejoin: LineJoin? = nil,
  strokeDasharray: [Double]? = nil, strokeDashoffset: Double? = nil,
  opacity: Double = 1, fillOpacity: Double = 1, strokeOpacity: Double = 1,
  fillRule: FillRule? = nil, transform: [Tf] = [], filter: Filter? = nil
) {
  let nums = points.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" }).compactMap { Double($0) }
  let pts = stride(from: 0, to: nums.count - 1, by: 2).map { Pt(nums[$0], nums[$0 + 1]) }
  polygon(points: pts, fill: fill, stroke: stroke, strokeWidth: strokeWidth, strokeLinecap: strokeLinecap, strokeLinejoin: strokeLinejoin,
          strokeDasharray: strokeDasharray, strokeDashoffset: strokeDashoffset, opacity: opacity, fillOpacity: fillOpacity,
          strokeOpacity: strokeOpacity, fillRule: fillRule, transform: transform, filter: filter)
}

/// SVG の <polyline> (閉じない折れ線)
public func polyline(
  points: [Pt],
  fill: Paint? = nil, stroke: Paint? = nil, strokeWidth: Double? = nil,
  strokeLinecap: LineCap? = nil, strokeLinejoin: LineJoin? = nil,
  strokeDasharray: [Double]? = nil, strokeDashoffset: Double? = nil,
  opacity: Double = 1, transform: [Tf] = [], filter: Filter? = nil
) {
  guard let first = points.first else { return }
  let p = CGMutablePath()
  p.move(to: CGPoint(x: first.x, y: first.y))
  for q in points.dropFirst() { p.addLine(to: CGPoint(x: q.x, y: q.y)) }
  drawShape(p, fill: fill, stroke: stroke, strokeWidth: strokeWidth, strokeLinecap: strokeLinecap, strokeLinejoin: strokeLinejoin,
            strokeDasharray: strokeDasharray, strokeDashoffset: strokeDashoffset, opacity: opacity, fillOpacity: 1,
            strokeOpacity: 1, fillRule: nil, transform: transform, filter: filter)
}

/// 画面全体を塗る (背景)
public func fillBackground(_ p: Paint) {
  let c = RenderContext.current
  rect(width: c.config.width, height: c.config.height, fill: p, stroke: Paint.none)
}

// ---------- パスの文字列を作る補助 ----------

/// 数値を SVG のパス用の短い文字列にする (1.0 → "1"、1e-7 → "0")
public func fmt(_ v: Double) -> String {
  if !v.isFinite { return "0" }
  let r = (v * 10000).rounded() / 10000
  if r == r.rounded() && abs(r) < 1e15 { return String(Int(r)) }
  return String(r)
}
