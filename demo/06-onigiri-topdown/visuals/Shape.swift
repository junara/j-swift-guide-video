// 三角に握る: ラップで包む → 両手で包み、回しながら三角に → ふんわり握るのがコツ
import Foundation
import JGVKit

func Shape(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let wrap = interpolate(n.frame, [n.atPhrase(0, 0, 0.1), n.atPhrase(0, 0, 0.9)], [0, 1], .clamp)
  let from = n.atPhrase(0, 1, -0.1)
  let tri = interpolate(n.frame, [from, n.endOf(0) + 10], [0, 1], .clamp)
  // 3 回に分けて 120° ずつ回しながら握る
  let turns = interpolate(n.frame, [from, n.endOf(0) + 10], [0, 3], .clamp)
  let rot = -90 + 120 * floor(turns) + (120 * max(0, jsMod(turns, 1) - 0.6)) / 0.4
  let squeeze = n.frame >= from ? abs(sin(turns * Double.pi)) : 0
  let soft = n.frame >= n.at(1) ? 0.5 + 0.5 * sin(n.frame * 0.25) : 0
  let press = squeeze * 14 + soft * 6
  let hands = n.ease(0, 0.6)
  let c = Pt(WRAP.x, WRAP.y)
  Stage {
    TableItems(umeCount: 2, riceLevel: 0.45)
    Pulse(x: c.x, y: c.y, r: RICE_S * 1.3, color: palette.accent, period: 2, active: n.isSpeaking(1))
    Rice(x: c.x, y: c.y, s: RICE_S, tri: tri, rot: rot, id: "r4")
    Wrap(x: c.x, y: c.y, size: WRAP.size, open: 1, wrap: wrap, riceS: RICE_S, tri: tri, rot: rot)
    if hands > 0 {
      g(opacity: hands) {
        TopHand(from: ARM_L, to: Pt(c.x - RICE_S * 1.15 + press, c.y + 30), angle: 60, cup: 0.8, side: .L)
        TopHand(from: ARM_R, to: Pt(c.x + RICE_S * 1.15 - press, c.y + 30), angle: -60, cup: 0.8, side: .R)
      }
    }
    Callout(x: c.x, y: 300, text: "ふんわりと握る", at: n.at(1, 0.2))
  }
}
