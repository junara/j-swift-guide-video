// ガイド（手順書）レイアウトの配色と配置。座標は 1920x1080 基準。
import Foundation

public struct GuidePalette {
  public var ink: Paint // 輪郭線・文字
  public var primary: Paint // 服・バッジ・進捗
  public var accent: Paint // マグなどの差し色
  public var wallTop: Paint
  public var wallBottom: Paint
  public var windowRing: Paint
  public var windowGlass: Paint
  public var counter: Paint
  public var counterEdge: Paint
  public var floor: Paint
  public var skin: Paint
  public var hair: Paint
  public var apron: Paint
  public var cream: Paint
  public var metal: Paint

  /// 色の名前 (script.json の guide.palette のキー。SVG の素材の var(--ink) などにも使う)
  static let keys: [(String, WritableKeyPath<GuidePalette, Paint>)] = [
    ("ink", \.ink), ("primary", \.primary), ("accent", \.accent), ("wallTop", \.wallTop), ("wallBottom", \.wallBottom),
    ("windowRing", \.windowRing), ("windowGlass", \.windowGlass), ("counter", \.counter), ("counterEdge", \.counterEdge),
    ("floor", \.floor), ("skin", \.skin), ("hair", \.hair), ("apron", \.apron), ("cream", \.cream), ("metal", \.metal),
  ]

  /// 名前 → 色
  public var colors: [String: Paint] {
    Dictionary(uniqueKeysWithValues: GuidePalette.keys.map { ($0.0, self[keyPath: $0.1]) })
  }

  /// script.json の guide.palette で一部の色を差し替える (知らない名前は無視する)
  public func merged(_ overrides: [String: String]) -> GuidePalette {
    var p = self
    for (k, path) in GuidePalette.keys { if let v = overrides[k] { p[keyPath: path] = Paint(v) } }
    return p
  }
}

public let DEFAULT_PALETTE = GuidePalette(
  ink: "#353b35",
  primary: "#315e4a",
  accent: "#d98a5c",
  wallTop: "#f5f1e8",
  wallBottom: "#e8e9dc",
  windowRing: "#e0e5d5",
  windowGlass: "#faf8ef",
  counter: "#cbb18d",
  counterEdge: "#bda17b",
  floor: "#ebe6da",
  skin: "#f1bc98",
  hair: "#3d3a32",
  apron: "#ece2ca",
  cream: "#f8f4ea",
  metal: "#6f9488"
)

/// 範囲 (x, y, 幅, 高さ)
public struct Box: Equatable {
  public var x: Double, y: Double, w: Double, h: Double
  public init(x: Double, y: Double, w: Double, h: Double) { self.x = x; self.y = y; self.w = w; self.h = h }
}

public struct GuideHeader {
  public var x: Double, kickerY: Double, titleY: Double, badgeY: Double, titleSize: Double
}

public struct GuideSubtitle {
  public var x: Double, y: Double, w: Double, h: Double, size: Double
}

public struct GuideWindow {
  public var x: Double, y: Double, r: Double
}

public struct GuideLayout {
  /// カウンター天板の高さ (道具はここに置く)
  public var counterY: Double
  public var counterH: Double
  /// 人物の足元 (カウンター天板の位置)
  public var presenter: Pt
  /// 拡大カード
  public var closeUp: Box
  public var subtitle: GuideSubtitle
  public var progressY: Double
  public var creditY: Double
  public var header: GuideHeader
  public var window: GuideWindow
  public var plantX: Double
  /// 部屋以外の型で、道具・画面を置いてよい範囲
  public var content: Box
}

/// 横型 1920x1080 の配置
public let LAYOUT_LANDSCAPE = GuideLayout(
  counterY: 780,
  counterH: 90,
  presenter: Pt(380, 780),
  closeUp: Box(x: 640, y: 250, w: 960, h: 500),
  subtitle: GuideSubtitle(x: 100, y: 896, w: 1720, h: 84, size: 36),
  progressY: 1012,
  creditY: 1050,
  header: GuideHeader(x: 100, kickerY: 60, titleY: 124, badgeY: 184, titleSize: 54),
  window: GuideWindow(x: 1460, y: 400, r: 330),
  plantX: 1700,
  content: Box(x: 100, y: 230, w: 1720, h: 640)
)

/// 縦型 1080x1920 の配置 (上に部屋と人物、カウンターの下に拡大カード)
public let LAYOUT_PORTRAIT = GuideLayout(
  counterY: 1120,
  counterH: 90,
  presenter: Pt(250, 1120),
  closeUp: Box(x: 50, y: 1235, w: 980, h: 420),
  subtitle: GuideSubtitle(x: 50, y: 1680, w: 980, h: 130, size: 46),
  progressY: 1840,
  creditY: 1885,
  header: GuideHeader(x: 60, kickerY: 110, titleY: 185, badgeY: 262, titleSize: 58),
  window: GuideWindow(x: 790, y: 640, r: 260),
  plantX: 960,
  content: Box(x: 50, y: 320, w: 980, h: 1330)
)

/// 既定 (横型) の配置。縦型にも対応する visual は useStage() を使う
public let GUIDE = LAYOUT_LANDSCAPE

/// ガイドの型: room = 部屋と人物 / screen = 画面操作 / topdown = 手元俯瞰 / manual = 組み立て説明書
public enum GuideVariant: String { case room, screen, topdown, manual }

