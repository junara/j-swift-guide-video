// jgv check で、描いた文字・注釈・字幕などの枠 (動画の座標) を描いた順に集める。
// 画像を見なくても「注釈が字幕バーに重なる」「チェックがボタンの文字に重なる」「注釈がカードに隠れる」「画面からはみ出す」が分かるように。
// 描くときに active でなければ何もしない (書き出しには影響しない)。check は 1 スレッドで描くので、ロックは取らない
import CoreGraphics
import Foundation

public enum LayoutProbe {
  public enum Kind: Sendable {
    /// binding・visual が描いた文字 (どうしの重なりは見ない)
    case text
    /// キューの注釈 (吹き出し・チェック・タイマー)
    case mark
    /// 枠 (見出し・工程バッジ・字幕バー・ポイントメモ・部品リスト・小手順ラベル)。どうしの重なりは見ない
    case chrome
    /// 拡大カードの台紙。先に描いた注釈が隠れるときだけ問題にする
    case cover
  }

  public struct Item {
    public var kind: Kind
    public var label: String
    /// 動画の座標 (y は下向き)。切り抜かれた所を除いた、見えている枠
    public var rect: CGRect
    /// 切り抜く前の枠 (画面からのはみ出しを見る)
    public var full: CGRect
  }

  /// ロックは無い: active にするのは jgv check だけで、check は 1 つのスレッドで順に描く (並列に描く経路では立てない)
  nonisolated(unsafe) public static var active = false
  /// 描いた順の枠 (1 フレームごとに空にしてから描く)
  nonisolated(unsafe) public static var items: [Item] = []
  /// 今の不透明度 (g(opacity:) の積)。出始め・消えかけで薄いものは記録しない
  nonisolated(unsafe) public static var alpha = 1.0
  /// 今の group (枠を記録した group の中の文字は記録しない。枠の無い group の中の文字は、その種類と名前で記録する)
  nonisolated(unsafe) static var groups: [(kind: Kind, label: String, boxed: Bool)] = []
  /// 注釈を出したキューの行など、名前の後ろに付ける説明
  nonisolated(unsafe) static var tags: [String] = []

  /// 出そろったものだけを見る (出入りの動きの途中の一瞬の重なりは問題にしない)
  static let minAlpha = 0.9

  /// body で描くものを 1 つのまとまりとして記録する。rect (今の座標) を渡すとその枠を記録し、中の文字は記録しない。
  /// rect が無ければ、中の文字を kind と label で記録する
  public static func group(_ kind: Kind, _ label: String, rect: CGRect? = nil, _ body: () -> Void) {
    guard active else { body(); return }
    if let rect { record(kind, label, rect) }
    groups.append((kind, label, rect != nil))
    defer { groups.removeLast() }
    body()
  }

  /// body で記録する名前の後ろに tag を付ける (例: キューの行番号 "L8 say")
  public static func tagged(_ tag: String, _ body: () -> Void) {
    guard active else { body(); return }
    tags.append(tag)
    defer { tags.removeLast() }
    body()
  }

  /// text() から呼ぶ。rect は今の座標の文字の枠
  static func text(_ s: String, rect: CGRect, opacity: Double) {
    guard active, opacity * alpha >= minAlpha else { return }
    if let g = groups.last {
      if g.boxed { return }
      record(g.kind, "\(g.label)「\(s)」", rect)
    } else {
      record(.text, "文字「\(s)」", rect)
    }
  }

  static func record(_ kind: Kind, _ label: String, _ r: CGRect) {
    guard alpha >= minAlpha, let c = RenderContext.currentOrNil else { return }
    let cg = c.cg
    // 今の座標 → 描き先 (CTM) → 動画の座標 (Bitmap.prepare の逆)。描いていない (切り抜かれた) 所は除く
    let s = Double(cg.width) / c.config.width
    let toDesign = cg.ctm.concatenating(CGAffineTransform(a: s, b: 0, c: 0, d: -s, tx: 0, ty: Double(cg.height)).inverted())
    // 注釈・枠は等倍で出そろう。大きさが変わっている途中 (飛び出す・縮んで消える) のものは記録しない
    if kind != .text && abs(sqrt(abs(toDesign.a * toDesign.d - toDesign.b * toDesign.c)) - 1) > 0.08 { return }
    let full = r.applying(toDesign)
    let d = full.intersection(cg.boundingBoxOfClipPath.applying(toDesign))
    if d.isNull || d.width <= 0 || d.height <= 0 { return }
    let name = tags.isEmpty ? label : "\(label) (\(tags.joined(separator: " ")))"
    items.append(Item(kind: kind, label: name, rect: d, full: full))
  }

  /// 1 フレームの枠から問題を見つける: (キー, 文)。キーは同じ問題を時刻をまたいでまとめるためのもの
  public static func problems(width: Double, height: Double) -> [(key: String, text: String)] {
    var out: [(String, String)] = []
    let canvas = CGRect(x: 0, y: 0, width: width, height: height).insetBy(dx: -2, dy: -2)
    for (i, a) in items.enumerated() {
      if (a.kind == .mark || a.kind == .chrome) && !canvas.contains(a.full) {
        out.append(("out|\(a.label)", "\(a.label) が画面からはみ出す"))
      }
      for b in items[(i + 1)...] where a.label != b.label {
        // a が先 (奥)、b が後 (手前) に描かれている
        let what: String
        switch (a.kind, b.kind) {
        case (.text, .text), (.chrome, .chrome), (.chrome, .cover), (.cover, .chrome), (.cover, .cover): continue
        case (.mark, .cover): what = "に隠れる"
        case (_, .cover), (.cover, _): continue
        default: what = "に重なる"
        }
        let x = a.rect.insetBy(dx: 2, dy: 2).intersection(b.rect.insetBy(dx: 2, dy: 2))
        guard !x.isNull, x.width * x.height > 80 else { continue }
        // 注釈を主語にする (注釈 → 枠 → 文字 の順)
        let rank: (Kind) -> Int = { $0 == .mark ? 0 : $0 == .chrome ? 1 : 2 }
        let (p, q) = what == "に隠れる" || rank(a.kind) <= rank(b.kind) ? (a, b) : (b, a)
        out.append(("\(p.label)|\(q.label)", "\(p.label) が \(q.label) \(what)"))
      }
    }
    return out
  }
}
