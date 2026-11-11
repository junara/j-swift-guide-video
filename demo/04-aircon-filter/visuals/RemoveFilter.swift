// フィルターを取り外す (拡大): 取っ手を持ってゆっくり引き下ろす → 曲げない・壊さない
import JGVKit

func RemoveFilter(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let out = interpolate(n.frame, [n.atPhrase(0, 1), n.endOf(0)], [0, 0.75], .clamp)
  let handle = place(AC_BIG.x, AC_BIG.y, AC_BIG.scale, 0, Pt(-130, 125 + out * 260))
  let reach = n.ease(0, -0.1)
  let handR = mix(Pt(1640, 790), handle, reach * (1 - n.ease(1, 0.2)))
  let warn = n.ease(1, 0.1)
  Stage {
    Presenter(handR: mix(Pt(440, 680), POINT, n.ease(0, -0.3)))
    CloseUp(steps: [
      CloseUpStep("取っ手を持つ", at: n.at(0, -0.2)),
      CloseUpStep("ゆっくり取り外す", at: n.atPhrase(0, 1, -0.2)),
      CloseUpStep("曲げない・破損させない", at: n.at(1, -0.1)),
    ]) {
      g(opacity: 1 - warn * 0.7) {
        AirCon(x: AC_BIG.x, y: AC_BIG.y, scale: AC_BIG.scale, panel: 0.78, filterOut: out, dust: 1)
      }
      SleeveArm(from: Pt(1640, 790), to: handR, bend: -0.2)
      Pop(at: n.at(1, 0.1), x: 1120, y: 560) {
        Filter(x: 0, y: 0, scale: 0.75, dust: 1, bend: 0.5 + 0.5 * sin(n.sec * 4))
        circle(cx: 150, cy: -90, r: 42, fill: "#d14b3b", stroke: palette.ink, strokeWidth: 4)
        path("M 132 -108 L 168 -72 M 168 -108 L 132 -72", stroke: "#fff", strokeWidth: 8, strokeLinecap: .round)
        T("曲げる・壊すのはNG", x: 0, y: 140, size: 30, weight: 900, color: "#d14b3b")
      }
    }
  }
}
