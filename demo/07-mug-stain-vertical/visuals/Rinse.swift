// すすぐ (縦型): 蛇口の水ですすぐ → ピカピカ + チェック
import JGVKit

func Rinse(_ props: Props) {
  let n = useNarration()
  let st = useStage()
  let Y = st.counterY
  let cu = st.closeUp
  let c = Pt(cu.x + cu.w / 2, cu.y + 200)
  let shineAt = n.atPhrase(0, 1, 0)
  let water = interpolate(n.frame, [n.at(0), n.at(0, 0.4), shineAt - 6, shineAt + 4], [0, 1, 1, 0], .clamp)
  let shine = interpolate(n.frame, [shineAt, shineAt + 10], [0, 1], .clamp)
  let tap = Pt(c.x + 120, cu.y + 40)
  let tapD = "M \(tap.x + 260) \(tap.y - 30) H \(tap.x + 20) Q \(tap.x) \(tap.y - 30) \(tap.x) \(tap.y)"
  Stage {
    Shadow(x: 680, w: 220)
    Mug(x: 680, y: Y, scale: 0.8)
    Burst(at: shineAt, x: 680, y: Y - 150, r: 150, count: 14)
    CheckBadge(x: 860, y: Y - 300, at: shineAt + 8, r: 54)
    Presenter(handR: mix(st.pose.restR, st.pose.gestureR, n.ease(0, -0.2)))
    CloseUp(steps: [
      CloseUpStep(label: "水でよくすすぐ", at: n.at(0, -0.2)),
      CloseUpStep(label: "ピカピカ！", at: shineAt),
    ]) {
      MugInside(x: c.x, y: c.y, rx: 300, ry: 120, stain: 0, water: water, shine: shine)
      path(tapD, fill: "none", stroke: "#353b35", strokeWidth: 40, strokeLinecap: .round)
      path(tapD, fill: "none", stroke: "#c9ced0", strokeWidth: 28, strokeLinecap: .round)
      Stream(from: Pt(tap.x, tap.y + 10), to: Pt(c.x + 40, c.y), color: "#8fcbe6", width: 18, active: water > 0.5)
      Burst(at: shineAt + 2, x: c.x, y: c.y, r: 200, count: 16, color: "#f2c14e")
    }
  }
}
