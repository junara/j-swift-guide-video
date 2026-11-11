// 登録する: 入力内容にチェック → 「登録」をクリック → 「連絡先を登録しました」と一覧の新しい行
import JGVKit

func Submit(_ props: Props) {
  let n = useNarration()
  let checks = interpolate(n.frame, [n.atPhrase(0, 0, 0.1), n.atPhrase(0, 0, 1.1)], [0, 3], .clamp)
  let clickF = n.atPhrase(0, 1, 0.8)
  let c = clickAt(n.frame, n.fps, clickF)
  let done = n.frame > clickF + n.fps * 0.4
  let toast = interpolate(n.frame, [n.at(1, -0.1), n.at(1, 0.3)], [0, 1], .clamp)
  let newRow = interpolate(n.frame, [n.at(1, 0.2), n.at(1, 0.8)], [0, 1], .clamp)
  let cursor = moveCursor(n.frame, n.fps, [
    (at: 0, p: Pt(640, 450)),
    (at: n.atPhrase(0, 1, 0.1), p: UI.submitBtn),
    (at: clickF + n.fps * 0.6, p: Pt(640, 500)),
  ])
  let state = done
    ? BookState(page: .list, url: "https://contacts.example.com/contacts", rows: 4, newRow: newRow, toast: toast)
    : BookState(
      page: .form,
      url: "https://contacts.example.com/contacts/new",
      name: "山田 太郎",
      email: "taro.yamada@example.com",
      group: "友人",
      checks: checks,
      press: c.pressed ? .submitBtn : nil,
      cursor: BookCursor(x: cursor.x, y: cursor.y, click: c.click)
    )
  Stage {
    Presenter(handR: pointHand(n.ease(0, -0.3)))
    CloseUp(
      steps: [
        CloseUpStep("入力内容を確認", at: n.at(0, -0.2)),
        CloseUpStep("「登録」をクリック", at: n.atPhrase(0, 1, -0.2)),
        CloseUpStep("登録完了", at: n.at(1, -0.1)),
      ],
      box: BIG_BOX
    ) {
      AddressBookUI(x: BROWSER.x, y: BROWSER.y, w: BROWSER.w, state: state)
      CheckBadge(x: BIG_BOX.x + BIG_BOX.w - 70, y: BIG_BOX.y + 70, at: n.at(1, 0.4), r: 46)
    }
  }
}
