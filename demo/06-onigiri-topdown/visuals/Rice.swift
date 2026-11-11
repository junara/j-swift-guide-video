// ご飯をのせる: ラップを広げる → 塩を振る → しゃもじで茶わん一杯分のせる
import JGVKit

func Rice(_ props: Props) {
  let n = useNarration()
  let open = spring(frame: n.frame - n.atPhrase(0, 0, 0.1), fps: n.fps, damping: 18)
  // 塩: ラップの上へ移動して振る
  let saltGo = interpolate(n.frame, [n.atPhrase(0, 1, -0.1), n.atPhrase(0, 1, 0.3), n.endOf(0) - 4, n.endOf(0) + 8], [0, 1, 1, 0], .clamp)
  let saltPos = mix(SALT, Pt(WRAP.x + 60, WRAP.y - 90), saltGo)
  let salt = interpolate(n.frame, [n.atPhrase(0, 1, 0.3), n.endOf(0)], [0, 0.6], .clamp)
  // 2 行目: しゃもじで茶わん → ラップへ (2 往復)
  let from = n.at(1, 0.1)
  let span = (n.endOf(1) - from) / 2
  let k = min(1.999, max(0, (n.frame - from) / span))
  let phase = jsMod(k, 1)
  let active = n.frame >= from && n.frame < n.endOf(1)
  let carry = interpolate(phase, [0.1, 0.45, 0.6, 0.95], [0, 1, 1, 0], .clamp)
  let paddle = active ? mix(Pt(BOWL.x + 20, BOWL.y), Pt(WRAP.x, WRAP.y), carry) : Pt(BOWL.x + 200, BOWL.y + 200)
  let hasRice = active && phase > 0.12 && phase < 0.55
  let pile = interpolate(n.frame, [from + span * 0.55, from + span * 0.62, from + span * 1.55, from + span * 1.62], [0, 0.6, 0.6, 1], .clamp)
  let level = 0.85 - 0.4 * interpolate(n.frame, [from, n.endOf(1)], [0, 1], .clamp)
  let grip = Pt(paddle.x + SHAMOJI_GRIP.x, paddle.y + SHAMOJI_GRIP.y)
  Stage {
    TableItems(saltPos: saltPos, shake: saltGo > 0.95 ? 1 : 0, riceLevel: level)
    Wrap(x: WRAP.x, y: WRAP.y, size: WRAP.size, open: open)
    Sprinkle(x: WRAP.x, y: WRAP.y, r: 110, amount: salt)
    if pile > 0 { Rice(x: WRAP.x, y: WRAP.y, s: RICE_S * (0.6 + 0.4 * pile), id: "r2") }
    if n.frame >= n.at(1, -0.2) {
      g {
        Shamoji(x: paddle.x, y: paddle.y, rice: hasRice ? 1 : 0)
        TopHand(from: ARM_R, to: grip, angle: 0)
      }
    }
    Callout(x: WRAP.x, y: 300, text: "茶わん一杯分", at: n.at(1, 0.3))
  }
}
