// この動画専用の道具: ノートPC (アドレス帳入り)、Web のアドレス帳の UI (ブラウザ)、カーソル、スマホ
// AddressBookUI は 960x560 の設計座標で描き、w に合わせて縮小する。クリック位置などは UI に設計座標でまとめる。
import JGVKit

private let FONT = "\"Hiragino Sans\", \"Hiragino Kaku Gothic ProN\", \"Noto Sans JP\", sans-serif"
private let MONO = "\"SF Mono\", Menlo, monospace"
let UI_W = 960.0
let UI_H = 560.0

/// 設計座標でのクリック位置・入力欄
let UI = Parts([
  "loginEmail": Pt(345, 225),
  "loginPw": Pt(345, 311),
  "loginBtn": Pt(480, 397),
  "menuContacts": Pt(100, 188),
  "newBtn": Pt(855, 141),
  "name": Pt(255, 220),
  "email": Pt(255, 300),
  "group": Pt(390, 380),
  "groupFriend": Pt(390, 471),
  "submitBtn": Pt(320, 514),
])

/// 文字列を at フレームから cps 文字/秒でタイプした途中の文字列
func typed(_ text: String, _ frame: Double, _ at: Double, _ fps: Double, _ cps: Double = 14) -> String {
  let chars = Array(text.unicodeScalars)
  let n = Int(max(0, min(Double(chars.count), floor(((frame - at) / fps) * cps))))
  var s = String.UnicodeScalarView()
  s.append(contentsOf: chars[0 ..< n])
  return String(s)
}

enum BookPage { case blank, login, home, list, form }
enum BookFocus { case loginEmail, loginPw, name, email, group }
enum BookPress { case loginBtn, newBtn, submitBtn, menuContacts }
struct BookCursor {
  var x: Double
  var y: Double
  var click: Double = 0 // 0〜1 で波紋
}

struct BookState {
  var page: BookPage
  var url: String? = nil
  var loginEmail: String? = nil
  var loginPw: Double? = nil // 入力済みの文字数 (●で表示)
  var focus: BookFocus? = nil
  var menuHot: Double? = nil // 左メニューの強調 0〜1
  var rows: Double? = nil // 一覧に表示する行数 (小数でスライドイン)
  var newRow: Double? = nil // 登録した連絡先の行 0〜1
  var name: String? = nil
  var email: String? = nil
  var group: String? = nil
  var groupOpen: Double? = nil // プルダウン 0〜1
  var groupHover: Bool? = nil
  var checks: Double? = nil // 確認のチェック数 0〜3
  var toast: Double? = nil // 0〜1
  var press: BookPress? = nil
  var cursor: BookCursor? = nil
}

private let CONTACTS = [
  ["佐藤 花子", "hanako.sato@example.com", "家族"],
  ["鈴木 一郎", "ichiro.suzuki@example.com", "友人"],
  ["高橋 美咲", "misaki.takahashi@example.com", "友人"],
  ["田中 健", "ken.tanaka@example.com", "家族"],
]

/// JS の真偽 (0 / undefined は偽)
private func truthy(_ v: Double?) -> Bool { (v ?? 0) != 0 }

private func Txt(_ s: String, x: Double, y: Double, size: Double = 20, weight: Double = 600, color: Paint = "#353b35", anchor: TextAnchor = .start, family: String = FONT) {
  text(s, x: x, y: y, fontSize: size, fontWeight: weight, fontFamily: family, fill: color, textAnchor: anchor, dominantBaseline: .central)
}

private func Field(x: Double, y: Double, w: Double, value: String? = nil, mono: Bool = false, focus: Bool = false, placeholder: String? = nil, caret: Bool = false) {
  let palette = useGuide().palette
  g {
    rect(x: x, y: y, width: w, height: 46, rx: 10, fill: "#fff", stroke: focus ? palette.primary : "#cfc8b8", strokeWidth: focus ? 4 : 2)
    if let value, !value.isEmpty {
      Txt(value + (caret ? "▍" : ""), x: x + 16, y: y + 23, size: mono ? 21 : 24, family: mono ? MONO : FONT)
    } else {
      Txt((placeholder ?? "") + (caret ? "▍" : ""), x: x + 16, y: y + 23, size: 21, weight: 500, color: "#b0a998")
    }
  }
}

