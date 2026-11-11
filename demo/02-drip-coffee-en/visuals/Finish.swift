// Remove and enjoy: バッグを持ち上げて外す (しずく注意) → 完成のチェック → 湯気
import JGVKit

func Finish(_ props: Props) {
  let n = useNarration()
  let liftFrom = n.atPhrase(0, 1, -0.2)
  let lift = interpolate(n.frame, [liftFrom, liftFrom + 22], [0, 1], .clamp)
  // 人物側 (左上) に持ち上げる
  let aside = Pt(MUG.x - 260, BAG_ON_MUG.y - 200)
  let bag = mix(BAG_ON_MUG, aside, 1 - pow(1 - lift, 2))
  let hold = place(bag.x, bag.y, BAG_SCALE, 0, Pt(DRIPBAG_PARTS.hookL.x + 20, DRIPBAG_PARTS.hookL.y))
  let reach = interpolate(n.frame, [liftFrom - 12, liftFrom], [0, 1], .clamp)
  let handR = mix(mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, -0.2)), hold, reach)
  // バッグの下から落ちるしずく
  let period = jsRound(n.fps * 0.7)
  let t = jsMod(jsMod(n.frame - liftFrom, period) + period, period)
  let dropY = bag.y + 6 + (t / period) * 140

  Stage {
    Shadow(x: MUG.x, w: 250)
    Mug(x: MUG.x, y: MUG.y, fill: 1)
    Steam(x: MUG.x, y: Y - 210, count: 3, height: 170, opacity: 0.6 * n.ease(2))
    DripBag(x: bag.x, y: bag.y, scale: BAG_SCALE, open: 1, hooks: 1, wet: 1, water: 0.1)
    if lift > 0.9 { ellipse(cx: bag.x, cy: dropY, rx: 7, ry: 11, fill: "#7a4a2a", opacity: 1 - t / period) }
    Presenter(handR: handR)
    Callout(x: MUG.x - 260, y: Y - 470, text: n.t("finish.callout", "Be careful of hot drips"), at: n.at(1))
    CheckBadge(x: MUG.x + 260, y: Y - 330, at: n.at(2), r: 56)
  }
}
