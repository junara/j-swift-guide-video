// 全画面アニメーション用の部品。座標は動画のピクセル (例: 1920x1080) そのまま。
// すべてフレーム番号から決定的に計算する
import Foundation

// ---------- path helpers ----------

public func circlePath(_ cx: Double, _ cy: Double, _ r: Double) -> String {
  "M \(cx - r) \(cy) a \(r) \(r) 0 1 0 \(2 * r) 0 a \(r) \(r) 0 1 0 \(-2 * r) 0"
}

public func rectPath(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double = 0) -> String {
  if r <= 0 { return "M \(x) \(y) h \(w) v \(h) h \(-w) Z" }
  return "M \(x + r) \(y) h \(w - 2 * r) a \(r) \(r) 0 0 1 \(r) \(r) v \(h - 2 * r) a \(r) \(r) 0 0 1 \(-r) \(r) h \(-(w - 2 * r)) a \(r) \(r) 0 0 1 \(-r) \(-r) v \(-(h - 2 * r)) a \(r) \(r) 0 0 1 \(r) \(-r) Z"
}

/// 角度 (度, 0 = 右, 時計回り) の円弧
public func arcPath(_ cx: Double, _ cy: Double, _ r: Double, _ fromDeg: Double, _ toDeg: Double) -> String {
  let rad = { (d: Double) in d * Double.pi / 180 }
  let sx = cx + r * cos(rad(fromDeg))
  let sy = cy + r * sin(rad(fromDeg))
  let ex = cx + r * cos(rad(toDeg))
  let ey = cy + r * sin(rad(toDeg))
  let large = abs(toDeg - fromDeg) > 180 ? 1 : 0
  let sweep = toDeg > fromDeg ? 1 : 0
  return "M \(sx) \(sy) A \(r) \(r) 0 \(large) \(sweep) \(ex) \(ey)"
}

// ---------- containers ----------

/// 工程の visual の描画範囲 (全画面)。中身をそのまま描く (影・グローは filter: .shadow / .glow で付ける)
public func Stage(_ content: () -> Void) { content() }

/// at フレームで弾むように拡大して登場 (x, y が拡大の中心)
public func Pop(at: Double, x: Double = 0, y: Double = 0, scale: Double = 1, _ content: () -> Void) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let s = spring(frame: frame - at, fps: fps, damping: 12, stiffness: 140)
  g(opacity: interpolate(s, [0, 0.3], [0, 1], .clamp), transform: [.translate(x, y), .scale(s * scale)], content)
}

// ---------- drawing ----------

/// パスを progress (0→1) に合わせて線で描く。fill を指定すると描画に合わせて塗りもフェードイン
public func Draw(d: String, progress: Double, color: Paint? = nil, width: Double = 6, fill: Paint? = nil, fillOpacity: Double = 1, glow: Bool = false, opacity: Double = 1) {
  let accent = useTheme().accent
  let p = clamp01(progress)
  let ev = evolvePath(p, d)
  g(opacity: p == 0 ? 0 : opacity) {
    if let fill { path(d, fill: fill, stroke: Paint.none, opacity: fillOpacity * interpolate(p, [0.5, 1], [0, 1], .clamp)) }
    path(d, fill: Paint.none, stroke: color ?? accent, strokeWidth: width, strokeLinecap: .round, strokeLinejoin: .round,
         strokeDasharray: ev.dash, strokeDashoffset: ev.offset, filter: glow ? .glow : nil)
  }
}

/// 組み込みアイコン (ICONS) を中心 (x, y)・大きさ size で線描き
public func Icon(name: String, x: Double, y: Double, size: Double, progress: Double = 1, color: Paint? = nil, strokeWidth: Double = 1.8, glow: Bool = false) {
  let accent = useTheme().accent
  guard let paths = ICONS[name] else { return }
  let n = Double(paths.count)
  g(transform: [.translate(x - size / 2, y - size / 2), .scale(size / 24)], filter: glow ? .glow : nil) {
    for (i, d) in paths.enumerated() {
      let p = clamp01(progress * (n * 0.5 + 0.5) - Double(i) * 0.5)
      let ev = evolvePath(p, d)
      path(d, fill: Paint.none, stroke: color ?? accent, strokeWidth: strokeWidth, strokeLinecap: .round, strokeLinejoin: .round,
           strokeDasharray: ev.dash, strokeDashoffset: ev.offset, opacity: p == 0 ? 0 : 1)
    }
  }
}

/// パスに沿って流れる点 (データの流れ・接続の表現)
public func FlowDots(d: String, count: Int = 4, speed: Double = 0.4, r: Double = 7, color: Paint? = nil, opacity: Double = 1) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let accent = useTheme().accent
  let m = PathMeasure(d)
  g(opacity: opacity) {
    for k in 0 ..< count {
      let t = jsMod((frame / fps) * speed + Double(k) / Double(count), 1)
      guard let pt = m.point(at: t * m.length) else { continue }
      let fade = sin(t * Double.pi)
      circle(cx: pt.x, cy: pt.y, r: r, fill: color ?? accent, opacity: fade, filter: .glow)
    }
  }
}

