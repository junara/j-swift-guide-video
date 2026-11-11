// 用意する (縦型): 句ごとにマグ → 重曹 → スポンジが置かれる。下の拡大カードで茶渋を見せる
import JGVKit

func Prepare(_ props: Props) {
  let n = useNarration()
  let st = useStage()
  let Y = st.counterY
  let drop = { (at: Double) in spring(frame: n.frame - at, fps: n.fps, damping: 13, stiffness: 140) }
  let mugIn = drop(n.atPhrase(0, 0, 0))
  let sodaIn = drop(n.atPhrase(0, 1, 0))
  let spongeIn = drop(n.at(1, 0))
  let cu = st.closeUp
  Stage {
    Shadow(x: 680, w: 220 * mugIn)
    Mug(x: 680, y: Y - (1 - mugIn) * 300, scale: 0.8)
    Shadow(x: 890, w: 120 * sodaIn)
    Canister(x: 890, y: Y - (1 - sodaIn) * 300, scale: 0.75, label: "重曹")
    Shadow(x: 520, w: 130 * spongeIn)
    Sponge(x: 520, y: Y - (1 - spongeIn) * 300, scale: 0.8)
    Presenter(handR: mix(st.pose.restR, st.pose.gestureR, n.ease(0, -0.2)))
    CloseUp(steps: [
      CloseUpStep(label: "茶渋のついたマグ", at: n.atPhrase(0, 0, -0.2)),
      CloseUpStep(label: "重曹", at: n.atPhrase(0, 1, -0.2)),
      CloseUpStep(label: "スポンジ", at: n.at(1, -0.1)),
    ]) {
      MugInside(x: cu.x + cu.w / 2, y: cu.y + 200, rx: 300, ry: 120, stain: 1)
    }
  }
}
