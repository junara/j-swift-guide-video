// フィルターを取り外す (拡大): ゴム手袋をはめる → つまみ・ロックを確認して回す → 両手で支えてゆっくり下ろす → 新聞紙の上に置く
import JGVKit

private let S = HOOD_BIG.scale
private let SHEET = (x: 1120.0, y: 700.0, w: 640.0)

func RemoveFilter(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let gloves = interpolate(n.frame, [n.at(0, 0.3), n.at(0, 0.8)], [0, 1], .clamp)
  // 2 行目: つまみを回してロックを外す
  let knob = interpolate(n.frame, [n.atPhrase(1, 1, 0.2), n.endOf(1)], [0, 1], .clamp)
  // 3・4 行目: フィルターを下ろす (ローカル px) → 新聞紙へ
  let drop2 = interpolate(n.frame, [n.atPhrase(2, 1), n.endOf(2)], [0, 90], .clamp)
  let drop3 = interpolate(n.frame, [n.atPhrase(3, 0, 0.2), n.atPhrase(3, 1, 0.4)], [0, 1], .clamp)
  let placed = n.frame >= n.at(3)
  let fy = HOOD_BIG.y + (-40 + drop2) * S
  let filterY = fy + (SHEET.y - 4 - fy) * (1 - pow(1 - drop3, 2))
  let knobL = hoodBig(HOOD_PARTS.knobL)
  let knobR = hoodBig(HOOD_PARTS.knobR)
  let halfW = (HOOD_FILTER.w / 2) * S
  // 両手
  let baseL = Pt(760, 790)
  let baseR = Pt(1480, 790)
  var hL = mix(baseL, Pt(900, 640), n.ease(0, 0))
  var hR = mix(baseR, Pt(1340, 640), n.ease(0, 0))
  hL = mix(hL, Pt(knobL.x + 6, knobL.y + 34), n.ease(1, -0.2))
  hR = mix(hR, Pt(knobR.x - 6, knobR.y + 34), n.ease(1, -0.2))
  hL = mix(hL, Pt(1120 - halfW + 10, filterY + 22), n.ease(2, -0.2))
  hR = mix(hR, Pt(1120 + halfW - 10, filterY + 22), n.ease(2, -0.2))
  let release = interpolate(n.frame, [n.atPhrase(3, 1, 0.5), n.atPhrase(3, 1, 1.0)], [0, 1], .clamp)
  hL = mix(hL, baseL, release)
  hR = mix(hR, baseR, release)

  Stage {
    Worker(handR: mix(Pt(440, 680), POINT, n.ease(0, -0.3)), gloves: gloves)
    CloseUp(steps: [
      CloseUpStep("ゴム手袋をはめる", at: n.at(0, -0.2)),
      CloseUpStep("つまみ・ロックを確認", at: n.at(1, -0.1)),
      CloseUpStep("両手で支えて外す", at: n.at(2, -0.1)),
      CloseUpStep("新聞紙の上に置く", at: n.at(3, -0.1)),
    ]) {
      RangeHood(x: HOOD_BIG.x, y: HOOD_BIG.y, scale: S, knob: knob, drop: drop2, hideFilter: placed, dirt: 0.9, oil: 1, gaps: 0.8)
      NewsSheet(x: SHEET.x, y: SHEET.y, w: SHEET.w)
      if placed {
        g(opacity: 0.78 + 0.22 * drop3) {
          Placed(x: 1120, y: filterY) {
            FilterFace(w: HOOD_FILTER.w * S, h: HOOD_FILTER.h * S, oil: 1, gaps: 0.8, seed: "hf")
          }
        }
      }
      Pulse(x: knobL.x, y: knobL.y, r: 60, color: palette.accent, period: 1.2, active: n.isSpeaking(1))
      Pulse(x: knobR.x, y: knobR.y, r: 60, color: palette.accent, period: 1.2, active: n.isSpeaking(1))
      SleeveArm(from: baseL, to: hL, bend: 0.12)
      SleeveArm(from: baseR, to: hR, bend: -0.12)
      GloveHand(x: hL.x, y: hL.y, on: gloves)
      GloveHand(x: hR.x, y: hR.y, on: gloves)
      g(opacity: 1 - n.ease(1, -0.2)) {
        Callout(x: 1120, y: 575, text: "油で手が汚れないように", at: n.at(0, 0.6))
      }
      g(opacity: 1 - n.ease(3, -0.1)) {
        Callout(x: 1120, y: 600, text: "落とさないよう、ゆっくり", at: n.atPhrase(2, 1, 0.2))
      }
    }
  }
}
