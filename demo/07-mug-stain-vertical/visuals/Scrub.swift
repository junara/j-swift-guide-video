// こする (縦型): スポンジでくるくる。茶渋がだんだん消えて泡が立つ
import JGVKit

func Scrub(_ props: Props) {
  let n = useNarration()
  let st = useStage()
  let Y = st.counterY
  let cu = st.closeUp
  let from = n.atPhrase(0, 1, -0.1)
  let p = interpolate(n.frame, [from, n.endOf(0) + 10], [0, 1], .clamp)
  let ang = n.frame * 0.35
  let c = Pt(cu.x + cu.w / 2, cu.y + 200)
  let sp = n.frame >= from ? Pt(c.x + cos(ang) * 150, c.y + sin(ang) * 50) : Pt(c.x + 380, c.y + 160)
  let pick = n.ease(0, -0.2)
  let handOver = Pt(680 + cos(ang) * 30, Y - 170 + sin(ang) * 10)
  Stage {
    Shadow(x: 680, w: 220)
    Mug(x: 680, y: Y, scale: 0.8)
    if pick < 0.5 { Sponge(x: 520, y: Y, scale: 0.8) }
    Presenter(handR: mix(st.pose.restR, handOver, pick))
    CloseUp(steps: [CloseUpStep(label: "くるくるとこする", at: n.at(0, -0.2))]) {
      MugInside(x: c.x, y: c.y, rx: 300, ry: 120, stain: 1 - p, soda: 1 - p * 0.7, paste: 1, foam: p > 0.05 ? min(1, p * 2) : 0)
      Sponge(x: sp.x, y: sp.y + 30, scale: 1, angle: sin(ang) * 10)
      SleeveArm(from: Pt(cu.x + cu.w + 20, cu.y + cu.h), to: Pt(sp.x + 60, sp.y - 10), bend: -0.15)
    }
  }
}
