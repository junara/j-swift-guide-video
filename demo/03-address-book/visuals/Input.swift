// 連絡先を入力: 3 つの欄が光る → 名前 → メールアドレス → グループ (プルダウンで友人)
import JGVKit

func Input(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let nameAt = n.atPhrase(1, 1, 0.1)
  let emailAt = n.atPhrase(2, 1, 0.1)
  let groupClick = n.at(3, 0.3)
  let hoverAt = n.atPhrase(3, 1, 0.1)
  let pickAt = n.atPhrase(3, 1, 0.7)
  let c1 = clickAt(n.frame, n.fps, groupClick)
  let c2 = clickAt(n.frame, n.fps, pickAt)
  let picked = n.frame > pickAt + 4
  let cursor = moveCursor(n.frame, n.fps, [
    (at: 0, p: Pt(820, 470)),
    (at: n.at(1, -0.2), p: UI.name),
    (at: n.at(2, -0.2), p: UI.email),
    (at: n.at(3, -0.1), p: UI.group),
    (at: hoverAt - 6, p: UI.groupFriend),
    (at: pickAt + n.fps * 0.5, p: Pt(640, 450)),
  ])
  let focus: BookFocus? = n.frame >= n.at(3) ? .group : n.frame >= n.at(2) ? .email : n.frame >= n.at(1) ? .name : nil
  // 1 行目: 3 つの入力欄を順に枠で示す
  let fields: [(y: Double, w: Double)] = [
    (y: 197, w: 480),
    (y: 277, w: 480),
    (y: 357, w: 300),
  ]
  Stage {
    Presenter(handR: pointHand(n.ease(0, -0.3)))
    CloseUp(
      steps: [
        CloseUpStep("3つの項目を入力する", at: n.at(0, -0.2)),
        CloseUpStep("名前：山田 太郎", at: n.at(1, -0.1)),
        CloseUpStep("メールアドレス", at: n.at(2, -0.1)),
        CloseUpStep("グループ：友人", at: n.at(3, -0.1)),
      ],
      box: BIG_BOX
    ) {
      AddressBookUI(
        x: BROWSER.x,
        y: BROWSER.y,
        w: BROWSER.w,
        state: BookState(
          page: .form,
          url: "https://contacts.example.com/contacts/new",
          focus: focus,
          name: typed("山田 太郎", n.frame, nameAt, n.fps, 7),
          email: typed("taro.yamada@example.com", n.frame, emailAt, n.fps, 16),
          group: picked ? "友人" : "",
          groupOpen: n.frame >= groupClick + 3 && !picked ? 1 : 0,
          groupHover: n.frame >= hoverAt,
          cursor: BookCursor(x: cursor.x, y: cursor.y, click: max(c1.click, c2.click))
        )
      )
      if n.frame < n.at(1) {
        for (i, f) in fields.enumerated() {
          let a = toScreen(Pt(232, f.y - 8))
          let b = toScreen(Pt(248 + f.w, f.y + 54))
          Draw(d: rectPath(a.x, a.y, b.x - a.x, b.y - a.y, 12), progress: n.progress(0, 0.5, 0.2 + Double(i) * 0.35), color: palette.accent, width: 5)
        }
      }
    }
  }
}
