// はじめに: ノートPCが置かれて画面が点く → 「アカウントが必要」のバッジ
import JGVKit

private let Y = GUIDE.counterY

func Intro(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let drop = spring(frame: n.frame - n.atPhrase(0, 0, 0.1), fps: n.fps, damping: 13, stiffness: 140)
  let on = interpolate(n.frame, [n.atPhrase(0, 1), n.atPhrase(0, 1, 0.5)], [0, 1], .clamp)
  let badge = Pt(1450, 520)
  Stage {
    Shadow(x: 900, w: 560 * drop)
    Laptop(x: 900, y: Y - (1 - drop) * 320, state: BookState(page: .login, url: "https://contacts.example.com"), on: on)
    Presenter(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, 0.2)))
    Pulse(x: badge.x, y: badge.y, r: 130, color: palette.primary, period: 1.8, active: n.isSpeaking(1))
    Pop(at: n.at(1, 0.1), x: badge.x, y: badge.y) {
      rect(x: -170, y: -80, width: 340, height: 160, rx: 28, fill: "#fff", stroke: palette.ink, strokeWidth: 5, filter: .shadow)
      Icon(name: "shield", x: -95, y: 0, size: 96, progress: (n.frame - n.at(1, 0.2)) / 18, color: palette.primary, strokeWidth: 2.2)
      T("アカウント", x: -30, y: -18, size: 30, weight: 900, color: palette.ink, anchor: .start)
      T("が必要です", x: -30, y: 26, size: 24, weight: 700, color: palette.primary, anchor: .start)
    }
  }
}
