// ネジを順に締める演出 (ドライバーがネジからネジへ移動し、締めたネジが残る)
import Foundation
import JGVKit

func Screwing(points: [Pt], from: Double, to: Double) {
  let n = useNarration()
  let count = Double(points.count)
  let span = (to - from) / count
  let idx = min(count - 1, max(0, floor((n.frame - from) / span)))
  let local = (n.frame - from - idx * span) / span
  let active = n.frame >= from && n.frame < to
  let tip = points[Int(idx)]
  g {
    for (i, p) in points.enumerated() {
      let di = Double(i)
      let driven = interpolate(n.frame, [from + span * (di + 0.2), from + span * (di + 0.8)], [0, 1], .clamp)
      if driven > 0 { Screw(x: p.x + 16 * (1 - driven), y: p.y, angle: 180, scale: 1.1) }
    }
    if active {
      g {
        Screwdriver(tip: Pt(tip.x + 4, tip.y), angle: -25, spin: local > 0.2 && local < 0.8)
        RotateArrow(x: tip.x + 30, y: tip.y - 70, r: 26, spin: true)
      }
    }
  }
}
