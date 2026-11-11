// 新規登録画面: 右上の「新規登録」をクリック → 登録フォームが表示 (枠で強調)
import JGVKit

func NewForm(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let clickF = n.atPhrase(0, 1, 0.5)
  let c = clickAt(n.frame, n.fps, clickF)
  let opened = n.frame > clickF + n.fps * 0.35
  let cursor = moveCursor(n.frame, n.fps, [
    (at: 0, p: Pt(560, 330)),
    (at: n.atPhrase(0, 0, 0.1), p: UI.newBtn),
    (at: clickF + n.fps * 0.5, p: Pt(820, 420)),
  ])
  let a = toScreen(Pt(226, 172))
  let b = toScreen(Pt(734, 552))
  Stage {
    Presenter(handR: pointHand(n.ease(0, -0.3)))
    CloseUp(
      steps: [
        CloseUpStep("右上の「新規登録」をクリック", at: n.at(0, -0.2)),
        CloseUpStep("登録フォームが表示される", at: n.at(1, -0.1)),
      ],
      box: BIG_BOX
    ) {
      AddressBookUI(
        x: BROWSER.x,
        y: BROWSER.y,
        w: BROWSER.w,
        state: BookState(
          page: opened ? .form : .list,
          url: opened ? "https://contacts.example.com/contacts/new" : "https://contacts.example.com/contacts",
          rows: 4,
          press: c.pressed ? .newBtn : nil,
          cursor: BookCursor(x: cursor.x, y: cursor.y, click: c.click)
        )
      )
      Draw(d: rectPath(a.x, a.y, b.x - a.x, b.y - a.y, 14), progress: n.progress(1, 0.8, 0.1), color: palette.accent, width: 6, glow: true)
    }
  }
}