/// 言語に合ったフォント (日本語・中国語・韓国語以外は欧文フォントを優先)
public func fontForLang(_ lang: String = "ja-JP") -> String {
  if lang.hasPrefix("ja") { return "\"Hiragino Sans\", \"Hiragino Kaku Gothic ProN\", \"Noto Sans JP\", \"Yu Gothic\", sans-serif" }
  if lang.hasPrefix("zh") { return "\"PingFang SC\", \"Hiragino Sans GB\", \"Noto Sans SC\", sans-serif" }
  if lang.hasPrefix("ko") { return "\"Apple SD Gothic Neo\", \"Noto Sans KR\", sans-serif" }
  return "\"Helvetica Neue\", Helvetica, Arial, \"Hiragino Sans\", sans-serif"
}

/// 人物の見た目: male = 男性 / female = 女性 / neutral = 中性 (既定)。script.json の guide.presenter
public enum PresenterLook: String, CaseIterable { case male, female, neutral }

public struct GuideInfo {
  public var palette: GuidePalette
  /// 人物の見た目 (script.json の guide.presenter。既定は neutral)
  public var presenter: PresenterLook
  public var font: String
  public var layout: GuideLayout
  public var variant: GuideVariant
  public var lang: String
  public var kicker: String
  public var title: String
  public var credit: String
  /// 字幕バーを表示するか (script.json の style.captions)
  public var captions: Bool
  /// 説明文 (Callout・StepNotes・拡大カードの小手順ラベルなど) を表示するか (style.notes)
  public var notes: Bool
  public init(palette: GuidePalette = DEFAULT_PALETTE, font: String = fontForLang("ja-JP"), layout: GuideLayout = LAYOUT_LANDSCAPE,
              variant: GuideVariant = .room, lang: String = "ja-JP", kicker: String = "", title: String = "", credit: String = "",
              captions: Bool = true, notes: Bool = true, presenter: PresenterLook = .neutral) {
    self.palette = palette; self.presenter = presenter; self.font = font; self.layout = layout; self.variant = variant; self.lang = lang
    self.kicker = kicker; self.title = title; self.credit = credit; self.captions = captions; self.notes = notes
  }
}

/// ガイドの配色・配置・型 (NarratedVideo が provide する。無ければ既定値)
public func useGuide() -> GuideInfo { useContextValue(GuideInfo.self) ?? GuideInfo() }

/// 人物の手の定位置
public struct Pose {
  public var restL: Pt
  public var restR: Pt
  public var gestureR: Pt
}

/// 今の配置 (横型 / 縦型) と、人物の手の定位置。配置の値は st.counterY のように直接読める
@dynamicMemberLookup
public struct StageInfo {
  public var layout: GuideLayout
  public var pose: Pose
  public subscript<T>(dynamicMember kp: KeyPath<GuideLayout, T>) -> T { layout[keyPath: kp] }
}

public func useStage() -> StageInfo {
  let layout = useGuide().layout
  let p = layout.presenter
  return StageInfo(layout: layout, pose: Pose(
    restL: Pt(p.x - 30, p.y - 105),
    restR: Pt(p.x + 60, p.y - 100),
    gestureR: Pt(p.x + 260, p.y - 265)
  ))
}

/// 原点 (x, y)・倍率 scale・回転 angle(度) で配置した部品のローカル座標 p を、画面座標に変換
public func place(_ x: Double, _ y: Double, _ scale: Double, _ angle: Double, _ p: Pt) -> Pt {
  let a = angle * Double.pi / 180
  return Pt(x + (p.x * cos(a) - p.y * sin(a)) * scale, y + (p.x * sin(a) + p.y * cos(a)) * scale)
}

/// place() の逆: 部品のローカル座標 p (持ち手・先端など) を画面座標 at に合わせたときの原点 (x, y)
public func originFor(_ at: Pt, _ scale: Double, _ angle: Double, _ p: Pt) -> Pt {
  let q = place(0, 0, scale, angle, p)
  return Pt(at.x - q.x, at.y - q.y)
}

public struct GuideLabels {
  public var closeUp: String
  public var before: String
  public var after: String
  /// 部品リスト (PartsList) の見出し
  public var parts: String
}

/// UI の既定文言 (言語別)。before / after は BeforeAfter の見出し
private let LABELS: [String: GuideLabels] = [
  "ja": GuideLabels(closeUp: "拡大", before: "ビフォー", after: "アフター", parts: "部品"),
  "en": GuideLabels(closeUp: "A closer look", before: "Before", after: "After", parts: "Parts"),
  "zh": GuideLabels(closeUp: "放大看", before: "之前", after: "之后", parts: "零件"),
  "ko": GuideLabels(closeUp: "자세히 보기", before: "전", after: "후", parts: "부품"),
  "vi": GuideLabels(closeUp: "Cận cảnh", before: "Trước", after: "Sau", parts: "Linh kiện"),
  "uk": GuideLabels(closeUp: "Крупним планом", before: "До", after: "Після", parts: "Деталі"),
]
public func guideLabels(_ lang: String) -> GuideLabels { LABELS[String(lang.prefix(2))] ?? LABELS["en"]! }

/// 2 点の補間
public func mix(_ a: Pt, _ b: Pt, _ t: Double) -> Pt { Pt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t) }
