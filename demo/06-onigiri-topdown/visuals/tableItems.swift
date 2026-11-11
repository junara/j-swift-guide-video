// 作業台の常設アイテム (塩・梅干しの皿・海苔・茶わん)。xxxIn で個別に出し入れ
import JGVKit

func TableItems(
  bowlIn: Double = 1, saltIn: Double = 1, umeIn: Double = 1, noriIn: Double = 1,
  umeCount: Int = 3, noriCount: Int = 3, saltPos: Pt = SALT, shake: Double = 0, riceLevel: Double = 0.85
) {
  g {
    g(opacity: bowlIn, transform: [.translate((1 - bowlIn) * -300, 0)]) {
      TopBowl(x: BOWL.x, y: BOWL.y, r: BOWL.r, fill: "#fbfaf5", level: riceLevel, grains: "#e3ddcf")
    }
    g(opacity: umeIn, transform: [.translate((1 - umeIn) * 300, 0)]) {
      TopPlate(x: UME_PLATE.x, y: UME_PLATE.y, r: UME_PLATE.r)
      for i in 0..<umeCount {
        Umeboshi(x: UME_PLATE.x - 24 + Double(i) * 24, y: UME_PLATE.y + (i % 2 != 0 ? 14 : -10), r: 20)
      }
    }
    g(opacity: noriIn, transform: [.translate((1 - noriIn) * 300, 0)]) {
      NoriStack(x: NORI.x, y: NORI.y, count: noriCount)
    }
    g(opacity: saltIn, transform: [.translate((1 - saltIn) * 300, 0)]) {
      TopShaker(x: saltPos.x, y: saltPos.y, shake: shake)
    }
  }
}

/// at フレームで横からすべり込む
func useSlide(_ at: Double) -> Double {
  let n = useNarration()
  return spring(frame: n.frame - at, fps: n.fps, damping: 16, stiffness: 120)
}
