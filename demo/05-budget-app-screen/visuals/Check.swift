// 内容を確認: 日付と金額が自動で入る (スキャン線) → チェック → 費目のプルダウンで「外食」
import JGVKit

func Check(_ props: Props) {
  let n = useNarration()
  let readAt = n.atPhrase(0, 0, 0.3)
  let auto = interpolate(n.frame, [readAt, readAt + 10], [0, 1], .clamp)
  let checks = interpolate(n.frame, [n.atPhrase(1, 0, 0.1), n.atPhrase(1, 0, 0.9)], [0, 2], .clamp)
  let openAt = n.atPhrase(1, 1, 0.1)
  let pickAt = n.atPhrase(1, 1, 0.9)
  let o = pressAt(n.frame, n.fps, openAt)
  let k = pressAt(n.frame, n.fps, pickAt)
  let picked = n.frame > pickAt + 3
  let finger = moveAlong(n.frame, n.fps, [
    (at: 0, p: toScreen(Pt(330, 700))),
    (at: openAt - 12, p: toScreen(APP.category)),
    (at: pickAt - 10, p: toScreen(APP.categoryEatOut)),
    (at: pickAt + 16, p: toScreen(Pt(330, 700))),
  ])
  // スキャン線 (読み取り中)
  let scan = interpolate(n.frame, [readAt, readAt + 24], [0, 1], .clamp)
  // 入力欄だけを明るく
  let spot = interpolate(n.frame, [n.at(0), n.at(0, 0.3), n.atPhrase(1, 1, -0.2), n.atPhrase(1, 1, 0.1)], [0, 1, 1, 0], .clamp)
  let state = BudgetState(
    page: .form,
    date: typed("2026/10/13", n.frame, readAt + 4, n.fps, 30),
    amount: typed("¥1,280", n.frame, readAt + 10, n.fps, 24),
    auto: auto,
    checks: checks,
    category: picked ? "外食" : "",
    categoryOpen: n.frame >= openAt + 4 && !picked ? 1 : 0,
    categoryHover: n.frame >= pickAt - 8
  )
  Stage {
    PhoneFrame(x: PH.x, y: PH.y, h: PH.h) {
      BudgetScreen(s: state)
      if scan > 0 && scan < 1 {
        rect(x: 10, y: 240 + scan * 150, width: 370, height: 4, fill: "#f2c14e", opacity: 0.9)
      }
    }
    Spotlight(rect: rectToScreen(APP.fields), opacity: spot)
    Tap(x: finger.x, y: finger.y, press: max(o.t, k.t))
    StepNotes(x: NOTES.x, y: NOTES.y, w: NOTES.w, items: [
      (label: n.t("check.1", "日付・金額は自動で入力"), at: n.at(0, -0.2)),
      (label: n.t("check.2", "内容が正しいか確認"), at: n.atPhrase(1, 0, -0.2)),
      (label: n.t("check.3", "費目を選ぶ（外食）"), at: n.atPhrase(1, 1, -0.2)),
    ])
  }
}
