// 注意事項: 同じメールアドレスは登録できない (×) → 登録した連絡先がスマホのアプリにも同期される (PC からスマホへ点が流れる)
import Foundation
import JGVKit

private let Y = GUIDE.counterY
private let MONO = "\"SF Mono\", Menlo, monospace"

func Notes(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let card = Pt(1440, 470)
  let cardOut = n.ease(1, -0.1)
  // 2 行目: PC の画面から右のスマホへ点が流れ、スマホに新しい連絡先が出る
  let flyFrom = n.atPhrase(1, 1, -0.2)
  let fly = interpolate(n.frame, [flyFrom, flyFrom + 24], [0, 1], .clamp)
  let e = 1 - pow(1 - fly, 3)
  let start = Pt(900, 600)
  let end = Pt(1440, 520)
  let ctrl = Pt(1170, 300)
  let path = "M \(start.x) \(start.y) Q \(ctrl.x) \(ctrl.y) \(end.x) \(end.y)"
  let phone = (h: 300.0, w: (300 * PHONE.w) / PHONE.h)
  Stage {
    Shadow(x: 900, w: 560)
    Laptop(x: 900, y: Y, state: BookState(page: .list, url: "https://contacts.example.com/contacts", rows: 4, newRow: 1))
    Presenter(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, -0.2)))
    // 1 行目: 重複は登録できない
    g(opacity: 1 - cardOut) {
      Pop(at: n.at(0, 0.1), x: card.x, y: card.y) {
        rect(x: -250, y: -150, width: 500, height: 300, rx: 28, fill: "#fff", stroke: palette.ink, strokeWidth: 5, filter: .shadow)
        T("メールアドレスの重複", x: 0, y: -100, size: 30, weight: 900, color: palette.ink)
        T("taro.yamada@example.com", x: -210, y: -30, size: 24, weight: 700, color: palette.ink, anchor: .start, family: MONO)
        T("taro.yamada@example.com", x: -210, y: 30, size: 24, weight: 700, color: "#b9b2a2", anchor: .start, family: MONO)
        line(x1: -215, y1: 30, x2: 150, y2: 30, stroke: "#d14b3b", strokeWidth: 5, opacity: n.progress(0, 0.4, 1.0))
        g(opacity: n.progress(0, 0.3, 1.2)) {
          circle(cx: 195, cy: 30, r: 26, fill: "#d14b3b")
          JGVKit.path("M 183 18 L 207 42 M 207 18 L 183 42", stroke: "#fff", strokeWidth: 6, strokeLinecap: .round)
        }
        T("重複登録はできません", x: 0, y: 100, size: 28, weight: 900, color: "#d14b3b")
      }
    }
    // 2 行目: スマホのアプリにも同期
    if n.frame >= flyFrom { FlowDots(d: path, count: 4, speed: 0.8, r: 7, color: palette.accent, opacity: 1 - fly * 0.6) }
    if n.frame >= flyFrom {
      g(opacity: e, transform: [.translate(0, (1 - e) * 40)]) {
        PhoneFrame(x: end.x - phone.w / 2, y: end.y - phone.h / 2, h: phone.h) {
          rect(width: PHONE.w, height: PHONE.h, fill: "#fbf9f4")
          UIAppBar(title: "アドレス帳", width: PHONE.w)
          UIListRow(x: 0, y: 120, w: PHONE.w, title: "山田 太郎", sub: "友人", highlight: interpolate(n.frame, [flyFrom + 24, flyFrom + 34], [0, 1], .clamp))
          UIListRow(x: 0, y: 192, w: PHONE.w, title: "佐藤 花子", sub: "家族")
          UIListRow(x: 0, y: 264, w: PHONE.w, title: "鈴木 一郎", sub: "友人")
        }
      }
    }
    Pop(at: flyFrom + 22, x: end.x, y: end.y + 200) {
      T("スマホにも同期されます", x: 0, y: 0, size: 32, weight: 900, color: palette.ink)
    }
    CheckBadge(x: end.x + 130, y: end.y - 150, at: flyFrom + 30, r: 44)
  }
}
