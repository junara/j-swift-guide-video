// 動画全体の 1 フレーム: 背景 → 工程の visual と工程バッジ → 枠 (タイトル・字幕バー・進捗) → 字幕。
// 部屋と人物は全工程で共通なので、シーン間でフェードせず visual と工程バッジだけを切り替える
import Foundation

/// 工程の visual (visuals/<名前>.swift の func <名前>(_ props: Props))
public typealias VisualFn = (Props) -> Void

func toFrame(_ sec: Double, _ fps: Double) -> Double { jsRound(sec * fps) }

private func SceneView(scene: Scene, style: Style, lines: [NarrationLine], totalScenes: Int, strings: [String: String], visuals: [String: VisualFn]) {
  let cfg = useVideoConfig()
  let gd = useGuide()
  if let ref = scene.visual {
    guard let visual = visuals[ref.type] else {
      fatalError("visual \"\(ref.type)\" が登録されていません (visuals/\(ref.type).swift を用意して jgv tts を実行)")
    }
    // 工程のアニメーション。ナレーションのタイミングを Context で渡す
    provide(SceneInfo(
      sceneIndex: scene.index, heading: scene.heading, lines: lines,
      accent: style.accentColor.map { Paint($0) } ?? gd.palette.accent,
      textColor: style.textColor.map { Paint($0) } ?? gd.palette.ink,
      fontFamily: gd.font, strings: strings
    )) {
      g(fontFamily: gd.font) { visual(ref.props) }
    }
  }
  GuideStepBadge(index: scene.index, label: scene.heading, total: cfg.height > cfg.width ? totalScenes : nil)
}

/// timeline の 1 フレームを描く (今のフレームは RenderContext の frame)
public func NarratedVideo(timeline tl: Timeline, visuals: [String: VisualFn]) {
  let fps = tl.fps
  // フォント未指定なら言語に合わせる
  let font = tl.style.fontFamily ?? fontForLang(tl.lang ?? "ja-JP")
  // "guide" = 部屋、"guide-screen" / "guide-topdown" / "guide-manual" = 型違い
  let parts = tl.layout.split(separator: "-")
  let variant = GuideVariant(rawValue: parts.count > 1 ? String(parts[1]) : "room") ?? .room
  let portrait = tl.height > tl.width
  let palette = DEFAULT_PALETTE.merged(tl.palette)
  // 字幕バー・説明文の表示 (script.json の style.captions / style.notes。既定は表示)
  let captions = tl.style.captions != false
  let notes = tl.style.notes != false
  let info = GuideInfo(
    palette: palette, font: font, layout: portrait ? LAYOUT_PORTRAIT : LAYOUT_LANDSCAPE, variant: variant,
    lang: tl.lang ?? "ja-JP", kicker: tl.kicker ?? "", title: tl.title, credit: tl.credit, captions: captions, notes: notes,
    presenter: tl.presenter.flatMap(PresenterLook.init(rawValue:)) ?? .neutral
  )
  /// 工程 i の行 (フレームは工程の先頭からの相対値)。
  /// 音声・字幕は絶対時刻を丸めてフレームに合わせるので、ここでも絶対時刻で丸めてから工程の頭を引く (別々に丸めて足すと 1 フレームずれる)
  func sceneLines(_ i: Int, _ scene: Scene) -> [NarrationLine] {
    let s0 = toFrame(scene.start, fps)
    func rel(_ sec: Double) -> Double { toFrame(sec, fps) - s0 }
    return tl.lines.filter { $0.sceneIndex == i }.enumerated().map { k, l in
      NarrationLine(
        index: k, text: l.text, cue: l.cue,
        start: rel(l.start),
        end: rel(l.start + l.duration),
        captions: l.captions.map { Caption(text: $0.text, start: rel($0.start), end: rel($0.end)) },
        phrases: l.phrases.map { Caption(text: $0.text, start: rel($0.start), end: rel($0.end)) }
      )
    }
  }
  // 動画のフレーム数は切り上げ、工程の終わりは四捨五入なので、端数が 0.5 未満だと最後の 1 コマがどの工程にも入らない。
  // 最後の工程は動画の終わりまで描く (最後のコマで絵と工程バッジが消えて、背景だけが残らないように)
  let totalFrames = Double(tl.durationInFrames)
  func sceneFrames(_ i: Int, _ scene: Scene) -> Double {
    let from = toFrame(scene.start, fps)
    let n = max(1, toFrame(scene.end, fps) - from)
    return i == tl.scenes.count - 1 ? max(n, totalFrames - from) : n
  }
  // キューの工程が前の工程の終わりの状態を実際の時刻の順で求められるよう、全工程の読み上げの時刻を渡す
  var timings: [String: (lines: [NarrationLine], durationInFrames: Double)] = [:]
  for (i, scene) in tl.scenes.enumerated() {
    guard let ref = scene.visual, timings[ref.type] == nil else { continue }
    timings[ref.type] = (sceneLines(i, scene), sceneFrames(i, scene))
  }
  provide(info) { provide(SceneTimings(byVisual: timings)) {
    fillBackground(palette.wallTop)
    GuideBackdrop()
    for (i, scene) in tl.scenes.enumerated() {
      Sequence(from: toFrame(scene.start, fps), durationInFrames: sceneFrames(i, scene)) {
        SceneView(scene: scene, style: tl.style, lines: sceneLines(i, scene), totalScenes: tl.scenes.count, strings: tl.strings, visuals: visuals)
      }
    }
    GuideFrame(scenes: tl.scenes.map { ($0.start, $0.end) })
    if captions {
      for line in tl.lines {
        for c in line.captions {
          let from = toFrame(c.start, fps)
          Sequence(from: from, durationInFrames: max(1, toFrame(c.end, fps) - from)) {
            GuideCaption(text: c.text, fontFamily: font, fontSize: tl.style.subtitleFontSize)
          }
        }
      }
    }
  } }
}