private func Button(x: Double, y: Double, w: Double, h: Double = 52, label: String, pressed: Bool = false, outline: Bool = false) {
  let palette = useGuide().palette
  let s = pressed ? 0.94 : 1
  let cx = x + w / 2
  let cy = y + h / 2
  g(transform: [.translate(cx, cy), .scale(s), .translate(-cx, -cy)]) {
    rect(x: x, y: y, width: w, height: h, rx: 12, fill: outline ? "#fff" : palette.primary, stroke: outline ? "#cfc8b8" : "none", strokeWidth: 2)
    Txt(label, x: cx, y: cy, size: 23, weight: 800, color: outline ? "#5b625b" : "#fff", anchor: .middle)
  }
}

func Cursor(x: Double, y: Double, click: Double = 0) {
  g {
    if click > 0 && click < 1 { circle(cx: x, cy: y, r: 14 + click * 34, fill: "none", stroke: "#315e4a", strokeWidth: 4, opacity: 1 - click) }
    path("M 0 0 L 0 34 L 9 26 L 16 41 L 23 38 L 16 23 L 28 22 Z", fill: "#fff", stroke: "#353b35", strokeWidth: 3, strokeLinejoin: .round, transform: [.translate(x, y)])
  }
}

/// Web のアドレス帳のブラウザ (左上 x, y・幅 w)
func AddressBookUI(x: Double, y: Double, w: Double, state s: BookState) {
  let palette = useGuide().palette
  let k = w / UI_W
  let app = s.page == .home || s.page == .list || s.page == .form
  let activeMenu = s.page == .home ? 0 : 1
  g(transform: [.translate(x, y), .scale(k)]) {
    g(clip: .rect(x: 0, y: 0, width: UI_W, height: UI_H, rx: 18)) {
      rect(width: UI_W, height: UI_H, fill: "#fbf9f4")
      // ブラウザの枠
      rect(width: UI_W, height: 56, fill: "#ece7dc")
      for (i, c) in (["#e57b6b", "#e8b65a", "#79b77a"] as [Paint]).enumerated() {
        circle(cx: 28 + Double(i) * 24, cy: 28, r: 8, fill: c)
      }
      rect(x: 110, y: 13, width: 620, height: 30, rx: 15, fill: "#fff")
      Txt(s.url ?? "", x: 130, y: 28, size: 18, color: "#6b6f68", family: MONO)

      if s.page == .login {
        g {
          rect(x: 300, y: 96, width: 360, height: 410, rx: 18, fill: "#fff", stroke: "#e1dacb", strokeWidth: 2)
          Txt("アドレス帳にログイン", x: 480, y: 146, size: 28, weight: 800, anchor: .middle)
          Txt("メールアドレス", x: 330, y: 184, size: 20, color: "#6b6f68")
          Field(x: 330, y: 202, w: 300, value: s.loginEmail, mono: true, focus: s.focus == .loginEmail, caret: s.focus == .loginEmail)
          Txt("パスワード", x: 330, y: 270, size: 20, color: "#6b6f68")
          Field(x: 330, y: 288, w: 300, value: String(repeating: "●", count: Int(s.loginPw ?? 0)), focus: s.focus == .loginPw, caret: s.focus == .loginPw)
          Button(x: 330, y: 370, w: 300, h: 54, label: "ログイン", pressed: s.press == .loginBtn)
        }
      }

      if app {
        g {
          rect(y: 56, width: UI_W, height: 48, fill: "#fff")
          Txt("アドレス帳", x: 24, y: 80, size: 22, weight: 900, color: palette.primary)
          circle(cx: 920, cy: 80, r: 16, fill: palette.apron, stroke: "#cfc8b8", strokeWidth: 2)
          rect(y: 104, width: 200, height: UI_H - 104, fill: "#f1ece1")
          if truthy(s.menuHot) { rect(y: 104, width: 200, height: UI_H - 104, fill: palette.primary, opacity: 0.12 * (s.menuHot ?? 0)) }
          for (i, m) in ["ホーム", "連絡先", "設定"].enumerated() {
            let active = i == activeMenu
            let pressed = i == 1 && s.press == .menuContacts
            let my = Double(i) * 48
            g {
              if active || pressed { rect(x: 12, y: 120 + my, width: 176, height: 40, rx: 10, fill: palette.primary, opacity: pressed ? 0.35 : 0.18) }
              circle(cx: 34, cy: 140 + my, r: 7, fill: active ? palette.primary : "#a8a294")
              Txt(m, x: 52, y: 140 + my, size: 21, weight: active ? 800 : 600, color: active ? palette.primary : "#5b625b")
            }
          }
        }
      }

      if s.page == .home {
        g {
          Txt("ホーム", x: 232, y: 145, size: 28, weight: 800)
          for i in 0 ..< 3 {
            rect(x: 232 + Double(i) * 238, y: 186, width: 218, height: 120, rx: 14, fill: "#fff", stroke: "#e1dacb", strokeWidth: 2)
          }
        }
      }

      if s.page == .list {
        g {
          Txt("連絡先", x: 232, y: 145, size: 28, weight: 800)
          Button(x: 780, y: 118, w: 150, h: 46, label: "＋ 新規登録", pressed: s.press == .newBtn)
          rect(x: 232, y: 186, width: 698, height: 40, rx: 8, fill: "#ece7dc")
          let hx: [Double] = [252, 420, 780]
          for (i, h) in ["名前", "メールアドレス", "グループ"].enumerated() {
            Txt(h, x: hx[i], y: 206, size: 19, weight: 800, color: "#5b625b")
          }
          for (i, u) in CONTACTS.enumerated() {
            let t = min(1, max(0, (s.rows ?? 0) - Double(i)))
            if t > 0 {
              let ry = Double(i) * 50
              g(opacity: t, transform: [.translate((1 - t) * 40, 0)]) {
                Txt(u[0], x: 252, y: 250 + ry, size: 21)
                Txt(u[1], x: 420, y: 250 + ry, size: 18, color: "#5b625b", family: MONO)
                Txt(u[2], x: 780, y: 250 + ry, size: 19)
                line(x1: 232, y1: 275 + ry, x2: 930, y2: 275 + ry, stroke: "#e7e1d4", strokeWidth: 2)
              }
            }
          }
          if truthy(s.newRow) {
            g(opacity: s.newRow ?? 0) {
              rect(x: 232, y: 428, width: 698, height: 44, rx: 8, fill: palette.primary, opacity: 0.14)
              Txt("山田 太郎", x: 252, y: 450, size: 21, weight: 800)
              Txt("taro.yamada@example.com", x: 420, y: 450, size: 18, family: MONO)
              Txt("友人", x: 780, y: 450, size: 19, weight: 800)
            }
          }
        }
      }

      if s.page == .form {
        g {
          Txt("連絡先の登録", x: 232, y: 145, size: 28, weight: 800)
          for (label, fy) in [("名前", 179.0), ("メールアドレス", 259.0), ("グループ", 339.0)] {
            Txt(label, x: 240, y: fy, size: 20, color: "#6b6f68")
          }
          Field(x: 240, y: 197, w: 480, value: s.name, focus: s.focus == .name, placeholder: "山田 太郎", caret: s.focus == .name)
          Field(x: 240, y: 277, w: 480, value: s.email, mono: true, focus: s.focus == .email, placeholder: "name@example.com", caret: s.focus == .email)
          Field(x: 240, y: 357, w: 300, value: s.group, focus: s.focus == .group, placeholder: "選択してください")
          path("M 512 374 l 10 12 l 10 -12", fill: "none", stroke: "#6b6f68", strokeWidth: 3, strokeLinecap: .round)
          // 確認のチェック
          let checks = s.checks ?? 0
          for (i, cy) in [220.0, 300.0, 380.0].enumerated() where checks > Double(i) {
            g(opacity: min(1, checks - Double(i))) {
              circle(cx: 760, cy: cy, r: 18, fill: palette.primary)
              path("M \(750) \(cy) l 7 7 l 13 -14", fill: "none", stroke: "#fff", strokeWidth: 4, strokeLinecap: .round, strokeLinejoin: .round)
            }
          }
          Button(x: 240, y: 488, w: 160, label: "登録", pressed: s.press == .submitBtn)
          Button(x: 420, y: 488, w: 160, label: "キャンセル", outline: true)
          // グループのプルダウン
          if truthy(s.groupOpen) {
            let open = s.groupOpen ?? 0
            let hover = s.groupHover ?? false
            g(opacity: open, transform: [.translate(0, (1 - open) * -10)]) {
              rect(x: 240, y: 405, width: 300, height: 90, rx: 10, fill: "#fff", stroke: "#cfc8b8", strokeWidth: 2)
              Txt("家族", x: 256, y: 427, size: 21)
              if hover { rect(x: 244, y: 451, width: 292, height: 40, rx: 8, fill: palette.primary, opacity: 0.18) }
              Txt("友人", x: 256, y: 471, size: 21, weight: hover ? 800 : 600)
            }
          }
        }
      }

      // 完了のトースト
      if truthy(s.toast) {
        let toast = s.toast ?? 0
        g(opacity: min(1, toast * 2), transform: [.translate(0, (1 - toast) * -40)]) {
          rect(x: 300, y: 62, width: 440, height: 58, rx: 14, fill: "#2f8f5b")
          circle(cx: 334, cy: 91, r: 14, fill: "#fff")
          path("M 327 91 l 5 5 l 10 -10", fill: "none", stroke: "#2f8f5b", strokeWidth: 4, strokeLinecap: .round, strokeLinejoin: .round)
          Txt("連絡先を登録しました", x: 360, y: 91, size: 22, weight: 800, color: "#fff")
        }
      }

      if let c = s.cursor { Cursor(x: c.x, y: c.y, click: c.click) }
    }
    rect(width: UI_W, height: UI_H, rx: 18, fill: "none", stroke: palette.ink, strokeWidth: 5 / k)
  }
}

