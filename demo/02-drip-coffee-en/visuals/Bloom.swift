// Let the coffee bloom: 少しだけお湯を注いで粉を湿らせ、20 秒蒸らす (タイマーは短縮表示)
import JGVKit

func Bloom(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let top = Pt(BAG_ON_MUG.x, BAG_ON_MUG.y - 158 * BAG_SCALE - 10)
  let spoutAt = Pt(top.x + 30, top.y - 110)
  let k = kettlePour(n.frame, n.atPhrase(0, 1, -0.4), n.endOf(0) + 6, spoutAt, 40)
  let wet = interpolate(n.frame, [n.atPhrase(0, 1), n.endOf(0)], [0, 0.45], .clamp)
  let timerAt = n.at(1, 0.2)
  let tp = interpolate(n.frame, [timerAt, n.endOf(1)], [0, 1], .clamp)
  let timer = Pt(1420, Y - 400)

  Stage {
    Shadow(x: MUG.x, w: 250)
    Mug(x: MUG.x, y: MUG.y)
    DripBag(x: BAG_ON_MUG.x, y: BAG_ON_MUG.y, scale: BAG_SCALE, open: 1, hooks: 1, wet: wet, water: k.pouring ? 0.6 : wet)
    Stream(from: k.spout, to: top, color: "#bfe0ee", width: 10, active: k.pouring)
    if n.frame >= timerAt { Steam(x: MUG.x, y: top.y - 10, count: 3, height: 130, opacity: 0.5) }
    Shadow(x: KETTLE_REST.x, w: 220 * (1 - k.reach * 0.6))
    Kettle(x: k.pos.x, y: k.pos.y, scale: KETTLE_SCALE, angle: k.tilt)
    Presenter(handR: mix(mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, -0.2)), k.handle, k.reach))
    Callout(x: MUG.x, y: Y - 330, text: n.t("bloom.callout", "Bloom for 20 seconds (time shortened)"), at: timerAt)
    g(opacity: interpolate(n.frame, [timerAt - 6, timerAt + 4], [0, 1], .clamp)) {
      circle(cx: timer.x, cy: timer.y, r: 92, fill: palette.cream, stroke: palette.ink, strokeWidth: 5)
      Draw(d: circlePath(timer.x, timer.y, 70), progress: 1, color: "#e3dccb", width: 12)
      if tp > 0 { Draw(d: arcPath(timer.x, timer.y, 70, -90, -90 + 359.9 * tp), progress: 1, color: palette.primary, width: 12) }
      CountUp(at: timerAt, to: 20, durSec: max(0.5, (n.endOf(1) - timerAt) / n.fps), suffix: "s", x: timer.x, y: timer.y, size: 48, weight: 900, color: palette.ink)
    }
  }
}
