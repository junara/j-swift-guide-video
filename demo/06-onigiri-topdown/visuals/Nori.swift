// 海苔を巻く: ラップを外す → 海苔を下から巻く → お皿にのせて完成
import JGVKit

func Nori(_ props: Props) {
  let n = useNarration()
  let off = interpolate(n.frame, [n.atPhrase(0, 0, 0.1), n.atPhrase(0, 0, 0.8)], [0, 1], .clamp)
  let nori = interpolate(n.frame, [n.atPhrase(0, 1, 0), n.endOf(0)], [0, 1], .clamp)
  let plate = n.ease(1, -0.1)
  let c = Pt(WRAP.x, WRAP.y)
  Stage {
    TableItems(umeCount: 2, noriCount: 2, riceLevel: 0.45)
    if plate > 0 {
      g(opacity: plate, transform: [.translate(c.x, c.y), .scale(0.8 + 0.2 * plate), .translate(-c.x, -c.y)]) {
        TopPlate(x: c.x, y: c.y + 10, r: 210)
      }
    }
    Rice(x: c.x, y: c.y, s: RICE_S, tri: 1, rot: -90, nori: nori, id: "r5")
    if off < 1 {
      g(opacity: 1 - off, transform: [.translate(off * 500, -off * 60)]) {
        Wrap(x: c.x, y: c.y, size: WRAP.size, open: 1, wrap: 1, riceS: RICE_S, tri: 1)
      }
    }
    if plate > 0.5 { Steam(x: c.x, y: c.y - 100, count: 3, height: 120, opacity: 0.35) }
    CheckBadge(x: c.x + 230, y: c.y - 170, at: n.at(1, 0.6), r: 52)
  }
}