// ---------- ノートPC (原点 = 底の中心) ----------
/// screen は画面の左上 (幅は LAPTOP_SCREEN_W)
let LAPTOP_PARTS = Parts(["keysL": Pt(-80, -16), "keysR": Pt(80, -16), "screen": Pt(-214, -318)])
let LAPTOP_SCREEN_W = 428.0

func Laptop(x: Double, y: Double, scale: Double = 1, angle: Double = 0, state: BookState? = nil, on: Double = 1) {
  let sc = LAPTOP_PARTS.screen
  g {
    Placed(x: x, y: y, scale: scale, angle: angle) {
      rect(x: -232, y: -334, width: 464, height: 296, rx: 16, fill: "#3a403d")
      rect(x: sc.x, y: sc.y, width: LAPTOP_SCREEN_W, height: 250, rx: 6, fill: "#1f2422", strokeWidth: 3)
      path("M -284 0 L -246 -38 L 246 -38 L 284 0 Z", fill: "#cfd4d1")
      path("M -200 -26 H 200 M -210 -14 H 210", stroke: "#a9afab", strokeWidth: 4)
    }
    if var state {
      g(opacity: on, transform: [.translate(x, y), .rotate(angle), .scale(scale)]) {
        state.cursor = nil
        AddressBookUI(x: sc.x, y: sc.y + 4, w: LAPTOP_SCREEN_W, state: state)
      }
    }
  }
}

