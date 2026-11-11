// 天板と底板を付ける: 天板・底板を差し込みネジ留め → 反対側 (左) の側板を合わせて留める
import JGVKit

func Frame(_ props: Props) {
  let n = useNarration()
  let uT = useAssemble(n.atPhrase(0, 0, 0.1))
  let uB = useAssemble(n.atPhrase(0, 0, 0.5))
  let uL = useAssemble(n.atPhrase(1, 0, 0))
  let showL = n.frame >= n.at(1, -0.3)
  Stage {
    ColorBox(state: [
      .AR: PartState(), .C1: PartState(), .C2: PartState(), .T: PartState(off: (0, 0, 22 * uT)), .B: PartState(off: (0, 30 * uB, 0)),
      .AL: PartState(off: (-30 * uL, 0, 0), opacity: showL ? 1 : 0),
    ])
    DashArrow(from: partCenter(.T, (0, 0, 22)), to: partCenter(.T), progress: n.progress(0, 0.5, 0))
    DashArrow(from: partCenter(.B, (0, 30, 0)), to: partCenter(.B), progress: n.progress(0, 0.5, 0.4))
    if showL { DashArrow(from: partCenter(.AL, (-30, 0, 0)), to: partCenter(.AL), progress: n.progress(1, 0.5, -0.2)) }
    Screwing(points: screwsOnRight([88, 1]), from: n.atPhrase(0, 1, 0), to: n.endOf(0) + 4)
    Screwing(points: screwsOnLeft([88, 60]), from: n.atPhrase(1, 1, 0), to: n.endOf(1) + 8)
    Callout(x: 1500, y: 330, text: "同じようにネジで留める", at: n.at(0, 0.3))
  }
}
