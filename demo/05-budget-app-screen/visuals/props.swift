// 家計簿アプリの画面 (スマホ 390x844 の設計座標)
import Foundation
import JGVKit

enum BudgetPage { case home, list, camera, form, summary }

struct BudgetState {
  var page: BudgetPage
  var pressed: String? = nil // "app" | "new" | "shutter" | "save" | "category" | "chart"
  var appOpen: Double? = nil // ホーム → アプリの拡大 (0〜1)
  var receipt: Double? = nil // カメラ: レシートが枠に合う (0〜1)
  var flash: Double? = nil
  var date: String? = nil
  var amount: String? = nil
  var auto: Double? = nil // 自動読み取りのバッジ (0〜1)
  var checks: Double? = nil // 確認チェック (0〜2)
  var category: String? = nil
  var categoryOpen: Double? = nil
  var categoryHover: Bool? = nil
  var payFocus: Bool? = nil
  var newRow: Double? = nil // 一覧に追加された行 (0〜1)
  var bars: Double? = nil // 今月の支出: 棒グラフが伸びる (0〜1)
  var focus: Double? = nil // 今月の支出: 外食の行を強調 (0〜1)
  var budget: Double? = nil // 今月の支出: 予算の残りの表示 (0〜1)
}

/// 設計座標でのタップ位置
let APP = (
  icon: Pt(125, 232),
  newBtn: Pt(195, 770),
  shutter: Pt(195, 760),
  category: Pt(195, 433),
  categoryEatOut: Pt(195, 528),
  pay: Pt(195, 513),
  save: Pt(195, 770),
  chart: Pt(352, 75),
  fields: Box(x: 24, y: 226, w: 342, h: 230)
)

/// 今月の支出 (外食には、この動画で記録した ¥1,280 を含む)
let MONTH = (
  total: "¥38,560",
  rows: [
    (label: "食費", value: 18400.0),
    (label: "外食", value: 7560.0),
    (label: "日用品", value: 5200.0),
    (label: "交通費", value: 4100.0),
    (label: "その他", value: 3300.0),
  ],
  focus: 1 // 外食
)
private func yen(_ v: Double) -> String {
  let s = String(Int(v))
  var out = ""
  for (i, c) in s.enumerated() {
    if i > 0 && (s.count - i) % 3 == 0 { out += "," }
    out.append(c)
  }
  return "¥" + out
}

private let ICONS: [(String, String)] = [
  ("写真", "#e7a15a"), ("家計簿", "#3b5f8f"), ("地図", "#6aa86f"), ("メール", "#5b8bd6"),
  ("カレンダー", "#d76b5b"), ("メモ", "#e8c35a"), ("天気", "#6cb6d9"), ("設定", "#8a8f94"),
]

private func Home(pressed: Bool = false) {
  rect(width: PHONE.w, height: PHONE.h, fill: .linear(LinearGradient(x1: 0, y1: 0, x2: 0, y2: 1, stops: [(0, "#c9dbe6"), (1, "#efe2cf")])))
  for (i, (label, color)) in ICONS.enumerated() {
    let x = 40 + Double(i % 4) * 85
    let y = 120 + Double(i / 4) * 112
    let isApp = label == "家計簿"
    let s = isApp && pressed ? 0.9 : 1
    g(transform: [.translate(x + 32, y + 32), .scale(s), .translate(-x - 32, -y - 32)]) {
      rect(x: x, y: y, width: 64, height: 64, rx: 16, fill: Paint(color))
      if isApp {
        UIText("¥", x: x + 32, y: y + 32, size: 34, weight: 900, color: "#fff", anchor: .middle)
      }
      UIText(label, x: x + 32, y: y + 82, size: 13, weight: 700, color: "#2b302d", anchor: .middle)
    }
  }
}

/// アプリバー右のグラフのボタン
private func ChartButton(pressed: Bool = false) {
  g(transform: [.translate(APP.chart.x, APP.chart.y), .scale(pressed ? 0.85 : 1)]) {
    circle(r: 20, fill: "#fff", opacity: pressed ? 0.35 : 0.18)
    for (x, y, h) in [(-9.0, 4.0, 8.0), (-2, -2, 14), (5, -8, 20)] {
      rect(x: x, y: y, width: 5, height: h, rx: 1.5, fill: "#fff")
    }
  }
}

