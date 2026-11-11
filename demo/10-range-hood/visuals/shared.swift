// 全シーン共通の配置 (換気扇・コンロ・コンセント・新聞紙) と、手袋をはめた人物、羽根の回転、物や手を順番に動かす track()
import JGVKit

let HOOD = Pt(1040, 470)
func hood(_ p: Pt) -> Pt { place(HOOD.x, HOOD.y, 1, 0, p) }
let COOK = Pt(1040, GUIDE.counterY)
let OUTLET = Pt(1420, 330)
let CORD_FROM = hood(HOOD_PARTS.cord)
let PLUG_IN = Pt(OUTLET.x, OUTLET.y + 10)
let PLUG_OUT = Pt(OUTLET.x - 30, OUTLET.y + 110)
let BUTTON = hood(HOOD_PARTS.button)
/// 天板に敷いた新聞紙と、その上に置いたフィルター
let NEWS = (x: 1470.0, y: GUIDE.counterY, w: 340.0)
let REST = (x: NEWS.x, y: GUIDE.counterY - 26, scale: 0.75)
/// 拡大カードでの換気扇
let HOOD_BIG = (x: 1120.0, y: 520.0, scale: 1.25)
func hoodBig(_ p: Pt) -> Pt { place(HOOD_BIG.x, HOOD_BIG.y, HOOD_BIG.scale, 0, p) }
/// 拡大カードのシンク・蛇口・フィルター
let SINK = Pt(1120, 330)
let TAP = Pt(1000, 380)
let F = (x: 1150.0, y: 560.0, scale: 1.1)
/// 拡大カードの人物の右手 (カードの縁を指す) と下ろした位置
let POINT = Pt(615, 515)
let LOW = Pt(440, 680)

/// 人物。gloves (0〜1) でゴム手袋をはめた手にする
func Worker(handL: Pt = PRESENTER.restL, handR: Pt = PRESENTER.restR, gloves: Double = 0) {
  Presenter(handL: handL, handR: handR)
  GloveHand(x: handL.x, y: handL.y, on: gloves)
  GloveHand(x: handR.x, y: handR.y, on: gloves)
}

/// 羽根の角度 (度)。speed(f) = そのフレームの回転速度 (度/フレーム) を 0 から積算する
func spinAngle(_ frame: Double, _ speed: (Double) -> Double) -> Double {
  var a = 0.0
  var f = 0.0
  while f < frame {
    a += speed(f)
    f += 1
  }
  return jsMod(a, 360)
}

/// 換気扇に吸い込まれる空気の流れ (on: 0〜1)
func Suction(x: Double, y: Double, from: Double = 170, on: Double = 1, color: Paint = "#9fb9c2") {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  if on <= 0.01 { return }
  let t = frame / fps
  g(fill: "none", stroke: color, strokeWidth: 6, strokeLinecap: .round) {
    for i in 0..<5 {
      let k = jsMod(t * 0.7 + random("su\(i)"), 1)
      let sx = x + Double(i - 2) * 110
      let px = sx + (x - sx) * k * 0.6
      let py = y + from - k * from
      path("M \(px) \(py + 40) q 14 -10 0 -20 q -14 -10 0 -20", opacity: on * sin(k * Double.pi) * 0.9)
    }
  }
}

private func ease(_ u: Double) -> Double { u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2 }

struct Move {
  var at: Double
  var to: Pt
  var dur: Double? = nil
  var lift: Double? = nil
}
/// start から moves を順に移動した現在位置 (at はフレーム、dur は秒、lift は弧の高さ)
func track(_ frame: Double, _ fps: Double, _ start: Pt, _ moves: [Move]) -> Pt {
  var cur = start
  for m in moves {
    let u = min(1, max(0, (frame - m.at) / ((m.dur ?? 0.6) * fps)))
    if u <= 0 { break }
    let e = ease(u)
    let p = Pt(cur.x + (m.to.x - cur.x) * e, cur.y + (m.to.y - cur.y) * e - sin(Double.pi * e) * (m.lift ?? 0))
    if u < 1 { return p }
    cur = m.to
  }
  return cur
}

/// 拭き掃除の手の動き: 範囲 (x0〜x1, y0〜y1) を u (0〜1) でジグザグに往復する
func zigzag(_ u: Double, _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ passes: Double = 3) -> Pt {
  let k = min(1, max(0, u)) * passes
  let row = min(passes - 1, floor(k))
  let s = k - row
  let dir: Double = Int(row) % 2 == 0 ? 1 : -1
  let x = dir > 0 ? x0 + (x1 - x0) * s : x1 - (x1 - x0) * s
  let y = y0 + ((y1 - y0) * (row + s * 0.5)) / max(1, passes - 0.5)
  return Pt(x, y)
}
