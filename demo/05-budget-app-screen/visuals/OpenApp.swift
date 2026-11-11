// アプリを開く: ホーム画面で家計簿アプリをタップ → 画面下の「レシートを記録」をタップ
import JGVKit

func OpenApp(_ props: Props) {
  let n = useNarration()
  let tapApp = n.atPhrase(0, 1, 0.4)
  let tapNew = n.atPhrase(1, 1, 0.6)
  let a = pressAt(n.frame, n.fps, tapApp)
  let b = pressAt(n.frame, n.fps, tapNew)
  let appOpen = interpolate(n.frame, [tapApp + 6, tapApp + 18], [0, 1], .clamp)
  let page: BudgetPage = appOpen >= 1 ? .list : .home
  let finger = moveAlong(n.frame, n.fps, [
    (at: 0, p: toScreen(Pt(300, 600))),
    (at: tapApp - 14, p: toScreen(APP.icon)),
    (at: tapApp + 20, p: toScreen(Pt(300, 600))),
    (at: tapNew - 14, p: toScreen(APP.newBtn)),
  ])
  let spot = interpolate(n.frame, [n.atPhrase(1, 0), n.atPhrase(1, 0, 0.3), tapNew + 10, tapNew + 20], [0, 1, 1, 0], .clamp)
  Stage {
    PhoneFrame(x: PH.x, y: PH.y, h: PH.h) {
      BudgetScreen(s: BudgetState(page: page, pressed: a.pressed ? "app" : b.pressed ? "new" : nil, appOpen: appOpen))
    }
    Spotlight(rect: Box(x: PH.x + 34 * K, y: PH.y + 734 * K, w: 322 * K, h: 72 * K), opacity: spot)
    Tap(x: finger.x, y: finger.y, press: max(a.t, b.t))
    StepNotes(x: NOTES.x, y: NOTES.y, w: NOTES.w, items: [
      (label: n.t("open.1", "家計簿アプリをタップ"), at: n.at(0, -0.2)),
      (label: n.t("open.2", "「レシートを記録」をタップ"), at: n.at(1, -0.2)),
    ])
  }
}
