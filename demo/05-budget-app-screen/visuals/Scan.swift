// レシートを撮影: レシートを枠に合わせる (枠が緑に) → シャッターをタップ (フラッシュ)
import JGVKit

func Scan(_ props: Props) {
  let n = useNarration()
  let receipt = interpolate(n.frame, [n.atPhrase(0, 1), n.endOf(0)], [0, 1], .clamp)
  let shot = n.atPhrase(1, 0, 0.8)
  let p = pressAt(n.frame, n.fps, shot)
  let flash = interpolate(n.frame, [shot + 2, shot + 5, shot + 14], [0, 1, 0], .clamp)
  let finger = moveAlong(n.frame, n.fps, [
    (at: 0, p: toScreen(Pt(330, 820))),
    (at: shot - 14, p: toScreen(APP.shutter)),
    (at: shot + 16, p: toScreen(Pt(330, 820))),
  ])
  Stage {
    PhoneFrame(x: PH.x, y: PH.y, h: PH.h, dark: true) {
      BudgetScreen(s: BudgetState(page: .camera, pressed: p.pressed ? "shutter" : nil, receipt: receipt, flash: flash))
    }
    Tap(x: finger.x, y: finger.y, press: p.t)
    CheckBadge(x: PH.x + 330, y: PH.y + 120, at: shot + 12)
    StepNotes(x: NOTES.x, y: NOTES.y, w: NOTES.w, items: [
      (label: n.t("scan.1", "レシートを枠に合わせる"), at: n.at(0, -0.2)),
      (label: n.t("scan.2", "シャッターで撮影"), at: n.at(1, -0.2)),
    ])
  }
}
