// 前面パネルを開く (拡大): 両手でパネルの端を持ち、ゆっくり持ち上げる → 無理な力は NG
import JGVKit

func OpenPanel(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let grab = n.ease(0, 0)
  let panel = 0.78 * interpolate(n.frame, [n.atPhrase(0, 1), n.endOf(0)], [0, 1], .clamp)
  let edge = panelEdgeY(panel)
  let pL = place(AC_BIG.x, AC_BIG.y, AC_BIG.scale, 0, Pt(-250, edge))
  let pR = place(AC_BIG.x, AC_BIG.y, AC_BIG.scale, 0, Pt(250, edge))
  let handL = mix(Pt(600, 780), pL, grab)
  let handR = mix(Pt(1640, 780), pR, grab)
  Stage {
    Presenter(handR: mix(Pt(440, 680), POINT, n.ease(0, -0.3)))
    CloseUp(steps: [
      CloseUpStep("パネルの両端を持つ", at: n.at(0, -0.2)),
      CloseUpStep("ゆっくり開く", at: n.atPhrase(0, 1, -0.2)),
      CloseUpStep("無理に力を加えない", at: n.at(1, -0.1)),
    ]) {
      AirCon(x: AC_BIG.x, y: AC_BIG.y, scale: AC_BIG.scale, panel: panel, dust: 1)
      SleeveArm(from: Pt(600, 790), to: handL, bend: 0.15)
      SleeveArm(from: Pt(1640, 790), to: handR, bend: -0.15)
      Pop(at: n.at(1, 0.2), x: 1120, y: 700) {
        rect(x: -230, y: -38, width: 460, height: 76, rx: 38, fill: "#fff", stroke: "#d14b3b", strokeWidth: 4)
        Icon(name: "warning", x: -180, y: 0, size: 46, color: "#d14b3b")
        T("無理な力はNG", x: 20, y: 0, size: 32, weight: 900, color: palette.ink)
      }
    }
  }
}
