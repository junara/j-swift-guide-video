// 工程の visual で繰り返し書かれていた小さな演出 (上から落ちて置かれる・水面の波紋・禁止マーク・円弧タイマー)
// at はシーン先頭からのフレーム (n.at() / n.atPhrase() の戻り値をそのまま渡す)
import Foundation

/// at から、道具が上から落ちてきて置かれる (影も一緒に濃くなる)。
/// content は落下中の「底の y 座標」を受け取って道具を描く: DropIn(at: t, x: x) { y in Mug(x: x, y: y) }
/// y は置いたときの底 (既定はカウンター天板)、height は落ち始めの高さ (px)
public func DropIn(at: Double, x: Double, y: Double? = nil, shadowW: Double = 100, height: Double = 320, _ content: (Double) -> Void) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let layout = useGuide().layout
  let ground = y ?? layout.counterY
  let u = dropAt(frame, fps, at)
  if u <= 0.001 { return }
  g(opacity: u) { Shadow(x: x, y: ground + 4, w: shadowW) }
  g(opacity: min(1, u * 4)) { content(ground - height * (1 - u)) }
}

/// 水面の揺れと、中心から広がる波紋 (原点 = 水面の中心、幅 w)。
/// at を渡すと、その時刻に大きく揺れてから小さく揺れ続ける (物を入れた・置いた瞬間)。省略すると小さく揺れ続ける
public func Ripple(x: Double, y: Double, w: Double, at: Double? = nil, color: Paint = "#ffffff") {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let t = frame / fps
  if let at, frame < at { return }
  let since = at.map { (frame - $0) / fps } ?? Double.infinity
  let amp = 0.6 + 3 * exp(-since * 1.5)
  let ring = jsMod(t * 0.8, 1)
  let h = w / 2
  g(fill: Paint.none, stroke: color, strokeLinecap: .round) {
    path("M \(x - h * 0.85) \(y + sin(t * 7) * amp) Q \(x - h * 0.3) \(y - 4 * amp * sin(t * 7 + 1)) \(x + h * 0.2) \(y + sin(t * 7 + 2) * amp) T \(x + h * 0.8) \(y)",
         strokeWidth: 3, opacity: 0.8)
    ellipse(cx: x, cy: y, rx: h * (0.2 + ring * 0.8), ry: h * (0.2 + ring * 0.8) * 0.15, strokeWidth: 2, opacity: 0.7 * (1 - ring))
  }
}

/// 禁止マーク (赤い円と斜線、原点 = 中心)。at を渡すとその時刻に弾んで登場する
public func NoSign(x: Double, y: Double, r: Double = 26, at: Double? = nil, color: Paint = "#d9534f") {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let s = at.map { spring(frame: frame - $0, fps: fps, damping: 12, stiffness: 160) } ?? 1
  if s <= 0.001 { return }
  let d = r * 0.7
  g(transform: [.translate(x, y), .scale(s)]) {
    circle(r: r, fill: "#ffffff", stroke: color, strokeWidth: r * 0.23)
    path("M \(-d) \(d) L \(d) \(-d)", stroke: color, strokeWidth: r * 0.23, strokeLinecap: .round)
  }
}

/// 円弧のタイマー (原点 = 中心)。progress (0〜1) で 12 時の位置から時計回りに弧が伸びる。
/// label は中央の文字 (「5分」など)。待ち時間は interpolate(n.frame, [始まり, 終わり], [0, 1]) で数秒に縮めて回す
public func ArcTimer(x: Double, y: Double, r: Double = 60, progress: Double, label: String = "", size: Double = 40, color: Paint? = nil) {
  let palette = useGuide().palette
  let p = min(1, max(0, progress))
  LayoutProbe.group(.mark, "タイマー", rect: CGRect(x: x - r - 22, y: y - r - 22, width: 2 * r + 44, height: 2 * r + 44)) {
    circle(cx: x, cy: y, r: r + 20, fill: "#ffffff", stroke: palette.ink, strokeWidth: 5)
    Draw(d: circlePath(x, y, r), progress: 1, color: "#e3dccb", width: 12)
    if p > 0 { Draw(d: arcPath(x, y, r, -90, -90 + 359.9 * p), progress: 1, color: color ?? palette.primary, width: 12) }
    if !label.isEmpty { T(label, x: x, y: y, size: size, weight: 900, color: palette.ink) }
  }
}