/// 広がる波紋 (注目・発話中の表現)。active=false で止まる
public func Pulse(x: Double, y: Double, r: Double, color: Paint? = nil, period: Double = 1.6, count: Int = 2, active: Bool = true, width: Double = 4) {
  guard active else { return }
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let accent = useTheme().accent
  for k in 0 ..< count {
    let t = jsMod(jsMod(frame / fps / period + Double(k) / Double(count), 1) + 1, 1)
    circle(cx: x, cy: y, r: r * (1 + t * 0.8), fill: Paint.none, stroke: color ?? accent, strokeWidth: width, opacity: (1 - t) * 0.6)
  }
}

/// at フレームで放射状に飛び散る線 (完了・強調の演出)
public func Burst(at: Double, x: Double, y: Double, r: Double = 120, count: Int = 12, color: Paint? = nil, width: Double = 5) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let accent = useTheme().accent
  let t = interpolate(frame - at, [0, fps * 0.7], [0, 1], .clamp)
  if t <= 0 || t >= 1 { return }
  g(opacity: 1 - t) {
    for i in 0 ..< count {
      let a = (Double(i) / Double(count)) * Double.pi * 2
      let r0 = r * (0.5 + t * 0.6)
      let r1 = r * (0.7 + t * 0.8)
      line(x1: x + cos(a) * r0, y1: y + sin(a) * r0, x2: x + cos(a) * r1, y2: y + sin(a) * r1, stroke: color ?? accent, strokeWidth: width, strokeLinecap: .round)
    }
  }
}

// ---------- text ----------

/// 文字列のおおよその表示幅 (全角 = size、ラテン・キリル・ギリシャ文字 = size * 0.56)。ラベルの座布団の幅などに使う
public func textWidth(_ text: String, _ size: Double) -> Double {
  text.unicodeScalars.reduce(0) { w, ch in
    let v = ch.value
    let narrow = v <= 0x052F || (v >= 0x1E00 && v <= 0x1EFF)
    return w + (narrow ? size * 0.56 : size)
  }
}

/// テキスト (\n で複数行)。y は 1 行目の中心
public func T(_ content: String, x: Double, y: Double, size: Double = 48, weight: Double = 700, color: Paint? = nil, anchor: TextAnchor = .middle, opacity: Double = 1, family: String? = nil) {
  let theme = useTheme()
  let lines = content.components(separatedBy: "\n")
  for (i, l) in lines.enumerated() {
    text(l, x: x, y: y + Double(i) * size * 1.3, fontSize: size, fontWeight: weight, fontFamily: family ?? theme.fontFamily,
         fill: color ?? theme.textColor, textAnchor: anchor, dominantBaseline: .central, opacity: opacity)
  }
}

/// at フレームから durSec 秒で from→to にカウントアップ
public func CountUp(at: Double, from: Double = 0, to: Double, durSec: Double = 1.2, decimals: Int = 0, prefix: String = "", suffix: String = "",
                    x: Double, y: Double, size: Double = 48, weight: Double = 700, color: Paint? = nil, anchor: TextAnchor = .middle, opacity: Double = 1, family: String? = nil) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let p = interpolate(frame, [at, at + durSec * fps], [0, 1], .clamp)
  let eased = 1 - pow(1 - p, 3)
  let v = from + (to - from) * eased
  T("\(prefix)\(String(format: "%.\(decimals)f", v))\(suffix)", x: x, y: y, size: size, weight: weight, color: color, anchor: anchor, opacity: opacity, family: family)
}

/// シーンに表示する組み込みアイコン (viewBox 0 0 24 24 / 線のみ)。各パスは順番に「線を描く」アニメーションで表示される
public let ICONS: [String: [String]] = [
  "shield": ["M12 2l8 3v6c0 5-3.5 9-8 11c-4.5-2-8-6-8-11V5z", "M8.5 12l2.5 2.5L15.5 10"],
  "warning": ["M12 3L2 20h20z", "M12 9v5", "M12 17h.01"],
  "sun": [
    "M12 7a5 5 0 1 0 0 10a5 5 0 1 0 0-10",
    "M12 1v2", "M12 21v2", "M1 12h2", "M21 12h2",
    "M4.2 4.2l1.4 1.4", "M18.4 18.4l1.4 1.4", "M4.2 19.8l1.4-1.4", "M18.4 5.6l1.4-1.4",
  ],
  "water": ["M12 2C8 7 5 10.5 5 14a7 7 0 0 0 14 0c0-3.5-3-7-7-12z", "M8.5 14.5a3.5 3.5 0 0 0 3.5 3.5"],
  "book": ["M4 4h7a2 2 0 0 1 2 2v14a2 2 0 0 0-2-2H4z", "M20 4h-7a2 2 0 0 0-2 2v14a2 2 0 0 1 2-2h7z"],
]
