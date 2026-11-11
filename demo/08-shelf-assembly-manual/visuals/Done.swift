// 完成: 本体を起こして完成 (チェック) → 重い物の載せすぎに注意
import JGVKit

func Done(_ props: Props) {
  let n = useNarration()
  let lift = interpolate(n.frame, [n.at(0, 0), n.at(0, 0.5), n.at(0, 0.8)], [0, -18, 0], .clamp)
  let warnAt = n.at(1, 0.2)
  let weight = isoPoint(ISO, 20, 15, 61)
  Stage {
    g(transform: [.translate(0, lift)]) {
      ColorBox(state: [.D: PartState(), .AL: PartState(), .B: PartState(), .C1: PartState(), .C2: PartState(), .T: PartState(), .AR: PartState()])
      if n.frame >= warnAt {
        g {
          IsoBox(iso: ISO, x: 10, y: 5, z: 61, w: 20, d: 18, h: 14, fill: "#c9ced0")
          Pulse(x: weight.x, y: weight.y - 40, r: 70, color: "#d14b3b", period: 1)
        }
      }
    }
    CheckBadge(x: 1180, y: 300, at: n.at(0, 0.6), r: 56)
    Pop(at: warnAt + 6, x: 1530, y: 560) {
      rect(x: -210, y: -60, width: 420, height: 120, rx: 20, fill: "#fff", stroke: "#d14b3b", strokeWidth: 5)
      T("載せすぎ注意", x: 0, y: -16, size: 34, weight: 900, color: "#d14b3b")
      T("棚板1枚あたり 10kg まで", x: 0, y: 28, size: 24, weight: 700, color: "#2b2f33")
    }
  }
}