// ---------- 封筒 ----------
/// 拡大カードを大きめに使う (画面 UI 用) と、その中のブラウザ位置
let BIG_BOX = Box(x: 560, y: 215, w: 1290, h: 600)
let BROWSER = Box(x: 760, y: 287, w: 890, h: 0)
/// 設計座標 → 画面座標 (拡大カード内のブラウザ)
func toScreen(_ p: Pt) -> Pt { Pt(BROWSER.x + (p.x * BROWSER.w) / UI_W, BROWSER.y + (p.y * BROWSER.w) / UI_W) }

/// カーソルの移動: points を順にたどる (各区間 0.4 秒でなめらかに移動)
func moveCursor(_ frame: Double, _ fps: Double, _ points: [(at: Double, p: Pt)]) -> Pt {
  var cur = points[0].p
  for i in 1 ..< points.count {
    let (at, p) = points[i]
    let t = min(1, max(0, (frame - at) / (fps * 0.4)))
    let e = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    cur = Pt(cur.x + (p.x - cur.x) * e, cur.y + (p.y - cur.y) * e)
  }
  return cur
}

/// クリックの波紋 (at から 0.35 秒で 0→1)。押下中は pressed = true
func clickAt(_ frame: Double, _ fps: Double, _ at: Double) -> (click: Double, pressed: Bool) {
  let t = (frame - at) / (fps * 0.35)
  return (t > 0 && t < 1 ? t : 0, t >= 0 && t < 0.4)
}
