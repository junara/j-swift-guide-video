// 背板をはめる: 背板が後ろから溝に滑り込む (点線の輪郭 → 実線)
import JGVKit

func Back(_ props: Props) {
  let n = useNarration()
  let u = useAssemble(n.atPhrase(0, 1, -0.2))
  let solid = interpolate(n.frame, [n.atPhrase(0, 1, 0.6), n.atPhrase(0, 1, 0.9)], [0, 1], .clamp)
  Stage {
    ColorBox(state: [.D: PartState(off: (0, -40 * u, 30 * u), dashed: solid < 0.5), .AL: PartState(), .B: PartState(), .C1: PartState(), .C2: PartState(), .T: PartState(), .AR: PartState()])
    DashArrow(from: partCenter(.D, (0, -40, 30)), to: partCenter(.D, (0, -6, 4)), progress: n.progress(0, 0.6, 0))
    Callout(x: 1500, y: 330, text: "後ろの溝にはめ込む", at: n.at(0, 0.3))
  }
}
