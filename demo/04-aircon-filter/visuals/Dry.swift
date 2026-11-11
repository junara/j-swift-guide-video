// 乾燥 (拡大): 振って水気を切る → 直射日光は × → 風通しの良い日陰で乾かす (時間は短縮)
import JGVKit

func Dry(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let shaking = n.isSpeaking(0)
  let shake = shaking ? sin(n.frame * 1.1) * 8 : 0
  let F = (x: 1000.0 + (shaking ? 0 : 0), y: 540.0, scale: 1.1)
  let putDown = n.ease(1, -0.2)
  let pos = mix(Pt(F.x, F.y - 20), Pt(F.x, F.y + 20), putDown)
  let handle = place(pos.x, pos.y, F.scale, shake, Pt(FILTER_PARTS.handle.x, -FILTER_PARTS.handle.y))
  let dryAt = n.atPhrase(1, 2, -0.1)
  let dry = interpolate(n.frame, [dryAt, n.endOf(1)], [0, 1], .clamp)
  let sun = Pt(1430, 360)
  let timer = Pt(1430, 590)
  Stage {
    Presenter(handR: mix(Pt(440, 680), POINT, n.ease(0, -0.3)))
    CloseUp(steps: [
      CloseUpStep("水気を軽く切る", at: n.at(0, -0.2)),
      CloseUpStep("直射日光を避ける", at: n.atPhrase(1, 0, -0.2)),
      CloseUpStep("風通しの良い日陰で乾燥", at: n.atPhrase(1, 1, -0.2)),
    ]) {
      // 日陰 (ひさし) と風
      g(opacity: interpolate(n.frame, [n.atPhrase(1, 1, -0.1), n.atPhrase(1, 1, 0.3)], [0, 1], .clamp)) {
        path("M 760 300 L 1240 300 L 1200 360 L 800 360 Z", fill: "#8f9a8c", stroke: palette.ink, strokeWidth: 4)
        path("M 800 360 L 760 740 L 1240 740 L 1200 360 Z", fill: "#5d6b5c", opacity: 0.12)
        for i in 0 ..< 3 {
          let fi = Double(i)
          let k = jsMod(n.sec * 0.9 + fi / 3, 1)
          path("M \(700 + k * 560) \(450 + fi * 80) q 30 -14 60 0 q 30 14 60 0", fill: "none", stroke: "#8ab8c8", strokeWidth: 6, strokeLinecap: .round,
               opacity: sin(k * Double.pi))
        }
      }
      Filter(x: pos.x, y: pos.y, scale: F.scale, angle: shake, wet: 1 - dry)
      if shaking { Drips(x: pos.x, y: pos.y + 130, w: 320, fall: 110, count: 10, seed: "dry") }
      SleeveArm(from: Pt(1000, 260), to: handle, bend: 0, width: 34)
      // 直射日光は避ける
      g(opacity: n.ease(1, -0.1)) {
        Icon(name: "sun", x: sun.x, y: sun.y, size: 140, progress: n.progress(1, 0.6), color: "#e0a83a", strokeWidth: 2.2)
        Draw(d: circlePath(sun.x, sun.y, 82), progress: n.progress(1, 0.4, 0.4), color: "#d14b3b", width: 10)
        Draw(d: "M \(sun.x - 58) \(sun.y - 58) L \(sun.x + 58) \(sun.y + 58)", progress: n.progress(1, 0.3, 0.6), color: "#d14b3b", width: 10)
      }
      // 乾燥タイマー
      g(opacity: interpolate(n.frame, [dryAt - 6, dryAt + 4], [0, 1], .clamp)) {
        circle(cx: timer.x, cy: timer.y, r: 80, fill: palette.cream, stroke: palette.ink, strokeWidth: 5)
        Draw(d: circlePath(timer.x, timer.y, 60), progress: 1, color: "#e3dccb", width: 12)
        if dry > 0 { Draw(d: arcPath(timer.x, timer.y, 60, -90, -90 + 359.9 * dry), progress: 1, color: palette.primary, width: 12) }
        CountUp(at: dryAt, to: 100, durSec: max(0.5, (n.endOf(1) - dryAt) / n.fps), suffix: "%", x: timer.x, y: timer.y, size: 34, weight: 900, color: palette.ink)
      }
      Callout(x: timer.x, y: timer.y + 130, text: "乾燥時間は短縮しています", at: dryAt + 6)
    }
  }
}
