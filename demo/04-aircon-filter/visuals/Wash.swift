// 水洗い (拡大): 汚れの残るフィルター → 裏返して蛇口の水を流す → 汚れが落ちる
import JGVKit

private let F = (x: 1110.0, y: 580.0, scale: 1.25)
private let TAP = Pt(1160, 330)

func Wash(_ props: Props) {
  let n = useNarration()
  let flip = interpolate(n.frame, [n.atPhrase(1, 0), n.atPhrase(1, 0, 0.6)], [0, 1], .clamp)
  let water = n.frame >= n.atPhrase(1, 0, 0.6)
  let clean = interpolate(n.frame, [n.atPhrase(1, 1), n.endOf(1)], [0, 1], .clamp)
  let dirt = 0.7 * (1 - clean)
  Stage {
    Presenter(handR: mix(Pt(440, 680), POINT, n.ease(0, -0.3)))
    CloseUp(steps: [
      CloseUpStep("汚れがひどい場合", at: n.at(0, -0.2)),
      CloseUpStep("裏側から水を流す", at: n.atPhrase(1, 0, -0.2)),
      CloseUpStep("ホコリを洗い落とす", at: n.atPhrase(1, 1, -0.2)),
    ]) {
      g(opacity: n.ease(0, 0.2)) {
        Faucet(x: TAP.x, y: TAP.y)
      }
      Filter(x: F.x, y: F.y, scale: F.scale, dust: dirt, wet: water ? 1 : 0, flip: flip, label: true)
      Stream(from: Pt(TAP.x, TAP.y + 4), to: Pt(TAP.x - 10, F.y - 60), color: "#8fcbe6", width: 20, active: water)
      if water { Drips(x: F.x, y: F.y + 150, w: 360, fall: 140, color: clean < 0.8 ? "#9b958a" : "#8fcbe6", count: 10, seed: "w") }
      Callout(x: 1420, y: 395, text: "汚れがひどいときだけ", at: n.at(0, 0.3))
    }
  }
}
