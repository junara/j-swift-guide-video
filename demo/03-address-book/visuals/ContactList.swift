// 連絡先の一覧: 左のメニューが光る → 「連絡先」をクリック → 一覧が順に表示
import Foundation
import JGVKit

func ContactList(_ props: Props) {
  let n = useNarration()
  let hotFrom = n.atPhrase(0, 0)
  let clickF = n.atPhrase(0, 1, 0.5)
  let c = clickAt(n.frame, n.fps, clickF)
  let opened = n.frame > clickF + n.fps * 0.35
  let menuHot = n.frame >= hotFrom && n.frame < clickF ? 0.5 + 0.5 * sin((n.frame - hotFrom) * 0.35) : 0
  let rows = interpolate(n.frame, [n.at(1), n.endOf(1)], [0, 4], .clamp)
  let cursor = moveCursor(n.frame, n.fps, [
    (at: 0, p: Pt(520, 300)),
    (at: n.atPhrase(0, 1, -0.2), p: UI.menuContacts),
    (at: clickF + n.fps * 0.6, p: Pt(600, 470)),
  ])
  Stage {
    Presenter(handR: pointHand(n.ease(0, -0.3)))
    CloseUp(
      steps: [
        CloseUpStep("画面左側のメニュー", at: n.at(0, -0.2)),
        CloseUpStep("「連絡先」をクリック", at: n.atPhrase(0, 1, -0.2)),
        CloseUpStep("連絡先の一覧が表示される", at: n.at(1, -0.1)),
      ],
      box: BIG_BOX
    ) {
      AddressBookUI(
        x: BROWSER.x,
        y: BROWSER.y,
        w: BROWSER.w,
        state: BookState(
          page: opened ? .list : .home,
          url: opened ? "https://contacts.example.com/contacts" : "https://contacts.example.com/home",
          menuHot: menuHot,
          rows: rows,
          press: c.pressed ? .menuContacts : nil,
          cursor: BookCursor(x: cursor.x, y: cursor.y, click: c.click)
        )
      )
    }
  }
}
