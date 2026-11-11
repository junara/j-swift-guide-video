// Get ready: "a mug," → "a drip coffee bag and a kettle." で道具が置かれ、2 行目で湯を沸かして 90℃ まで冷ます
import JGVKit

func Prepare(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let drop = { (at: Double) in spring(frame: n.frame - at, fps: n.fps, damping: 13, stiffness: 140) }
  let mugIn = drop(n.atPhrase(0, 0, 0.1))
  let bagIn = drop(n.atPhrase(0, 1, 0.1))
  let kettleIn = drop(n.atPhrase(0, 1, 0.9))
  let boilAt = n.at(1)
  let cool = interpolate(n.frame, [n.at(1, 1.2), n.endOf(1)], [0, 1], .clamp)
  let gauge = Pt(KETTLE_REST.x, Y - 330)

  Stage {
    Shadow(x: MUG.x, w: 250 * mugIn)
    Mug(x: MUG.x, y: Y - (1 - mugIn) * 320)
    Shadow(x: 790, w: 150 * bagIn)
    DripBag(x: 790, y: Y - (1 - bagIn) * 320, scale: 0.85)
    Shadow(x: KETTLE_REST.x, w: 220 * kettleIn)
    g(opacity: kettleIn) {
      Kettle(x: KETTLE_REST.x, y: Y - (1 - kettleIn) * 320, scale: KETTLE_SCALE)
    }
    if n.frame >= boilAt { Steam(x: KETTLE_REST.x + 150, y: Y - 140, count: 3, height: 150, opacity: 0.6 * (1 - cool * 0.6)) }
    Presenter(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, -0.2)))
    // 温度計: 100℃ → 90℃
    if n.frame >= boilAt {
      g(opacity: n.ease(1)) {
        rect(x: gauge.x - 130, y: gauge.y - 46, width: 260, height: 92, rx: 46, fill: "#fff", stroke: palette.ink, strokeWidth: 4)
        CountUp(at: n.at(1, 1.2), from: 100, to: 90, durSec: max(0.5, (n.endOf(1) - n.at(1, 1.2)) / n.fps), suffix: "°C", x: gauge.x, y: gauge.y, size: 48, weight: 900, color: cool > 0.95 ? palette.primary : palette.accent)
      }
    }
    Callout(x: 980, y: Y - 300, text: n.t("prepare.callout", "Prepare your tools and hot water"), at: n.atPhrase(0, 1, 0.4))
  }
}
