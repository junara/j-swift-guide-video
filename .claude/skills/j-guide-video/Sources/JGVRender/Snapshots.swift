// 各ナレーション行の「アニメーションが出そろった瞬間」を静止画にして一覧画像を作る (見た目の確認用)。
//   --scene=N   N 番目 (0 始まり) の工程だけを書き出す。出力は out/snapshots/scene-N/ (並列で実行しても衝突しない)
//   --phrases   行ごとではなく句ごとに撮る。1 工程 = 一覧の 1 段で「工程の最初 → 句ごと → 工程の最後の 0.5 秒前」の順に並ぶ
//   --seams     工程の境目だけを撮る。1 段 = 境目 1 つの 4 コマ「前の工程の最後の 0.5 秒前 | 最後 ‖ 次の工程の最初 | 読み始めの直後」
//   --at=1.5,2.3  --scene=N の工程の始まりからの秒を指定して撮る (出力は scene-N/at/)
//   --video     その動画から抜き出す (描かない)
// 撮るフレームだけを描くので、動画全体を書き出すより速い
import CoreGraphics
import Foundation
import JGVCore
import JGVKit

public struct SnapshotOptions {
  public var scene: Int?
  public var phrases = false
  public var seams = false
  public var at: [Double]?
  public var video: URL?
  public init() {}
}

struct Shot {
  var t: Double
  var file: URL
}

public enum Snapshots {
  static let detail = 0.5

