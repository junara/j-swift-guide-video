// ログイン: ブラウザで開く → メールとパスワードを入力 → 「ログイン」をクリック
import Foundation
import JGVKit

func Login(_ props: Props) {
  let n = useNarration()
  let url = "https://contacts.example.com"
  let urlAt = n.atPhrase(0, 0, 0.3)
  let urlDone = urlAt + ceil((Double(url.unicodeScalars.count) / 22) * n.fps)
  let emailAt = n.atPhrase(1, 0, 0.5)
  let email = "me@example.com"
  let pwAt = emailAt + jsRound(n.fps * 1.3)
  let btnAt = n.atPhrase(1, 1, 0.5)
  let c = clickAt(n.frame, n.fps, btnAt)
  let after = n.frame > btnAt + n.fps * 0.45
  let cursor = moveCursor(n.frame, n.fps, [
    (at: 0, p: Pt(700, 520)),
    (at: emailAt - 12, p: UI.loginEmail),
    (at: pwAt - 10, p: UI.loginPw),
    (at: btnAt - 12, p: UI.loginBtn),
  ])
  var state: BookState = after
    ? BookState(page: .home, url: "https://contacts.example.com/home")
    : BookState(
      page: n.frame >= urlDone ? .login : .blank,
      url: typed(url, n.frame, urlAt, n.fps, 22),
      loginEmail: typed(email, n.frame, emailAt, n.fps, 18),
      loginPw: max(0, min(8, floor(((n.frame - pwAt) / n.fps) * 16))),
      focus: n.frame >= pwAt - 4 ? .loginPw : n.frame >= emailAt - 4 ? .loginEmail : nil,
      press: c.pressed ? .loginBtn : nil
    )
  state.cursor = n.frame >= urlDone ? BookCursor(x: cursor.x, y: cursor.y, click: c.click) : nil
  Stage {
    Presenter(handR: pointHand(n.ease(0, -0.3)))
    CloseUp(
      steps: [
        CloseUpStep("ブラウザでアドレス帳を開く", at: n.at(0, -0.2)),
        CloseUpStep("メールアドレスとパスワードを入力", at: n.atPhrase(1, 0, -0.2)),
        CloseUpStep("「ログイン」をクリック", at: n.atPhrase(1, 1, -0.2)),
      ],
      box: BIG_BOX
    ) {
      AddressBookUI(x: BROWSER.x, y: BROWSER.y, w: BROWSER.w, state: state)
    }
  }
}