private func List(s: BudgetState) {
  let rows: [(String, String, String, String, String)] = [
    ("食費", "10/12 スーパー", "¥2,460", "カード", "#5b8bd6"),
    ("日用品", "10/10 ドラッグストア", "¥980", "現金", "#4c9a6a"),
    ("交通費", "10/08 電車", "¥640", "カード", "#5b8bd6"),
  ]
  let nr = s.newRow ?? 0
  UIAppBar(title: "家計簿", width: PHONE.w)
  ChartButton(pressed: s.pressed == "chart")
  UIText("最近の記録", x: 24, y: 128, size: 15, weight: 800, color: "#8a8a7c")
  g(transform: [.translate(0, nr * 72)]) {
    for (i, r) in rows.enumerated() {
      UIListRow(x: 0, y: 150 + Double(i) * 72, w: PHONE.w, title: r.0, sub: r.1, right: r.2, badge: (text: r.3, color: Paint(r.4)))
    }
  }
  if nr > 0 {
    g(opacity: nr, transform: [.translate((1 - nr) * 60, 0)]) {
      UIListRow(x: 0, y: 150, w: PHONE.w, title: "外食", sub: "10/13 CAFE MORI", right: "¥1,280", badge: (text: "現金", color: "#4c9a6a"), highlight: 1)
    }
  }
  UIButton(x: 40, y: 740, w: 310, h: 60, label: "＋ レシートを記録", pressed: s.pressed == "new", size: 21)
}

private func CameraPage(s: BudgetState) {
  let r = s.receipt ?? 0
  let ok = r > 0.95
  let dx = (1 - r) * 70
  let rot = (1 - r) * -14
  let corner: Paint = ok ? "#5fd08a" : "#f2c14e"
  rect(width: PHONE.w, height: PHONE.h, fill: "#141716")
  g(transform: [.translate(195 + dx, 380), .rotate(rot)]) {
    rect(x: -110, y: -170, width: 220, height: 340, fill: "#fbfaf6")
    UIText("CAFE MORI", x: 0, y: -130, size: 18, weight: 900, anchor: .middle)
    UIText("2026/10/13 14:05", x: 0, y: -100, size: 13, color: "#6b6f68", anchor: .middle)
    for i in 0 ..< 3 {
      rect(x: -90, y: -60 + Double(i) * 34, width: 110, height: 10, rx: 5, fill: "#d6d0c2")
      rect(x: 50, y: -60 + Double(i) * 34, width: 40, height: 10, rx: 5, fill: "#d6d0c2")
    }
    line(x1: -90, y1: 60, x2: 90, y2: 60, stroke: "#bdb6a6", strokeWidth: 2, strokeDasharray: [6, 5])
    UIText("合計", x: -90, y: 92, size: 18, weight: 900)
    UIText("¥1,280", x: 90, y: 92, size: 22, weight: 900, anchor: .end)
  }
  // 枠
  for (x, y, sx, sy) in [(55.0, 190.0, 1.0, 1.0), (335, 190, -1, 1), (55, 570, 1, -1), (335, 570, -1, -1)] {
    path("M \(x) \(y + 40 * sy) V \(y) H \(x + 40 * sx)", fill: "none", stroke: corner, strokeWidth: 6, strokeLinecap: .round)
  }
  text(ok ? "レシートを認識しました" : "レシートを枠に合わせてください", x: 195, y: 640, fontSize: 15, fontWeight: 700, fill: ok ? "#5fd08a" : "#fff", textAnchor: .middle)
  circle(cx: 195, cy: 760, r: 38, fill: "none", stroke: "#fff", strokeWidth: 5)
  circle(cx: 195, cy: 760, r: s.pressed == "shutter" ? 26 : 30, fill: "#fff")
  if let f = s.flash, f != 0 { rect(width: PHONE.w, height: PHONE.h, fill: "#fff", opacity: f) }
}

