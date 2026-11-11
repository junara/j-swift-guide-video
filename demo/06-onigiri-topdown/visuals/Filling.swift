// 具をのせる: 指で真ん中をくぼませる → 梅干しをつまんでのせる → 上からご飯をかぶせる
import Foundation
import JGVKit

func Filling(_ props: Props) {
  let n = useNarration()
  let pressT = n.atPhrase(0, 0, 0.3)
  let dent = interpolate(n.frame, [pressT, pressT + 14], [0, 1], .clamp)
  let pickT = n.atPhrase(0, 1, 0)
  let move = interpolate(n.frame, [pickT + 6, pickT + 24], [0, 1], .clamp)
  let placed = move >= 1
  let ume = mix(Pt(UME_PLATE.x + 24, UME_PLATE.y + 14), Pt(WRAP.x, WRAP.y), move)
  let coverT = n.at(1, 0.3)
  let cover = interpolate(n.frame, [coverT, coverT + 14], [0, 1], .clamp)
  // 右手: くぼませる → 梅干しをつまむ → かぶせる → 下げる
  var hand = mix(Pt(1300, 900), Pt(WRAP.x + 10, WRAP.y + 40), n.ease(0, -0.1))
  if n.frame >= pickT - 6 { hand = mix(hand, Pt(ume.x + 14, ume.y + 40), interpolate(n.frame, [pickT - 6, pickT + 6], [0, 1], .clamp)) }
  if n.frame >= coverT - 8 {
    hand = mix(Pt(ume.x + 14, ume.y + 40), Pt(WRAP.x + 10, WRAP.y + 30 + sin(n.frame * 0.6) * 8), interpolate(n.frame, [coverT - 8, coverT + 4], [0, 1], .clamp))
  }
  if n.frame >= n.endOf(1) - 8 { hand = mix(hand, Pt(1400, 1000), interpolate(n.frame, [n.endOf(1) - 8, n.endOf(1) + 8], [0, 1], .clamp)) }
  Stage {
    TableItems(umeCount: 2, riceLevel: 0.45)
    Wrap(x: WRAP.x, y: WRAP.y, size: WRAP.size, open: 1)
    Rice(x: WRAP.x, y: WRAP.y, s: RICE_S, dent: dent, ume: placed ? 1 : 0, cover: cover, id: "r3")
    if !placed && n.frame >= pickT { Umeboshi(x: ume.x, y: ume.y, r: RICE_S * 0.22) }
    TopHand(from: ARM_R, to: hand, angle: -15, cup: 0.5)
  }
}