  public static func run(renderer: FrameRenderer, root: URL, options o: SnapshotOptions) throws {
    let tl = renderer.timeline
    var scene: Scene? = nil
    if let s = o.scene {
      guard s >= 0, s < tl.scenes.count else { throw AudioMix.err("--scene=\(s) はありません (工程は 0〜\(tl.scenes.count - 1))") }
      scene = tl.scenes[s]
    }
    if let at = o.at, scene == nil || o.seams || o.phrases || at.isEmpty || at.contains(where: { !$0.isFinite || $0 < 0 }) {
      throw AudioMix.err("--at は --scene=N と一緒に、工程の始まりからの秒をカンマ区切りで渡す (例: --scene=3 --at=1.5,2.3)。--phrases・--seams とは同時に使えない")
    }
    if o.seams && (scene != nil || o.phrases) { throw AudioMix.err("--seams は --scene・--phrases と同時に使えません (境目はすべての工程について撮る)") }
    if o.seams && tl.scenes.count < 2 { throw AudioMix.err("工程が 1 つだけなので境目がありません") }

    var outDir = root.appendingPathComponent("out/snapshots")
    if let scene { outDir.appendPathComponent("scene-\(scene.index)") }
    if o.at != nil { outDir.appendPathComponent("at") }
    // out/・out/snapshots/ などがシンボリックリンクだと、前回の画像を消すときにリンク先の画像を消してしまうので止める
    try Safety.requireNoSymlinks(under: root, outDir)
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    // 前回の静止画だけを消す (scene-N/ は残す。リンクではないふつうのファイルだけ)
    for f in (try? FileManager.default.contentsOfDirectory(atPath: outDir.path)) ?? [] where f.hasSuffix(".png") && Safety.isRegularFile(outDir.appendingPathComponent(f)) {
      try? FileManager.default.removeItem(at: outDir.appendingPathComponent(f))
    }

    func pad2(_ i: Int) -> String { String(format: "%02d", i) }
    func f1(_ v: Double) -> String { String(format: "%.1f", v) }
    var rows: [String] = []
    var shots: [Shot] = []
    var cellW = 768
    var cols = 1
    var rowsN = 1
    // 静止画がそろった後に作る一覧の 1 段 (境目) と、空きのコマ
    var seamRows: [(files: [URL], out: URL)] = []
    var blanks: [URL] = []
    let vertical = tl.height > tl.width

    if o.seams {
      for i in 0 ..< tl.scenes.count - 1 {
        let a = tl.scenes[i], b = tl.scenes[i + 1]
        let bLine = tl.lines.first { $0.sceneIndex == b.index }
        let ts = [max(a.start + 0.1, a.end - 0.5), a.end - 0.1, b.start + 0.1, min(b.end - 0.1, max(b.start + 0.1, (bLine?.start ?? b.start) + 0.4))]
        let files = (0 ..< 4).map { outDir.appendingPathComponent("seam-\(pad2(i))-\($0).png") }
        for (k, t) in ts.enumerated() { shots.append(Shot(t: t, file: files[k])) }
        seamRows.append((files, outDir.appendingPathComponent("\(pad2(i)).png")))
        rows.append("\(pad2(i))  工程 \(a.index) (+\(f1(ts[0] - a.start))s, 最後 +\(f1(ts[1] - a.start))s) | 工程 \(b.index) (最初 +\(f1(ts[2] - b.start))s, +\(f1(ts[3] - b.start))s)  \(a.heading) → \(b.heading)")
      }
      cols = 1
      rowsN = tl.scenes.count - 1
    } else if let atList = o.at, let scene {
      let last = scene.end - 2 / tl.fps
      for (k, sec) in atList.enumerated() {
        let t = min(last, scene.start + sec)
        shots.append(Shot(t: t, file: outDir.appendingPathComponent("\(pad2(k)).png")))
        let over = scene.start + sec > last ? " (工程の長さを超えたので最後のフレーム)" : ""
        rows.append("\(pad2(k))  工程 \(scene.index)  +\(String(format: "%.2f", t - scene.start))s\(over)")
      }
      cols = min(atList.count, vertical ? 6 : 4)
      rowsN = Int((Double(atList.count) / Double(cols)).rounded(.up))
    } else {
      let lines = tl.lines.enumerated().filter { scene == nil || $0.element.sceneIndex == scene!.index }
      if o.phrases {
        // 1 工程 = 1 段: 工程の最初、各句 (句の読み始めから動きが出そろうまで)、工程の最後
        let scenes = scene.map { [$0] } ?? tl.scenes
        let lists: [[(t: Double, label: String)]] = scenes.map { sc in
          var list: [(t: Double, label: String)] = [(sc.start + 0.1, "start")]
          for (li, l) in lines.map({ $0.element }).filter({ $0.sceneIndex == sc.index }).enumerated() {
            let phs = l.phrases.isEmpty ? [Caption(text: l.text, start: l.start, end: l.start + l.duration)] : l.phrases
            for (k, ph) in phs.enumerated() {
              list.append((ph.start + min(0.9, max(0.35, (ph.end - ph.start) * 0.85)), "行 \(li) [\(k)] \(ph.text)"))
            }
          }
          // 最後のコマは工程の終わりの 0.5 秒前 (拡大カードが縮み始める前)
          list.append((max(sc.start + 0.1, sc.end - 0.5), "end"))
          return list
        }
        cols = lists.map { $0.count }.max() ?? 1
        rowsN = lists.count
        if cols > 4 { cellW = max(320, 3000 / cols) }
        for (r, list) in lists.enumerated() {
          for c in 0 ..< cols {
            let file = outDir.appendingPathComponent("\(pad2(r))-\(pad2(c)).png")
            if c < list.count {
              shots.append(Shot(t: list[c].t, file: file))
              rows.append("\(file.deletingPathExtension().lastPathComponent)  工程 \(scenes[r].index)  +\(f1(list[c].t - scenes[r].start))s  \(list[c].label)")
            } else {
              blanks.append(file)
            }
          }
        }
      } else {
        if lines.isEmpty { throw AudioMix.err("この工程には読み上げる行がありません (script.json の lines が空)") }
        for (i, l) in lines {
          let t = l.start + min(1.2, l.duration * 0.6)
          shots.append(Shot(t: t, file: outDir.appendingPathComponent("\(pad2(i)).png")))
          let sceneStart = tl.scenes.first { $0.index == l.sceneIndex }?.start ?? 0
          rows.append("\(pad2(i))  工程 \(l.sceneIndex)  +\(f1(t - sceneStart))s  \(l.text)")
        }
        cols = min(lines.count, vertical ? 6 : 4)
        rowsN = Int((Double(lines.count) / Double(cols)).rounded(.up))
      }
    }

    guard !shots.isEmpty else { throw AudioMix.err("撮るコマがありません (timeline の scenes が空)") }
    // 撮るフレームを動画の半分の大きさで描く (または --video から抜き出す)
    let maxFrame = tl.durationInFrames - 1
    if let video = o.video {
      for s in shots {
        let img = try VideoWriter.frame(of: video, at: max(0, s.t), maxWidth: Int(tl.width * detail))
        try Bitmap.writePNG(img, to: s.file)
      }
    } else {
      let errors = NSLock()
      var firstError: Error?
      DispatchQueue.concurrentPerform(iterations: shots.count) { k in
        let s = shots[k]
        let frame = min(maxFrame, max(0, Int(jsRound(s.t * tl.fps))))
        let img = renderer.image(frame: frame, scale: detail)
        do { try Bitmap.writePNG(img, to: s.file) } catch {
          errors.lock(); firstError = firstError ?? error; errors.unlock()
        }
      }
      if let firstError { throw firstError }
    }
    // 境目の 4 コマを縮めて横に並べる (赤い線が前後の工程の境)
    for row in seamRows {
      let imgs = row.files.compactMap { Bitmap.read($0) }
      guard imgs.count == 4 else { continue }
      let cw = vertical ? 300.0 : 480.0
      let h = Int((cw * Double(imgs[0].height) / Double(imgs[0].width) / 2).rounded()) * 2
      let white = RGBA(1, 1, 1), red = RGBA(0xdd / 255.0, 0x33 / 255.0, 0x33 / 255.0)
      if let img = Bitmap.hstack(imgs, height: h, gaps: [(4, white), (24, red), (4, white)]) { try Bitmap.writePNG(img, to: row.out) }
    }
    // 句の少ない工程は白い画像で埋めて、段をそろえる
    if !blanks.isEmpty, let first = shots.first.flatMap({ Bitmap.read($0.file) }) {
      let cg = Bitmap.context(width: first.width, height: first.height)
      cg.setFillColor(RGBA(1, 1, 1).cgColor)
      cg.fill(CGRect(x: 0, y: 0, width: first.width, height: first.height))
      if let white = cg.makeImage() { for b in blanks { try Bitmap.writePNG(white, to: b) } }
    }
    // 一覧は 1 コマずつの静止画を cellW に縮めて並べる (境目の 1 段はすでに縮めてある)
    let names = ((try? FileManager.default.contentsOfDirectory(atPath: outDir.path)) ?? [])
      .filter { $0.hasSuffix(".png") && $0.first?.isNumber == true && Safety.isRegularFile(outDir.appendingPathComponent($0)) }.sorted()
    let images = names.map { Bitmap.read(outDir.appendingPathComponent($0)) }
    let sheetCellW = o.seams ? (images.compactMap { $0?.width }.max() ?? cellW) : cellW
    if let sheet = Bitmap.tile(images, cols: cols, cellW: sheetCellW, padding: o.seams ? 24 : 8) {
      try Bitmap.writePNG(sheet, to: outDir.appendingPathComponent("sheet.png"))
    }
    _ = rowsN
    print(rows.joined(separator: "\n"))
    let rel = outDir.path.replacingOccurrences(of: root.path + "/", with: "")
    let detailOf = o.seams
      ? "seam-II-K.png (II は上の各行の頭の番号、K は左から 0〜3。0 = 前の工程の最後の 0.5 秒前、3 = 次の工程の読み始めの直後)"
      : "<上の各行の頭の番号>.png (例: \(shots[min(3, shots.count - 1)].file.lastPathComponent))"
    print("OK: \(rel)/sheet.png (\(o.seams ? "境目 \(tl.scenes.count - 1) つ, 1 段に 1 つ" : "\(cols) 列 × \(rowsN) 段, 左上から順")\(o.seams ? "。赤い線の左 2 コマが前の工程の最後の 0.5 秒前と最後、右 2 コマが次の工程の最初と読み始めの直後 (赤い線の両隣で全景、両端で拡大カードの中身のつながりを見る)" : ""))")
    fflush(stdout)
    FileHandle.standardError.write(Data(("   1 コマずつの静止画 (動画の半分の大きさ): \(rel)/\(detailOf)。一覧で細部が見えないときに Read する\n").utf8))
  }
}
