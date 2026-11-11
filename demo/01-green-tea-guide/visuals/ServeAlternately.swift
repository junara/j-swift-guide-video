// STEP 4: 拡大カードで、急須を 2 つの湯のみに 1→2→2→1 の順で少しずつ注ぎ分ける
import JGVKit

private let CUPS = [Pt(930, 720), Pt(1170, 720)]
private let ORDER = [0, 1, 1, 0]
private let ANGLE = -38.0
private let SCALE = 1.0

func ServeAlternately(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let start = n.at(0, 0.2)
  let end = n.endOf(1) - 6
  let seg = (end - start) / Double(ORDER.count)
  let idx = min(ORDER.count - 1, max(0, Int(((n.frame - start) / seg).rounded(.down))))
  let local = (n.frame - start - Double(idx) * seg) / seg
  let done = n.frame >= end
  let before = n.frame < start

  // 注ぐ位置: 注ぎ口が湯のみの上に来るよう急須の原点を逆算
  let spoutRel = place(0, 0, SCALE, ANGLE, TEAPOT_PARTS.spout)
  let potAt = { (c: Int) in Pt(CUPS[c].x + 10 - spoutRel.x, CUPS[c].y - 175 - spoutRel.y) }
  let prev = potAt(ORDER[max(0, idx - 1)])
  let cur = potAt(ORDER[idx])
  let move = idx == 0 ? 1 : interpolate(local, [0, 0.25], [0, 1], .clamp)
  let pos = before || done ? Pt(1400, 560) : mix(prev, cur, move)
  let tilt = before || done ? 0 : ANGLE * interpolate(local, [0.2, 0.35, 0.85, 1], [0, 1, 1, 0], .clamp)
  let pouring = !before && !done && local > 0.35 && local < 0.85
  let spout = place(pos.x, pos.y, SCALE, tilt, TEAPOT_PARTS.spout)
  let grip = place(pos.x, pos.y, SCALE, tilt, TEAPOT_PARTS.grip)

  // 各湯のみの量: 注いだ回数ぶん増える
  let fillOf = { (c: Int) -> Double in
    ORDER.enumerated().reduce(0.0) { acc, item in
      if item.element != c { return acc }
      let i = Double(item.offset)
      let p = interpolate(n.frame, [start + seg * (i + 0.35), start + seg * (i + 0.85)], [0, 1], .clamp)
      return acc + 0.35 * p
    }
  }

  Stage {
    Presenter(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, -0.3)))
    CloseUp(steps: [
      CloseUpStep("少しずつ注ぐ", at: n.atPhrase(0, 0, -0.2)),
      CloseUpStep("1→2→2→1 と交互に", at: n.atPhrase(0, 1, -0.2)),
      CloseUpStep("濃さが均等になる", at: n.at(1, -0.1)),
    ]) {
      for (i, c) in CUPS.enumerated() {
        Yunomi(x: c.x, y: c.y, scale: 1.25, fill: fillOf(i))
      }
      // 注いだ順番の番号
      for (i, c) in ORDER.enumerated() {
        Pop(at: start + seg * (Double(i) + 0.3), x: CUPS[c].x - 40 + (i >= 2 ? 80 : 0), y: CUPS[c].y + 0) {
          circle(r: 26, fill: palette.primary, stroke: palette.ink, strokeWidth: 4)
          T(String(i + 1), x: 0, y: 0, size: 28, weight: 900, color: "#fff")
        }
      }
      Stream(from: spout, to: Pt(CUPS[ORDER[idx]].x, CUPS[ORDER[idx]].y - 140), color: "#c3cf72", width: 12, active: pouring)
      Teapot(x: pos.x, y: pos.y, scale: SCALE, angle: tilt)
      SleeveArm(from: Pt(1640, 720), to: grip, bend: -0.15)
    }
  }
}
