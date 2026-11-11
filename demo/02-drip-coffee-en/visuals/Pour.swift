// Pour slowly: 2〜3 回に分けて注ぐ。注ぐたびにバッグの湯が増え、間で落ちきるのを待つ
import JGVKit

func Pour(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let top = Pt(BAG_ON_MUG.x, BAG_ON_MUG.y - 158 * BAG_SCALE - 10)
  let spoutAt = Pt(top.x + 30, top.y - 110)
  // 3 回の注ぎ (1 行目の 2 句目から 2 行目の終わりまで)
  let from = n.atPhrase(0, 1, -0.3)
  let to = n.endOf(1)
  let span = (to - from) / 3
  let rounds = [0.0, 1, 2].map { i in kettlePour(n.frame, from + span * i, from + span * (i + 0.62), spoutAt, 40) }
  let k = rounds.first { $0.reach > 0 } ?? rounds[0]
  let holding = rounds.contains { $0.reach > 0 }
  // 湯量: 注いでいる間に上がり、待つ間に下がる
  let water = [0.0, 1, 2].reduce(0.0) { acc, i in
    let up = interpolate(n.frame, [from + span * i + 14, from + span * (i + 0.55)], [0, 0.9], .clamp)
    let down = interpolate(n.frame, [from + span * (i + 0.62), from + span * (i + 1)], [0, 0.9], .clamp)
    return acc + up - down
  }
  let coffee = interpolate(n.frame, [from, to], [0, 1], .clamp)

  Stage {
    Shadow(x: MUG.x, w: 250)
    Mug(x: MUG.x, y: MUG.y, fill: coffee)
    DripBag(x: BAG_ON_MUG.x, y: BAG_ON_MUG.y, scale: BAG_SCALE, open: 1, hooks: 1, wet: 0.55 + coffee * 0.4, water: max(0.05, water))
    Stream(from: k.spout, to: top, color: "#bfe0ee", width: 12, active: holding && k.pouring)
    Steam(x: MUG.x, y: top.y - 10, count: 3, height: 130, opacity: 0.45)
    Shadow(x: KETTLE_REST.x, w: 220 * (1 - k.reach * 0.6))
    Kettle(x: k.pos.x, y: k.pos.y, scale: KETTLE_SCALE, angle: k.tilt)
    Presenter(handR: holding ? mix(PRESENTER.gestureR, k.handle, k.reach) : mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, -0.2)))
    // 注いだ回数
    for i in 0..<3 {
      let fi = Double(i)
      Pop(at: from + span * fi + 16, x: MUG.x - 230 + fi * 70, y: Y - 420) {
        circle(r: 28, fill: palette.primary, stroke: palette.ink, strokeWidth: 4)
        T(String(i + 1), x: 0, y: 0, size: 30, weight: 900, color: "#fff")
      }
    }
    Callout(x: MUG.x, y: Y - 330, text: n.t("pour.callout", "Pour in 2–3 rounds"), at: n.atPhrase(0, 1))
  }
}
