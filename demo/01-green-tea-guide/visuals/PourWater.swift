// STEP 3: 湯のみのお湯を急須に移し (2 杯)、ふたをして 1 分タイマー
import JGVKit

private let Y = GUIDE.counterY
private let POT = Pt(930, Y)
private let CUPS: [Double] = [1150, 1300]

func PourWater(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let start = n.at(0, 0.1)
  let end = n.endOf(0) + 6
  let half = (end - start) / 2
  // 湯のみ i を持ち上げ → 傾けて注ぐ → 戻す
  struct Cup { var pos: Pt; var tilt: Double; var fill: Double; var active: Bool; var pouring: Bool }
  let cupState = { (i: Int) -> Cup in
    let s = start + half * Double(i)
    let up = interpolate(n.frame, [s, s + half * 0.25], [0, 1], .clamp)
    let down = interpolate(n.frame, [s + half * 0.8, s + half], [0, 1], .clamp)
    let tilt = -80 * interpolate(n.frame, [s + half * 0.2, s + half * 0.35], [0, 1], .clamp) * (1 - down)
    let fill = 0.75 * (1 - interpolate(n.frame, [s + half * 0.35, s + half * 0.8], [0, 1], .clamp))
    let rest = Pt(CUPS[i], Y)
    let pour = Pt(POT.x + 190, Y - 225)
    let pos = mix(rest, pour, up * (1 - down))
    return Cup(pos: pos, tilt: tilt, fill: fill, active: n.frame >= s && n.frame < s + half, pouring: tilt < -60)
  }
  let cups = [cupState(0), cupState(1)]
  let holding = cups.first { $0.active }
  let rim = holding.map { place($0.pos.x, $0.pos.y, 0.9, $0.tilt, Pt(-66, -128)) }
  let grip = holding.map { place($0.pos.x, $0.pos.y, 0.9, $0.tilt, Pt(-YUNOMI_PARTS.grip.x, YUNOMI_PARTS.grip.y)) }
  let reach = interpolate(n.frame, [start - 10, start], [0, 1], .clamp) * (1 - interpolate(n.frame, [end, end + 12], [0, 1], .clamp))
  let handR = grip.map { mix(PRESENTER.gestureR, $0, reach) } ?? mix(PRESENTER.gestureR, PRESENTER.restR, n.ease(1, 0.8))

  // 2 行目: ふた → タイマー
  let lidAt = n.atPhrase(1, 0, 0.2)
  let lid = 1 - interpolate(n.frame, [lidAt, lidAt + 12], [0, 1], .clamp)
  let timerAt = n.atPhrase(1, 1, -0.1)
  let tp = interpolate(n.frame, [timerAt, n.durationInFrames - 12], [0, 1], .clamp)
  let timer = Pt(POT.x, Y - 400)

  Stage {
    Shadow(x: POT.x, w: 240)
    Teapot(x: POT.x, y: POT.y, scale: 1, lidOpen: lid)
    if lid < 0.1 { Steam(x: POT.x - 10, y: Y - 160, count: 3, height: 130, opacity: 0.4) }
    for (i, c) in cups.enumerated() {
      Shadow(x: CUPS[i], w: 140 * (1 - min(1, abs(c.pos.y - Y) / 150) * 0.6))
      Yunomi(x: c.pos.x, y: c.pos.y, scale: 0.9, angle: c.tilt, fill: c.tilt < -20 ? 0 : c.fill)
    }
    if let holding, let rim { Stream(from: rim, to: Pt(POT.x + 5, Y - 130), active: holding.pouring) }
    Presenter(handR: handR)
    // 1 分タイマー
    g(opacity: interpolate(n.frame, [timerAt - 6, timerAt + 4], [0, 1], .clamp)) {
      circle(cx: timer.x, cy: timer.y, r: 92, fill: palette.cream, stroke: palette.ink, strokeWidth: 5)
      Draw(d: circlePath(timer.x, timer.y, 70), progress: 1, color: "#e3dccb", width: 12)
      if tp > 0 { Draw(d: arcPath(timer.x, timer.y, 70, -90, -90 + 359.9 * tp), progress: 1, color: palette.primary, width: 12) }
      CountUp(at: timerAt, to: 60, durSec: max(0.5, (n.durationInFrames - 12 - timerAt) / n.fps), suffix: "秒", x: timer.x, y: timer.y, size: 40, weight: 900, color: palette.ink)
    }
    Callout(x: timer.x + 330, y: timer.y, text: "待ち時間は短縮しています", at: timerAt + 10)
  }
}
