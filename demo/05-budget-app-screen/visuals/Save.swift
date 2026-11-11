// 記録する: 支払い方法を確認 → 「記録する」をタップ → 一覧の先頭に追加
import JGVKit

func Save(_ props: Props) {
  let n = useNarration()
  let tap = n.atPhrase(0, 1, 0.6)
  let p = pressAt(n.frame, n.fps, tap)
  let saved = n.frame > tap + 10
  let newRow = interpolate(n.frame, [n.at(1, 0), n.at(1, 0.6)], [0, 1], .clamp)
  let toast = interpolate(n.frame, [tap + 10, tap + 20, n.at(1, 1.5), n.at(1, 1.8)], [0, 1, 1, 0], .clamp)
  let spot = interpolate(n.frame, [n.atPhrase(0, 0), n.atPhrase(0, 0, 0.3), n.atPhrase(0, 1, -0.1), n.atPhrase(0, 1, 0.2)], [0, 1, 1, 0], .clamp)
  let finger = moveAlong(n.frame, n.fps, [
    (at: 0, p: toScreen(Pt(330, 700))),
    (at: tap - 14, p: toScreen(APP.save)),
    (at: tap + 18, p: toScreen(Pt(330, 680))),
  ])
  let state = saved
    ? BudgetState(page: .list, newRow: newRow)
    : BudgetState(page: .form, pressed: p.pressed ? "save" : nil, date: "2026/10/13", amount: "¥1,280", category: "外食", payFocus: spot > 0.5)
  Stage {
    PhoneFrame(x: PH.x, y: PH.y, h: PH.h) {
      BudgetScreen(s: state)
      UIBanner(x: 20, y: 60, w: 350, title: "記録しました", show: toast)
    }
    Spotlight(rect: Box(x: PH.x + 18 * K, y: PH.y + 466 * K, w: 354 * K, h: 78 * K), opacity: spot)
    Tap(x: finger.x, y: finger.y, press: p.t)
    StepNotes(x: NOTES.x, y: NOTES.y, w: NOTES.w, items: [
      (label: n.t("save.1", "支払い方法を確認"), at: n.at(0, -0.2)),
      (label: n.t("save.2", "「記録する」をタップ"), at: n.atPhrase(0, 1, -0.2)),
      (label: n.t("save.3", "一覧の先頭に表示"), at: n.at(1, -0.1)),
    ])
  }
}
