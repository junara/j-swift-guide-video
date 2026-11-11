// 描画中の状態 (描き先・継承する線や塗りの属性・フレーム・Context の値)。
// 1 フレームは 1 つのスレッドで描くので、今の描画先はスレッドごとに持つ (RenderContext.current)。
// 部品は引数で描き先を受け取らず、path(…) / g { … } / useCurrentFrame() のように今の描画先に描く
import CoreGraphics
import Foundation

public enum LineCap: Sendable { case butt, round, square }
public enum LineJoin: Sendable { case miter, round, bevel }
public enum TextAnchor: Sendable { case start, middle, end }
public enum DominantBaseline: Sendable { case alphabetic, central, middle, hanging, textTop, textBottom }
public enum FillRule: Sendable { case nonzero, evenodd }

/// g・図形に付けられる効果 (SVG の filter="url(#kit-shadow)" / "url(#kit-glow)")
public enum Filter: Sendable {
  /// 下に落ちる影 (dx, dy, ぼかしの標準偏差, 色)。kit の影は .shadow()
  case dropShadow(dx: Double, dy: Double, std: Double, color: RGBA)
  /// 周りがぼんやり光る (ぼかしの標準偏差, 光の色。nil なら線の色)
  case glow(std: Double, color: RGBA?)
  /// kit-shadow: 下に 10px、ぼかし 14、黒の 35%
  public static let shadow = Filter.dropShadow(dx: 0, dy: 10, std: 14, color: RGBA(0, 0, 0, 0.35))
  /// kit-glow: ぼかし 8
  public static let glow = Filter.glow(std: 8, color: nil)
}

/// 継承する描画の属性 (SVG の g に付けた fill・stroke などが子要素に引き継がれるのと同じ)
public struct DrawStyle {
  public var fill: Paint = .black
  public var stroke: Paint = .none
  public var strokeWidth: Double = 1
  public var strokeLinecap: LineCap = .butt
  public var strokeLinejoin: LineJoin = .miter
  public var strokeDasharray: [Double]? = nil
  public var strokeDashoffset: Double = 0
  public var fillRule: FillRule = .nonzero
  public var fontFamily: String? = nil
  public var fontSize: Double = 16
  public var fontWeight: Double = 400
  public var textAnchor: TextAnchor = .start
  public var dominantBaseline: DominantBaseline = .alphabetic
  public var letterSpacing: Double = 0
  public init() {}
}

/// 動画の設定
public struct VideoConfig {
  public var fps: Double
  public var width: Double
  public var height: Double
  public var durationInFrames: Double
  public init(fps: Double, width: Double, height: Double, durationInFrames: Double) {
    self.fps = fps; self.width = width; self.height = height; self.durationInFrames = durationInFrames
  }
}

public final class RenderContext {
  public let cg: CGContext
  public var style = DrawStyle()
  var styleStack: [DrawStyle] = []
  /// 今のフレーム (Sequence の中ではその先頭からの相対値)
  public var frame: Double
  public var config: VideoConfig
  /// Context で渡す値 (型ごとに 1 つ)
  var values: [ObjectIdentifier: Any] = [:]

  public init(cg: CGContext, frame: Double, config: VideoConfig) {
    self.cg = cg
    self.frame = frame
    self.config = config
  }

  // ---------- スレッドごとの今の描画先 ----------

  private static let key: pthread_key_t = {
    var k = pthread_key_t()
    pthread_key_create(&k, nil)
    return k
  }()

  public static var current: RenderContext {
    guard let raw = pthread_getspecific(key) else {
      fatalError("描画の部品は RenderContext.run { … } の中 (visual・部品の描画中) で使ってください")
    }
    return Unmanaged<RenderContext>.fromOpaque(raw).takeUnretainedValue()
  }

  public static var currentOrNil: RenderContext? {
    pthread_getspecific(key).map { Unmanaged<RenderContext>.fromOpaque($0).takeUnretainedValue() }
  }

  /// body の間、このスレッドの描画先を self にする
  public func run(_ body: () -> Void) {
    let prev = pthread_getspecific(RenderContext.key)
    pthread_setspecific(RenderContext.key, Unmanaged.passUnretained(self).toOpaque())
    defer { pthread_setspecific(RenderContext.key, prev) }
    withExtendedLifetime(self) { body() }
  }

  func pushStyle() { styleStack.append(style) }
  func popStyle() { style = styleStack.removeLast() }

  /// 今の変換の倍率 (影のずれ・ぼかしは画面のピクセルで指定するので、これを掛ける)
  var ctmScale: Double {
    let m = cg.ctm
    return sqrt(abs(m.a * m.d - m.b * m.c))
  }
}

// ---------- Context の値 (React の createContext / useContext に当たる) ----------

/// body の間、型 T の値として value を渡す (useContextValue(T.self) で受け取る)
public func provide<T>(_ value: T, _ body: () -> Void) {
  let c = RenderContext.current
  let key = ObjectIdentifier(T.self)
  let prev = c.values[key]
  c.values[key] = value
  defer { c.values[key] = prev }
  body()
}

/// provide で渡された型 T の値 (無ければ nil)
public func useContextValue<T>(_ type: T.Type) -> T? {
  RenderContextOrNil()?.values[ObjectIdentifier(T.self)] as? T
}

@inline(__always) func RenderContextOrNil() -> RenderContext? { RenderContext.currentOrNil }

// ---------- フレーム ----------

/// 今のフレーム。Sequence (工程) の中ではその先頭からのフレーム
public func useCurrentFrame() -> Double { RenderContext.current.frame }

/// 動画の fps・大きさ・長さ (Sequence の中では durationInFrames がその長さ)
public func useVideoConfig() -> VideoConfig { RenderContext.current.config }

/// from から durationInFrames の間だけ body を描く。中ではフレームが from からの相対値になる
public func Sequence(from: Double, durationInFrames: Double, _ body: () -> Void) {
  let c = RenderContext.current
  let local = c.frame - from
  guard local >= 0, local < durationInFrames else { return }
  let prevFrame = c.frame
  let prevConfig = c.config
  c.frame = local
  c.config.durationInFrames = durationInFrames
  defer { c.frame = prevFrame; c.config = prevConfig }
  body()
}
