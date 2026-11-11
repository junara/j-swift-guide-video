// 今月の支出を見る: アプリバーのグラフのボタンをタップ → 費目ごとの棒グラフが伸びる → 外食を強調し、予算の残りを確かめて完了
import Foundation
import JGVKit

func Summary(_ props: Props) {
  let n = useNarration()
  let tap = n.atPhrase(0, 0, 0.7)
  let p = pressAt(n.frame, n.fps, tap)
  let open = n.frame > tap + 8
  let bars = interpolate(n.frame, [tap + 12, tap + 42], [0, 1], .clamp(easing: { t in 1 - pow(1 - t, 3) }))
  let focus = interpolate(n.frame, [n.atPhrase(1, 0), n.atPhrase(1, 0, 0.3)], [0, 1], .clamp)
  let budgetAt = n.atPhrase(1, 1, 0.1)
  let budget = interpolate(n.frame, [budgetAt, budgetAt + 10], [0, 1], .clamp)
  let spot = interpolate(n.frame, [n.at(0), n.at(0, 0.3), tap, tap + 8], [0, 1, 1, 0], .clamp)
  let finger = moveAlong(n.frame, n.fps, [
    (at: 0, p: toScreen(Pt(300, 600))),
    (at: tap - 14, p: toScreen(APP.chart)),
    (at: tap + 20, p: toScreen(Pt(330, 820))),
  ])
  let state = open
    ? BudgetState(page: .summary, bars: bars, focus: focus, budget: budget)
    : BudgetState(page: .list, pressed: p.pressed ? "chart" : nil, newRow: 1)
  Stage {
    PhoneFrame(x: PH.x, y: PH.y, h: PH.h) {
      BudgetScreen(s: state)
    }
    Spotlight(rect: Box(x: PH.x + 322 * K, y: PH.y + 45 * K, w: 60 * K, h: 60 * K), opacity: spot, r: 30)
    Tap(x: finger.x, y: finger.y, press: p.t)
    CheckBadge(x: PH.x + 360, y: PH.y + 40, at: budgetAt + 10, r: 50)
    StepNotes(x: NOTES.x, y: NOTES.y, w: NOTES.w, items: [
      (label: n.t("summary.1", "グラフのボタンで今月の支出を開く"), at: n.at(0, -0.2)),
      (label: n.t("summary.2", "費目ごとの合計を確かめる"), at: n.at(1, -0.2)),
    ])
  }
}
