// STEP 6: 湯のみを両手で持ち上げ、湯気が立つ。完成のチェックと、おかわりのヒント
import JGVKit

private let Y = GUIDE.counterY

func Enjoy(_ props: Props) {
  let n = useNarration()
  let lift = n.ease(0, -0.2)
  let cupRest = Pt(1080, Y)
  let cupHeld = Pt(600, 620)
  let cup = mix(cupRest, cupHeld, lift)
  let sip = sin(n.sec * 1.6) * 6 * lift
  let handR = mix(PRESENTER.gestureR, Pt(cup.x + 70, cup.y - 60 + sip), interpolate(n.frame, [n.at(0, -0.4), n.at(0, -0.1)], [0, 1], .clamp))
  let handL = mix(PRESENTER.restL, Pt(cup.x - 70, cup.y - 50 + sip), interpolate(n.frame, [n.at(0, -0.2), n.at(0, 0.2)], [0, 1], .clamp))

  Stage {
    Shadow(x: 960, w: 240)
    Teapot(x: 960, y: Y)
    Shadow(x: 1260, w: 140)
    Yunomi(x: 1260, y: Y, scale: 0.9, fill: 0.7)
    Steam(x: 1260, y: Y - 130, count: 2, height: 110)
    Shadow(x: cupRest.x, w: 140 * (1 - lift * 0.8))
    Presenter(handL: handL, handR: handR)
    Yunomi(x: cup.x, y: cup.y + sip, scale: 0.9, fill: 0.7)
    Steam(x: cup.x, y: cup.y - 130 + sip, count: 3, height: 140)
    CheckBadge(x: 1420, y: Y - 300, at: n.at(0, 0.3), r: 56)
    Callout(x: 1100, y: Y - 420, text: "2煎目は熱めのお湯でさっと", at: n.at(1, 0.4))
  }
}
