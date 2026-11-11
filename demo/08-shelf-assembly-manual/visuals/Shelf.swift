// 棚板を取り付ける: 右の側板に棚板 2 枚を差し込む (点線の矢印) → ネジで固定
import JGVKit

func Shelf(_ props: Props) {
  let n = useNarration()
  let u1 = useAssemble(n.atPhrase(0, 1, -0.1))
  let u2 = useAssemble(n.atPhrase(0, 1, 0.4))
  let off = { (u: Double) -> Off3 in (0, 34 * u, 0) }
  Stage {
    ColorBox(state: [.AR: PartState(), .C1: PartState(off: off(u1)), .C2: PartState(off: off(u2))])
    DashArrow(from: partCenter(.C2, (0, 34, 0)), to: partCenter(.C2), progress: n.progress(0, 0.5, 0))
    DashArrow(from: partCenter(.C1, (0, 34, 0)), to: partCenter(.C1), progress: n.progress(0, 0.5, 0.3))
    Screwing(points: screwsOnRight([60, 30]), from: n.at(1, 0.1), to: n.endOf(1) + 6)
    Callout(x: 1500, y: 330, text: "しっかり固定", at: n.at(1, 0.2))
  }
}
