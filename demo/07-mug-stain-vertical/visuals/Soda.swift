// 重曹を入れる (縦型): スプーンで重曹をマグへ → 水を少し足してペーストに
import JGVKit

func Soda(_ props: Props) {
  let n = useNarration()
  let st = useStage()
  let Y = st.counterY
  let cu = st.closeUp
  // 1 行目: スプーンで茶筒 → マグ
  let scoopT = n.atPhrase(0, 1, -0.2)
  let carry = interpolate(n.frame, [scoopT, scoopT + 18], [0, 1], .clamp)
  let tilt = interpolate(n.frame, [scoopT + 18, scoopT + 26], [0, -60], .clamp)
  let spoon = mix(Pt(890, Y - 200), Pt(700, Y - 220), carry)
  let soda = interpolate(n.frame, [scoopT + 20, scoopT + 32], [0, 1], .clamp)
  let grip = place(spoon.x, spoon.y, 0.8, tilt, SPOON_PARTS.grip)
  // 2 行目: 水を加えてペーストに
  let water = interpolate(n.frame, [n.at(1, 0.2), n.atPhrase(1, 1, 0)], [0, 1], .clamp)
  let paste = interpolate(n.frame, [n.atPhrase(1, 1, 0), n.endOf(1)], [0, 1], .clamp)
  let reach = n.ease(0, 0) * (1 - n.ease(1, -0.1))
  Stage {
    Shadow(x: 680, w: 220)
    Mug(x: 680, y: Y, scale: 0.8)
    Shadow(x: 890, w: 120)
    Canister(x: 890, y: Y, scale: 0.75, label: "重曹", lidOpen: n.ease(0, -0.2))
    Shadow(x: 520, w: 130)
    Sponge(x: 520, y: Y, scale: 0.8)
    if n.frame < n.at(1) { Spoon(x: spoon.x, y: spoon.y, scale: 0.8, angle: tilt, leaves: false) }
    Presenter(handR: mix(st.pose.gestureR, grip, reach))
    CloseUp(steps: [
      CloseUpStep(label: "重曹を小さじ1杯", at: n.at(0, -0.2)),
      CloseUpStep(label: "少量の水でペーストに", at: n.at(1, -0.1)),
    ]) {
      MugInside(x: cu.x + cu.w / 2, y: cu.y + 200, rx: 300, ry: 120, stain: 1, soda: soda, paste: paste, water: water * 0.25)
    }
  }
}
