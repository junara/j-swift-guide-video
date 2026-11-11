// 本体を拭く (拡大): 薄めた洗剤液に雑巾を浸して固く絞る → 油汚れを拭く (洗剤の跡) → 水拭きで洗剤を落とす → 乾いたタオルで仕上げ
import JGVKit

private let BASE_L = Pt(760, 790)
private let BASE_R = Pt(1480, 790)
private let BASIN = (x: 1120.0, y: 800.0, scale: 1.6)
private let WRING = Pt(1120, 600)

func WipeHood(_ props: Props) {
  let n = useNarration()
  // 1 行目: 浸す → 絞る
  let dip = interpolate(n.frame, [n.at(0, 0.3), n.at(0, 0.9), n.atPhrase(0, 1, -0.4), n.atPhrase(0, 1)], [0, 1, 1, 0], .clamp)
  let wringing = n.frame >= n.atPhrase(0, 1) && n.frame < n.endOf(0) + 6
  let twist = wringing ? 0.5 + 0.5 * sin((n.frame - n.atPhrase(0, 1)) * 0.25) : 0
  let cloth0 = Pt(WRING.x, WRING.y + dip * 110)
  let basinOut = n.ease(1, -0.1)
  // 2〜4 行目: 拭く (洗剤 → 水拭き → 乾拭き)
  let pass = { (i: Int) -> Double in interpolate(n.frame, [n.at(.index(i), 0.2), n.endOf(.index(i))], [0, 1], .clamp) }
  let w1 = pass(1)
  let w2 = pass(2)
  let w3 = pass(3)
  let cur = n.frame >= n.at(3, -0.2) ? 3 : n.frame >= n.at(2, -0.2) ? 2 : 1
  let u = cur == 1 ? w1 : cur == 2 ? w2 : w3
  let wipeP = zigzag(u, 820, 1420, 300, 420, 3)
  let dirt = 0.9 * (1 - w1)
  let soap = min(1, w1 * 1.4) * (1 - w2)
  let colors: [Int: Paint] = [1: "#eef0f2", 2: "#d3e8f2", 3: TOWEL_COLOR]
  let hL = mix(Pt(cloth0.x - 70, cloth0.y), BASE_L, basinOut)
  let hR = mix(Pt(cloth0.x + 70, cloth0.y), wipeP, n.ease(1, -0.3))
  let clothP = n.frame < n.at(1, -0.3) ? cloth0 : hR
  // 持ち替えの瞬間 (行の頭) は布を少し下げて入れ替える
  let swap = { (i: Int) -> Double in
    let k = LineKey.index(i)
    return interpolate(n.frame, [n.at(k, -0.3), n.at(k, -0.1), n.at(k, 0.1), n.at(k, 0.3)], [0, 1, 1, 0], .clamp)
  }
  let dropY = (swap(2) + swap(3)) * 80

  Stage {
    Worker(handR: mix(LOW, POINT, n.ease(0, -0.3)), gloves: 1)
    CloseUp(steps: [
      CloseUpStep("洗剤液に浸して固く絞る", at: n.at(0, -0.2)),
      CloseUpStep("油汚れを拭き取る", at: n.at(1, -0.2)),
      CloseUpStep("水拭きで洗剤を落とす", at: n.at(2, -0.2)),
      CloseUpStep("乾いたタオルで仕上げ", at: n.at(3, -0.2)),
    ]) {
      RangeHood(x: HOOD_BIG.x, y: HOOD_BIG.y, scale: HOOD_BIG.scale, hideFilter: true, dirt: dirt, soap: soap)
      Sparkles(x: HOOD_BIG.x, y: 350, w: 700, h: 160, on: w3, count: 8, seed: "wh")
      g(opacity: 1 - basinOut) {
        Basin(x: BASIN.x, y: BASIN.y, scale: BASIN.scale, suds: 1, color: "#9cc3d6")
        if wringing { Drips(x: WRING.x, y: WRING.y + 40, w: 70, fall: 70, count: 5, seed: "wr") }
      }
      Cloth(x: clothP.x, y: clothP.y + 20 + dropY, scale: 1.1, angle: n.frame < n.at(1, -0.3) ? 0 : -10, color: colors[cur]!, twist: twist, wet: cur == 3 ? 0 : 0.6)
      SleeveArm(from: BASE_L, to: hL, bend: 0.12)
      SleeveArm(from: BASE_R, to: Pt(hR.x, hR.y + dropY), bend: -0.12)
      GloveHand(x: hL.x, y: hL.y)
      GloveHand(x: hR.x, y: hR.y + dropY)
      CheckBadge(x: 1480, y: 330, at: n.endOf(3) - 4)
    }
  }
}
