// はじめに: ケージの中でうさぎが跳ねる (快適に) → ケージがきらめく (清潔に) → 掃除方法の案内
import Foundation
import JGVKit

func Intro(_ props: Props) {
  let n = useNarration()
  // 「快適に過ごせるように」でぴょんぴょん跳ねる
  let hopT = (n.frame - n.atPhrase(0, 0)) / n.fps
  let hopping = hopT > 0 && hopT < 2.4
  let hop = hopping ? abs(sin(hopT * Double.pi * 1.6)) * 60 : 0
  let dx = hopping ? sin(hopT * 1.3) * 70 : interpolate(hopT, [2.4, 3], [sin(2.4 * 1.3) * 70, 0], .clamp)
  // 「清潔に保つ」で汚れが消えてきらめく
  let clean = interpolate(n.frame, [n.atPhrase(0, 1), n.atPhrase(0, 1, 1)], [0, 1], .clamp)
  Stage {
    Shadow(x: CAGE.x, w: 620)
    CageSet(dirt: 1 - clean, rabbit: true, nibble: !hopping, rabbitAt: Pt(SLOT.rabbit.x + dx, SLOT.rabbit.y - hop)) {
      Litter(x: CAGE.x, y: CAGE.y - 52, w: 520, amount: 1 - clean, seed: "in")
    }
    Hearts(x: SLOT.rabbit.x + dx - 50, y: SLOT.rabbit.y - 200, on: hopping ? 1 : 0)
    Sparkles(x: CAGE.x, y: CAGE.y - 200, w: 560, h: 300, on: clean * (1 - n.ease(1, 1)), count: 8)
    Presenter(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, 0)))
    Callout(x: CAGE.x, y: CAGE.y - 470, text: "ケージの中を清潔に", at: n.atPhrase(0, 1))
  }
}