private func Form(s: BudgetState) {
  let palette = useGuide().palette
  let checks = s.checks ?? 0
  let check = { (i: Double, y: Double) in
    if checks > i {
      g(opacity: min(1, checks - i)) {
        circle(cx: 350, cy: y, r: 13, fill: palette.primary)
        path("M 343 \(y) l 5 5 l 9 -10", fill: "none", stroke: "#fff", strokeWidth: 3, strokeLinecap: .round, strokeLinejoin: .round)
      }
    }
  }
  let auto = { (y: Double) in
    if let a = s.auto, a != 0 {
      g(opacity: a) {
        rect(x: 250, y: y - 12, width: 80, height: 24, rx: 12, fill: "#f2c14e")
        UIText("自動読取", x: 290, y: y, size: 12, weight: 800, anchor: .middle)
      }
    }
  }
  UIAppBar(title: "レシートを記録", width: PHONE.w, back: true)
  rect(x: 24, y: 118, width: 62, height: 84, fill: "#fbfaf6", stroke: "#cfc8b8", strokeWidth: 2)
  rect(x: 34, y: 134, width: 42, height: 6, rx: 3, fill: "#d6d0c2")
  rect(x: 34, y: 150, width: 30, height: 6, rx: 3, fill: "#d6d0c2")
  UIText("CAFE MORI のレシート", x: 102, y: 150, size: 15, weight: 700)
  UIText("撮影済み", x: 102, y: 176, size: 13, color: "#8a8a7c")
  UIField(x: 24, y: 248, w: 300, label: "日付", value: s.date, placeholder: "—")
  auto(271)
  check(0, 271)
  UIField(x: 24, y: 330, w: 300, label: "金額", value: s.amount, placeholder: "—")
  auto(353)
  check(1, 353)
  UIField(x: 24, y: 410, w: 342, label: "費目", value: s.category, placeholder: "選択してください", focus: (s.categoryOpen ?? 0) > 0, select: true)
  UIField(x: 24, y: 490, w: 342, label: "支払い方法", value: "現金", focus: s.payFocus ?? false)
  UIButton(x: 24, y: 740, w: 342, h: 60, label: "記録する", pressed: s.pressed == "save", size: 21)
  if let open = s.categoryOpen, open != 0 {
    let hover = s.categoryHover ?? false
    g(opacity: open) {
      rect(x: 24, y: 460, width: 342, height: 138, rx: 12, fill: "#fff", stroke: "#cfc8b8", strokeWidth: 2, filter: .shadow)
      for (i, o) in ["食費", "外食", "日用品"].enumerated() {
        let fi = Double(i)
        if hover && i == 1 { rect(x: 30, y: 466 + fi * 44, width: 330, height: 40, rx: 8, fill: palette.primary, opacity: 0.15) }
        UIText(o, x: 44, y: 486 + fi * 44, size: 17, weight: hover && i == 1 ? 800 : 600)
      }
    }
  }
}

private func SummaryPage(s: BudgetState) {
  let palette = useGuide().palette
  let max = MONTH.rows.map { $0.value }.max() ?? 1
  let bars = s.bars ?? 0
  let focus = s.focus ?? 0
  rect(width: PHONE.w, height: PHONE.h, fill: "#fbf9f4")
  UIAppBar(title: "今月の支出", width: PHONE.w, back: true)
  UIText("10月の合計", x: 24, y: 132, size: 15, weight: 800, color: "#8a8a7c")
  UIText(MONTH.total, x: 24, y: 176, size: 38, weight: 900)
  for (i, r) in MONTH.rows.enumerated() {
    let y = 236 + Double(i) * 84
    let hi = i == MONTH.focus ? focus : 0
    if hi > 0 { rect(x: 12, y: y - 6, width: 366, height: 72, rx: 12, fill: palette.accent, opacity: 0.16 * hi) }
    UIText(r.label, x: 24, y: y + 16, size: 18, weight: hi > 0.5 ? 900 : 700)
    UIText(yen(r.value), x: 366, y: y + 16, size: 18, weight: 800, anchor: .end)
    rect(x: 24, y: y + 34, width: 342, height: 16, rx: 8, fill: "#e6e0d3")
    let bw = Swift.max(0.01, (r.value / max) * 342 * bars)
    rect(x: 24, y: y + 34, width: bw, height: 16, rx: 8, fill: i == MONTH.focus && hi > 0.5 ? palette.accent : palette.primary)
  }
  if let b = s.budget, b != 0 {
    g(opacity: b) {
      rect(x: 24, y: 672, width: 342, height: 64, rx: 14, fill: "#fff", stroke: "#cfc8b8", strokeWidth: 2)
      UIText("予算 ¥40,000 まで あと ¥1,440", x: 195, y: 704, size: 17, weight: 800, anchor: .middle)
    }
  }
}

func BudgetScreen(s: BudgetState) {
  switch s.page {
  case .home:
    let k = s.appOpen ?? 0
    Home(pressed: s.pressed == "app")
    if k > 0 {
      g(opacity: min(1, k * 3), transform: [.translate(APP.icon.x * (1 - k), APP.icon.y * (1 - k)), .scale(0.16 + 0.84 * k)]) {
        rect(width: PHONE.w, height: PHONE.h, fill: "#fbf9f4")
        List(s: BudgetState(page: .list))
      }
    }
  case .list: List(s: s)
  case .camera: CameraPage(s: s)
  case .summary: SummaryPage(s: s)
  case .form: Form(s: s)
  }
}
