# Visual kit リファレンス

手順動画の工程ごとのアニメーションを書くための部品。ふだんは工程の動きを **キュー**（[cue.md](cue.md)）で書き、ここの部品は binding（`visuals/bind.swift`）の描き方で呼ぶ。工程全体を Swift の visual で書くときは、この文書の雛形・パターンも使う。カスタム visual (`visuals/<Name>.swift`) で `import JGVKit` して使う（描画 DSL の JGVCore も一緒に使える）。
座標は動画のピクセルそのまま（横 1920×1080 / 縦 1080×1920、y は下向き）。すべてフレーム番号から計算する。kit のソースは skill の `Sources/JGVKit/`・`Sources/JGVCore/`（プロジェクトのビルドはこれをそのまま参照する。編集しない）。この文書に無い引数・持つ所（`〜_PARTS`）は、ソースを読まずに `jgv api <語>`（例: `jgv api やかん`・`jgv api 持つ所`）で宣言と説明を引く。

## カスタム visual の雛形

```swift
// visuals/MyScene.swift  → script.json で "visual": "MyScene"（props は { "type": "MyScene", "foo": 1 }）
import JGVKit

func MyScene(_ props: Props) {
  let n = useNarration()
  let foo = props.double("foo", 1)
  let cx = n.width / 2
  let cy = n.safe.y + n.safe.h / 2
  Stage {
    // 1 行目の読み上げ開始から 0.8 秒で円を描く
    Draw(d: circlePath(cx, cy, 200 * foo), progress: n.progress(0, 0.8), width: 6, glow: true)
    // 2 行目の開始で弾むように登場
    Pop(at: n.at(1), x: cx, y: cy) {
      T("ポイント", x: 0, y: 0, size: 80, weight: 800)
    }
  }
}
```

- ファイル名と同じ名前の `func <Name>(_ props: Props)` にする（ファイル名 = visual 名、英数字 PascalCase）。登録表は `jgv render` などのビルドのたびに `visuals/` から作るので、書かなくてよい
- `props` は script.json の visual のほかのキー: `props.double("cups", 2)` / `props.string("label", "")` / `props.bool("dark", false)`（2 つ目は無いときの値）。JSON のまま欲しいときは `props["items"]`
- 共有したい部品・定数は小文字のファイル（`shared.swift` `props.swift`）にまとめる。同じモジュールなので import なしでそのまま使える（登録表には載らない）。ユーザーのライブラリの部品 `parts/*.swift` も同じ
- **工程の visual から、ほかの工程の visual のファイル（大文字のファイル）の定数・関数を使わない**。`jgv snapshots --scene=N` はその工程の visual と小文字のファイル・`parts/` だけでビルドする（並列で作業中のほかの工程の書きかけで止まらないように）。2 つの工程で使うものは `shared.swift` に置く
- `Stage { … }` の中に描く。描画は即時（関数を呼んだ順に重なる。後に呼んだものが手前）
- 必ず `n.safe`（左上の見出し・工程バッジと下部の字幕バーを除いた領域。`useStage().content` と同じ）の中に収める
- 工程名は左上の工程バッジに自動で出るので、visual の中に見出しは描かない

### 描画 DSL（SVG の要素 → 関数）

SVG の要素と属性を、そのまま関数と引数にしたもの（`Sources/JGVCore/Draw.swift`）。子要素は末尾のクロージャ `{ … }` に書く。

| 関数 | SVG |
|---|---|
| `g(fill:stroke:strokeWidth:strokeLinecap:strokeLinejoin:strokeDasharray:strokeDashoffset:opacity:fillRule:fontFamily:fontSize:fontWeight:textAnchor:transform:clip:filter:) { … }` | `<g>`。塗り・線の属性は中身に引き継ぐ |
| `path("M …", fill:…)` | `<path d>` |
| `rect(x:y:width:height:rx:ry:fill:…)` | `<rect>`（x, y の既定 0） |
| `circle(cx:cy:r:fill:…)` / `ellipse(cx:cy:rx:ry:fill:…)` | `<circle>` / `<ellipse>`（cx, cy の既定 0） |
| `line(x1:y1:x2:y2:stroke:…)` | `<line>`（fill 引数なし） |
| `polygon(points:fill:…)` / `polyline(points:…)` | `points` は `[Pt(0, 0), Pt(10, 0)]` か `"0,0 10,0"` |
| `text("文字", x:y:fontSize:fontWeight:fontFamily:fill:stroke:strokeWidth:textAnchor:dominantBaseline:letterSpacing:opacity:transform:)` | `<text>`（`textAnchor: .middle`、`dominantBaseline: .central`） |

**引数の順番**: Swift はラベル付き引数の順番を入れ替えられない（宣言順に書かないとコンパイルエラー）。どの図形も **形（`d` / `x y width height rx ry` / `cx cy r` / `x1 y1 x2 y2` / `points`）→ `fill` → `stroke` → `strokeWidth` → `strokeLinecap` → `strokeLinejoin` → `strokeDasharray` → `strokeDashoffset` → `opacity` → `fillOpacity` → `strokeOpacity` → `fillRule` → `transform` → `filter`** の順。`g` は `opacity` の次が `fillRule` → 文字の属性 → `transform` → `clip` → `filter`（`fillOpacity` は無い）。kit の部品も宣言順（下の表の順）に書く。

```swift
let palette = useGuide().palette
g(stroke: palette.ink, strokeWidth: 6, strokeLinecap: .round, strokeLinejoin: .round, transform: [.translate(x, y), .rotate(-10), .scale(s)]) {
  rect(x: -120, y: -80, width: 240, height: 160, rx: 18, fill: palette.cream)
  circle(cx: 0, cy: 0, r: 40, fill: "none", strokeDasharray: [10, 8])
  path("M -60 -40 Q 0 -90 60 -40", fill: "none", stroke: palette.accent, opacity: n.ease(0))
  text("ラベル", x: 0, y: 110, fontSize: 30, fontWeight: 800, fill: palette.ink, stroke: "none", textAnchor: .middle, dominantBaseline: .central)
}
g(clip: .rect(x: 300, y: 300, width: 200, height: 120, rx: 16)) {   // clipPath。.circle(cx:cy:r:) / .ellipse(…) / .path("M…") も
  ellipse(cx: 400, cy: 360, rx: 160, ry: 90, fill: .linear(LinearGradient(x1: 0, y1: 0, x2: 0, y2: 1, stops: [(0, "#9ccbe0"), (1, "#4b9cc4")])))
}
polygon(points: [Pt(100, 100), Pt(200, 100), Pt(150, 40)], fill: "#e0a83a", filter: .shadow)
```

- 数値はすべて `Double`。点は `Pt(x, y)`、矩形は `Box(x:y:w:h:)`
- 色は `Paint`。文字列リテラルからそのまま作れる（`fill: "#fff"`、`fill: "none"`、`palette.primary`）。2 色の中間は `Paint("#ccc").mix("#8a6", t)`、半透明は `.opacity(0.5)`
- 透明（塗らない）は `"none"` か `Paint.none`。**`fill: .none` と書かない**（引数は `Paint?` なので `nil` = 外側の g から引き継ぐ、になる。塗りの既定は黒。コンパイラの警告だけで、ビルドは通る）
- 属性を省く（`nil`）と外側の `g` から引き継ぐ（SVG と同じ）。道具の `Placed` の中は線が ink・太さ 6 なので、中の文字には `stroke: "none"` を付ける
- `transform` は配列で、左から順に掛かる: `[.translate(x, y), .rotate(deg), .scale(s)]`。`.rotate(deg, cx, cy)`、`.scale(sx, sy)`、`.skewX(deg)` も
- `filter: .shadow`（影）/ `.glow`（発光）。破線は `strokeDasharray: [10, 8]`
- 条件は `if cond { … }`、繰り返しは `for (i, it) in items.enumerated() { … }`
- パスの文字列は文字列補間で作る: `path("M \(x) \(y) L \(x + w) \(y)")`（Double をそのまま埋めてよい）

### Swift で書くときの注意

- 乱数は `random("seed")`（同じ seed なら毎回同じ値）。`Double.random`・`Date()`・時計は使わない（コマごとに違う絵になる）。すべて `n.frame` から計算する
- 計算: `interpolate(v, [a, b], [c, d], .clamp)`（clamp なしは引数を省く。easing 付きは `.clamp(easing: Easing.inOut(Easing.cubic))`、片側だけは `InterpolateOptions(left: .clamp)`）、`spring(frame: f, fps: n.fps, damping: 200)`（`stiffness:` `mass:` も）。四捨五入は `jsRound(x)`（0.5 は常に切り上げ）、小数・負の数の余りは `jsMod(a, b)`（結果の符号は `a` と同じ）。ほかは Swift の `floor`・`hypot`・`Double.pi` をそのまま使う
- **Double と Int を混ぜない**: `for i in 0 ..< 3` の `i` は Int なので `Double(i)` にする。配列のリテラルは `[-130.0, 130]` のように 1 つを小数で書くと `[Double]` になる
- ファイルの中だけで使う定数・関数は `private` にする（`private let POT = Pt(930, GUIDE.counterY)`）。ほかのファイルと名前がぶつからない
- **kit の関数と同じ名前のローカル変数を作らない**: `let rect = ph.rect(SAVE)` のあとで `rect(x: …)` を呼ぶと「cannot call value of non-function type」になる。名前を変える（`saveRect`）か、`JGVKit.rect(…)` と書く。`path` `circle` `line` `text` `g` も同じ。kit の部品・定数（`Mug`、`MUG_PARTS`、`Stream` など）と同じ名前の部品・visual も作らない（自分のほうが優先され、kit のものが隠れる）
- 長い式・`?:` の入れ子・Double の計算をたくさんつないだ式は、型チェックが遅くなる（「unable to type-check this expression in reasonable time」）。途中を `let` に分ける
- 部品の引数は、宣言にある既定値のものだけ省ける。描き方を関数にして渡すときは `{ x, y, s in Mug(x: x, y: y, scale: s) }` の形（引数の数を宣言に合わせる。使わない引数は `_`）
- ビルドは `jgv snapshots` / `jgv render` / `jgv preview` が自動で行い、エラーの行だけを出す（警告は出ない）

## useNarration()

| 名前 | 内容 |
|---|---|
| `at(key, offsetSec = 0)` | 行の読み上げ開始フレーム（シーン先頭からの相対）。`key` は行番号 (0〜) または `lines[].cue` の文字列。無い行はシーンの外（動きは起きない） |
| `atPhrase(key, k, offsetSec = 0)` | 行を読点・句点で区切った k 番目の句の開始フレーム（下の「句単位の同期」） |
| `endOf(key)` | 行の読み上げ終了フレーム |
| `progress(key, durSec = 0.8, offsetSec = 0)` | 行の開始から durSec 秒で 0→1（線形・クランプ）。`Draw(progress:)` に渡すのが定番 |
| `ease(key, offsetSec = 0)` | 行の開始でなめらかな spring 値 0→1 |
| `isSpeaking(key)` | その行を読み上げ中か |
| `lines` | `[NarrationLine]`（`index text cue start end captions phrases`。フレームはシーン相対）。字幕チャンク単位の同期は `captions` を使う |
| `frame` / `sec` / `fps` / `durationInFrames` | 現在フレーム・秒・fps・シーン長（どれも Double） |
| `width` / `height` / `portrait` | 動画サイズと縦動画かどうか |
| `safe` | `Box`（`x y w h`）描画してよい領域 |
| `notes` | 説明文を表示するか（`script.json` の `style.notes`。既定 true）。visual に `T` などで直接書く説明の文字（注意書き・まとめ・補足）は `if n.notes { … }` で囲む。道具や画面 UI の一部として描かれた文字（ボタン名・ラベル・タイマーの数字）は囲まない |
| `t(key, fallback)` | 画面上の文言（`script.json` の `strings[key]`、無ければ fallback。下の「画面上の文言の多言語化」） |
| `heading` / `accent` / `textColor` / `fontFamily` | 工程名とテーマ（色の既定はパレットの `accent` / `ink`、`style.accentColor` / `style.textColor` で上書き） |

引数はラベルなしで書く（`n.at(1, 0.2)`、`n.atPhrase(0, 1, -0.2)`）。`offsetSec` は負の値も可（例: `n.at(0, -0.3)` = 読み始める 0.3 秒前から準備）。

## 部品

| 部品 | 用途 |
|---|---|
| `Stage { … }` | 工程の描画範囲（全画面）。影・発光は各図形の `filter: .shadow` / `.glow` |
| `Draw(d:progress:color:width:fill:fillOpacity:glow:opacity:)` | パスを線で描くアニメーション（`evolvePath`）。fill 指定で描き終わりに塗りがフェードイン |
| `Icon(name:x:y:size:progress:color:strokeWidth:glow:)` | 組み込みアイコンを線描き（名前は下記） |
| `Pop(at:x:y:scale:) { … }` | at フレームで弾んで拡大登場。中身は (0,0) 基準で描く |
| `FlowDots(d:count:speed:r:color:opacity:)` | パスに沿って流れる光の点（接続・データの流れ） |
| `Pulse(x:y:r:color:period:count:active:width:)` | 広がる波紋（注目・発話中） |
| `Burst(at:x:y:r:count:color:width:)` | 放射状に飛び散る線（完了・発見の瞬間） |
| `T("文字", x:y:size:weight:color:anchor:opacity:family:)` | テキスト（`\n` で改行、y は 1 行目の中心。`anchor` の既定は `.middle`） |
| `CountUp(at:from:to:durSec:decimals:prefix:suffix:x:y:size:weight:color:anchor:opacity:family:)` | 数値のカウントアップ（`to` は `x` より前） |

文字幅: `textWidth(text, size)`（全角 = size、半角 = 0.56 × size のおおよその幅。ラベルの座布団などに）。実際のフォントで測るときは `measureText(text, size: 40, weight: 800)`

パス生成: `circlePath(cx, cy, r)` / `rectPath(x, y, w, h, r)` / `arcPath(cx, cy, r, fromDeg, toDeg)`（0° = 右、時計回り）

組み込みアイコン: `shield` `warning` `sun` `water` `book`（`Sources/JGVKit/Primitives.swift` の `ICONS` に 24×24 の線のパスで追加できる）

よく使う演出（`Sources/JGVKit/guide/Effects.swift`、どの型でも使える）:

| 部品 | 内容 |
|---|---|
| `DropIn(at:x:y:shadowW:height:) { y in 道具(x: x, y: y) }` | `at` に道具が上から落ちてきて置かれる（影も濃くなる）。クロージャは落下中の底の y を受け取る。`y` の既定はカウンター天板 |
| `Ripple(x:y:w:at:color:)` | 水面の揺れと広がる波紋（原点 = 水面の中心）。`at` に大きく揺れてから小さく揺れ続ける |
| `NoSign(x:y:r:at:color:)` | 禁止マーク（「扉は閉めたまま」「触らない」など）。`at` に弾んで登場 |
| `ArcTimer(x:y:r:progress:label:size:color:)` | 円弧のタイマー。`progress`（0〜1）で 12 時から時計回りに伸びる。待ち時間は `interpolate(n.frame, [始まり, 終わり], [0, 1], .clamp)` で数秒に縮めて回し、`label: "5分"` のように実際の時間を書く |

## 動きのパターン集

- **登場**: `Draw`（線で描く）→ `Pop`（中身）→ `Burst`（強調）の順に 0.1〜0.3 秒ずつずらす
- **常に何か動かす**: 静止画面にしない。湯気（`Steam`）・`FlowDots`・`Pulse`・`sin(n.frame * …)` での揺れなどで、ナレーション中ずっと微動させる
- **発話との対応**: 名詞が出る行で、その物体を登場させる。`n.isSpeaking(i)` で話している間だけ `Pulse` を出す
- **場面転換**: 2 行目で前の要素を `g(opacity: 1 - n.ease(1)) { … }` で消し、新しい要素を出す
- **数値・時間**: `CountUp` と `arcPath` の円弧タイマー（または `ArcTimer`）を組み合わせる（`interpolate(n.frame, [n.at(1), n.endOf(1)], [0, 1], .clamp)`）
- **揺れ・緊迫**: `g(transform: [.translate(sin(n.frame * 2.3) * 14, 0)]) { … }`、落ち着かせるときは係数を 0 へ
- 乱数は `random("seed")`（決定的）。粒を並べるときは `random("grain\(i)")` のように番号を seed に入れる

### 動きの計算（`Sources/JGVKit/Motion.swift`）

`at` は `n.at()` / `n.atPhrase()` の戻り値（シーン先頭からのフレーム）をそのまま渡す。

| 関数 | 内容 |
|---|---|
| `easeAt(frame, fps, at)` | `at` から始まるなめらかな 0→1。行や句に結びつかないフレームから始めたいときの `n.ease` |
| `dropAt(frame, fps, at)` | 上から落ちて弾んで止まる 0→1（1 を超えないので、置いた物がカウンターにめり込まない）。`y = 着地点 - 300 * (1 - dropAt(…))` |
| `track(frame, fps, start, moves)` | `start` から `moves`（`[Move(at:to:dur:lift:)]`、`dur` 既定 0.6 秒・`lift` 既定 0）を順に移動した現在位置。手や道具を「取りに行く → 弧を描いて運ぶ → 戻す」 |
| `zigzag(u, x0, x1, y0, y1, passes = 3)` | 範囲を `u`（0〜1）でジグザグに往復する位置。拭く・こする手 |
| `clock(sec)` | 秒数を `"m:ss"` に（タイマー・表示窓） |

```swift
let hand = track(n.frame, n.fps, PRESENTER.restR, [
  Move(at: n.atPhrase(0, 0), to: bowlRim),                   // ボウルへ手を伸ばす
  Move(at: n.atPhrase(0, 1), to: inside, lift: 80),          // 弧を描いて庫内へ運ぶ
  Move(at: n.atPhrase(0, 2), to: PRESENTER.restR, dur: 0.5), // 手を戻す
])
```

## よくあるシーンの型（`Sources/JGVKit/guide/Scenes.swift`、どの型でも・縦型でも使える）

「用意するもの」「注意点」「ビフォー・アフター」「まとめ」は、毎回手で描かずにこの部品を使う。`Stage { … }` の中に置き、`Presenter` などと組み合わせる。`at` は `n.at()` / `n.atPhrase()` の戻り値、文言は `n.t()` で渡す（長い英語・ベトナム語は文字を縮めるか 2〜3 行に折って枠に収める）。置く範囲 `box` の既定は型に合わせて自動（部屋の横型は人物の右から観葉植物の手前まで x 700〜1620 / y 250〜840、部屋の縦型はカウンターの下 = `useStage().closeUp`、ほかの型はコンテンツ領域の中央）。`useSceneBox()` で同じ範囲を取れる（部品の外、たとえば shared.swift では `sceneBox(LAYOUT_LANDSCAPE, .room)`）。部屋の縦型では、シーンの型を使う工程は拡大カード（`CloseUp`）を出さない（同じ範囲に重なる）。

| 部品 | 用途 |
|---|---|
| `PrepareItems(items:variant:box:maxScale:)` | 用意するもの。`items: [PrepareItem(label:at:w:h:origin:draw:)]`（`draw` は末尾のクロージャ `{ x, y, s in 道具 }`）。部屋の横型は `.counter`（人物の右のカウンターに上から落ちて並び、天板の前面に名前の札）、それ以外は `.cards`（カードの格子、2〜8 個）。`w` `h` は scale 1 での大きさ（既定 240×230 = マグくらい。幅は原点から遠いほうの端までの 2 倍 = 注ぎ口・取っ手を含める）。kit の道具は一覧画像のセルの `scale` から **w ≈ 300 ÷ scale**（例: FryingPan 0.55 → 約 550）、背の高い道具だけ **h ≈ 210 ÷ scale**（平たい道具は実際の高さ 60〜150）を目安にする（取っ手が片側に長い道具は少し大きめに: FryingPan は約 600）。cards ではカードの外にはみ出した部分は切り抜かれる。`draw` に渡す y は、手元俯瞰型では道具の中心（`h` の半分だけ底より上）、ほかの型では底（`origin: .bottom` / `.center` で変えられる）。cards は道具ごとに、カードに収まる倍率で描く（上限は `maxScale`、既定 1。布・スプーンなど実物が小さい道具は小さいままなので、大きく見せるなら `maxScale: 2` くらいにする）。counter は全部を同じ倍率で描くので大きさの関係が保たれる |
| `NoteCards(items:box:maxRow:)` | 注意点のカード。`items: [NoteItem(text:kind:at:icon:)]`、`kind` は `.ng` `.ok` `.warn` `.info`。縦に積まれ、種類の記号（NG 赤 ✕ / OK ✓ / 注意 ⚠ / 情報 i）と小さな絵が付く。`icon` は `{ … }` で、原点 = 中心で 80×80 くらいに描く。いま読んでいるカードは枠が太くなる。NG の文は赤字 |
| `NoteMark(x:y:kind:r:)` | 注意点の記号だけ（自前のカードや道具の横に） |
| `BeforeAfter(before:after:at:mode:beforeAt:box:dur:labels:)` | ビフォー・アフター。`before` / `after` は範囲を受け取るクロージャ `{ b in 絵 }`（画面座標で `b` の中に描く）。`.split`（既定）: 2 枚を並べ（横長なら左右、縦長なら上下）、`at` に after と矢印が出る。`.wipe`: 1 枚で、`at` から `dur` 秒（既定 1.2）かけて仕切りが左→右に動き after が現れる。見出しは言語に合わせて自動（ビフォー / アフター、Before / After …）、`labels: ("掃除前", "掃除後")` で差し替え |
| `SummaryList(items:at:doneAt:box:maxRow:) { 完成品 }` | まとめのチェックリスト。`items: [(label: String, at: Double)]` が各 `at` で順にチェックされる。`doneAt`（既定: 最後の項目の 0.8 秒後）にカード右上へ `CheckBadge` と `Burst`、末尾のクロージャ（完成品など画面座標で描く。省略可）がカードの手前にふわっと出る。完成品と並べるときは `box` を狭めてカードを片側に寄せ、空いた所に描く（例: 部屋の横型で `box: Box(x: 700, y: 250, w: 600, h: 590)`、完成品は x 1450 前後のカウンターの上） |
| `prepareLayout(items, box, maxScale:)` / `sceneBox(layout, variant)` | `PrepareItems` の counter の並び（道具ごとの底の中心 `x` と共通の `scale` の `[PrepareSpot]`。底の y は `counterY`。`items` は `[(w: Double?, h: Double?)]`）と、既定の範囲を、部品の外で求める。次の工程で道具を同じ位置・大きさから始めるときに shared.swift で使う |

```swift
// 用意するもの (句ごとに 1 つずつ落ちてくる)
Presenter(handR: mix(st.pose.restR, st.pose.gestureR, n.ease(0)))
PrepareItems(items: [
  PrepareItem(label: n.t("kettle", "やかん"), at: n.atPhrase(0, 0), w: 380) { x, y, s in Kettle(x: x, y: y, scale: s) },
  PrepareItem(label: n.t("mug", "マグカップ"), at: n.atPhrase(0, 1), w: 260, h: 180) { x, y, s in Mug(x: x, y: y, scale: s) },
])

// 注意点 (1 行に 1 枚)
NoteCards(items: [
  NoteItem(text: n.t("n1", "必ず電源を切ってから作業"), kind: .ok, at: n.at(0, 0.1), icon: { Icon(name: "shield", x: 0, y: 0, size: 70, color: "#315e4a") }),
  NoteItem(text: n.t("n2", "濡れたまま取り付けない"), kind: .ng, at: n.at(1, 0.1), icon: { Icon(name: "water", x: 0, y: 0, size: 70, color: "#4b9cc4") }),
  NoteItem(text: n.t("n3", "高い場所では転倒に注意"), kind: .warn, at: n.at(2, 0.1)),
])

// ビフォー・アフター (MyFilter は visuals/props.swift の道具)
BeforeAfter(
  before: { b in MyFilter(x: b.x + b.w / 2, y: b.y + b.h - 40, dirt: 1) },
  after: { b in MyFilter(x: b.x + b.w / 2, y: b.y + b.h - 40, dirt: 0) },
  at: n.atPhrase(1, 0), mode: .wipe
)

// まとめ
SummaryList(items: [(label: n.t("s1", "電源を切る"), at: n.at(0)), (label: n.t("s2", "ホコリを吸う"), at: n.at(1))], doneAt: n.at(2))
```

- `style.notes: false` のとき: `PrepareItems` は札を出さず道具だけ、`NoteCards` は文を消して「絵 + 記号」の四角いタイルを横に並べる、`SummaryList` は文の代わりに灰色の帯にチェックが入っていく。`BeforeAfter` の見出しは構図の一部なので消さない
- 部屋の縦型で項目が多い（注意点 6 個以上など）と、カウンターの下（高さ 420）では文字が小さくなる。`box: Box(x: 440, y: 340, w: 590, h: 1300)`（人物の右からカウンターの下まで）のように広い範囲を渡すか、2 シーンに分ける
- 部屋の横型（counter）で「用意するもの」の次の工程で道具を使うときは、`prepareLayout` の位置と倍率を shared.swift に置いて両方の工程で使う（終わりと始まりの状態がそろう）。cards（縦型・ほかの型）はカードのまま終わるので、次の工程は道具を置き直して始める。人物が手で触る道具は x 1150 くらいまでなので、触る道具を左寄りに並べるか、次の工程の頭で道具を移す
- 1 行に 1 項目（`n.at(i)`）で `NoteCards` / `SummaryList` を作った工程は、多言語版で文の数が減ると後ろの項目が出ない（無い行はシーンの外になる）。翻訳でも文の数をそろえる
- counter の並びは 1 列だけ。8 個並べると道具はかなり小さくなる（倍率 0.4 前後）。大きく見せたいときは `variant: .cards` と `box` を使う

## ガイドレイアウト（手順書・ハウツー動画）

script.json に `"layout": "guide"` を指定すると、部屋の背景（壁・丸窓・観葉植物・カウンター）、左上のシリーズ名／タイトル／`STEP 01` 工程バッジ、下部のクリーム色の字幕バー、工程ごとの進捗バー、クレジットが自動で付く。visual は「人物と道具」だけを描けばよい。

```jsonc
{
  "title": "急須で緑茶を淹れる",
  "layout": "guide",
  "guide": { "kicker": "DAILY RITUAL / TEA GUIDE", "palette": { "primary": "#315e4a" } },
  "credit": "ナレーション: macOS Sakura",   // 省略時は TTS 設定から自動
  "style": { "subtitleFontSize": 38, "maxCharsPerCaption": 40 },   // "captions": false で字幕バーなし、"notes": false で説明文なし
  "scenes": [{ "heading": "道具を準備する", "visual": "Prepare", "lines": ["…"] }]   // heading = 工程名
}
```

### 配置 (`GUIDE`)

| 名前 | 値 | 用途 |
|---|---|---|
| `GUIDE.counterY` | 780 | カウンター天板。道具は `y: GUIDE.counterY` に置く（原点 = 底の中心） |
| `GUIDE.presenter` | `Pt(380, 780)` | 人物の位置（全シーン共通にして、シーンが変わっても人物が動かないようにする） |
| `GUIDE.closeUp` | `Box(x: 640, y: 250, w: 960, h: 500)` | 拡大カードの範囲 |
| 左上 x 100〜900 / y 30〜210 | | 見出し領域。描かない |
| y 870 より下 | | 字幕バー・進捗の側。描かない |

色は `useGuide().palette`（`ink` `primary` `accent` `cream` `apron` `metal` `skin` `hair` `counter` など。どれも `Paint`）。

### 人物

`Presenter(handL:handR:x:y:smile:look:)` — 腕は肩から手まで伸び縮みする「ゴム腕」。**手の位置（画面座標の `Pt`）を渡すだけ**で腕が描かれる。読み上げ中は自動で口が動き、まばたき・呼吸もする。`smile`（0〜1）で笑顔（0.5 以上で目が「^ ^」）。完成・成功の場面で `smile: easeAt(n.frame, n.fps, n.at(1))` のように上げる。`look` は見た目（`.male` 男性＝短髪・太い眉・シャツの襟 / `.female` 女性＝流した前髪とポニーテール・細い眉 / `.neutral` 中性＝耳にかかる髪）。省略すると `script.json` の `guide.presenter`（既定 `neutral`）。手の位置・肩の位置はどの見た目でも同じなので、見た目を変えても手の座標は直さなくてよい。

- 定位置: `PRESENTER.restL` / `PRESENTER.restR`（下ろした手）、`PRESENTER.gestureR`（道具や拡大カードを指し示す）
- 道具を持つ: 道具のパーツ位置を `place()` で画面座標にして手に渡す
  ```swift
  let handle = place(kx, ky, 0.85, tilt, KETTLE_PARTS.handle)   // やかんの取っ手
  Kettle(x: kx, y: ky, scale: 0.85, angle: tilt)
  Presenter(handR: mix(PRESENTER.gestureR, handle, reach))      // reach: 0→1 で手を伸ばす
  ```
- `SleeveArm(from:to:bend:width:)` — 拡大カードの中で、カードの縁から伸びる袖と手（カードの中に人の胴を描く場面では、`from` はカードの縁ではなくその胴の肩。縁から遠くへ伸ばすと腕が長い帯になる。`from` から `to`（手）までは 400px 以内を目安にし、遠いときは付け根（胴を描くときは胴そのもの）を手に近づける）

### 道具（原点 = 底の中心、`x:y:scale:angle:`）

どの道具も引数は `x, y, scale = 1, angle = 0` が先頭で、その後に下の「追加の引数」が表の順に並ぶ（例: `Mug(x: 900, y: GUIDE.counterY, scale: 0.8, fill: 0.7)`）。パーツは `MUG_PARTS.rim` のように名前で読む（`Pt`）。

| 部品 | パーツ (`*_PARTS`) | 追加の引数 |
|---|---|---|
| `Kettle` やかん（注ぎ口が右） | `handle` `spout` | `color` `flip`（`true` で注ぎ口が左。パーツは `flipPart(KETTLE_PARTS.spout)`） |
| `Mug` マグ | `handle` `rim` | `fill` `drink` `color` |
| `Yunomi` 湯のみ | `rim` `grip` | `fill`(0〜1) `tea` `color` |
| `Teapot` 急須（横手） | `grip` `spout` `lid` | `color` `lidOpen`(0〜1) |
| `Canister` 茶筒 | — | `label` `lidOpen` |
| `Spoon` スプーン | `grip` `bowl` | `leaves`(Bool) |
| `DripBag` ドリップバッグ | `holdL` `holdR` `strip` `hookL` `hookR` `top` | `open`(帯を破る) `hooks`(フックを広げる) `wet` `water` |

家事・掃除・台所の道具（`Sources/JGVKit/guide/Household.swift`）。原点は特に書いていなければ底の中心:

| 部品 | パーツ (`*_PARTS`) | 追加の引数 |
|---|---|---|
| `Outlet` コンセント（原点 = 中心、`x:y:` のみ） | — | — |
| `Plug` プラグ（原点 = 刃の付け根、`x:y:angle:` のみ） | `grip` | `cordFrom`（コードの根元の画面座標。省略不可） |
| `PowerPlug(outlet:cordFrom:out:away:tilt:)` コンセントとプラグ（`outlet` = コンセントの中心） | — | `out`(0 = 差した、1 = 抜いた) `away` `tilt` |
| `Breaker` ブレーカー（分電盤の 1 回路分、原点 = 中心） | `leverOn` `leverOff` | `off`(0 = 入、1 = 切) |
| `Remote` リモコン（原点 = 中心） | — | `press`(0→1 で電波) |
| `Faucet` 蛇口（原点 = 吐水口） | — | `side`(`.left` / `.right`: 壁から伸びる側) `height` |
| `Sink` シンクの槽（原点 = 上辺の中心） | — | `w` `h` |
| `Basin` 洗面器 | `water` | `suds` `steam`(Bool) `color` |
| `Glove` ゴム手袋（置いた状態） | — | — |
| `GloveHand(x:y:r:on:)` 手袋をはめた手（原点 = 手の中心） | — | `on`(0〜1)。`Presenter` / `SleeveArm` の手の位置に重ねる |
| `Sponge` スポンジ | `grip` | `foam` |
| `ToothBrush` 歯ブラシ（寝かせた状態） | `grip` `head` | `color` |
| `Brush` 取っ手付きブラシ（原点 = 毛先） | `grip` | — |
| `Detergent` 洗剤ボトル | `grip` `nozzle` | `label` |
| `SprayBottle` スプレー | — | `color` |
| `Rag` たたんだ雑巾 | — | `wet` `color` |
| `Cloth` 手に持った布（原点 = 中心） | — | `color` `twist`(絞る) `wet` |
| `Towel` たたんだタオル | — | — |
| `NewsBundle` 新聞紙の束 | — | — |
| `NewsSheet(x:y:w:spread:stain:)` 敷いた新聞紙（原点 = 天板の中心） | — | `spread`(広げる) `stain` |
| `TrashBag` ゴミ袋 | `grip` `mouth` | `full` |
| `WipePack` ウェットシートのボトル / `WipeSheet` シート 1 枚（原点 = 中心） | — | `dirty`（WipeSheet） |
| `VacuumNozzle` 掃除機のノズル（原点 = 吸い込み口） | `grip`（`NOZZLE_PARTS`） | `on`(Bool) |
| `Cooktop` 2 口コンロ | — | `pot`(Bool、鍋) `flame` |
| `Laptop` ノート PC | `keysL` `keysR` `screen` | `on`。末尾のクロージャで画面の中（`LAPTOP_SCREEN` = 428×250、左上が原点）に描く |
| `Envelope` 封筒 | — | `open` |

効果: `Drips(x:y:w:fall:color:count:seed:)`（落ちる水滴・汚れ）、`Sparkles(x:y:w:h:on:count:seed:)`（きれいになった所のきらめき）、`Hearts(x:y:on:)`（立ちのぼるハート）

プラグを抜く・差す動き（`unplug` / `plugIn`）: `from`〜`to` でプラグが差した位置 ↔ 抜いた位置（既定はコンセントの左下 `PLUG_AWAY`、傾き `PLUG_TILT` 25°）を動く。手は `from` の 0.4 秒前からプラグの持つ所（`PLUG_PARTS.grip`）へ伸びる。
```swift
let m = unplug(n.frame, n.fps, PlugMoveOptions(outlet: OUTLET, from: n.atPhrase(2, 1, 0.1), to: n.atPhrase(2, 1, 0.7)))
// 差すときは plugIn(…)。抜く → 差すを 1 シーンでするなら、後半は plugIn の戻り値に切り替える
PowerPlug(outlet: OUTLET, cordFrom: CORD_FROM, out: m.out)
Presenter(handR: mix(mix(PRESENTER.restR, m.grip, m.reach), PRESENTER.gestureR, n.ease(3, -0.2)))
```
- 戻り値: `pos` `angle`（`Plug` を自分で描くとき）、`out`（`PowerPlug` に）、`grip`（手の位置）、`reach`（0→1、その後 1 のまま。手を離すのは visual 側で `mix`）
- コードが右から来るなど抜く向きを変えるときは `away: Pt(60, 90)`（`PlugMoveOptions` と `PowerPlug` の両方に同じ値）
- 差した / 抜いた位置だけ欲しいときは `plugSpots(outlet, away)` → `.in` / `.out`（`Pt`）
- ブレーカーを切る手: `place(BRK.x, BRK.y, 1, 0, mix(BREAKER_PARTS.leverOn, BREAKER_PARTS.leverOff, off))`

台所の道具（`Sources/JGVKit/guide/Kitchen.swift`）。原点は特に書いていなければ底の中心。取っ手が片側にある道具（`FryingPan` `Knife` `Ladle` `MeasuringCup` `MeasuringSpoon`）は既定で取っ手が右。`flip: true` で左右反転し、そのときのパーツは `place(x, y, s, angle, flipPart(XXX_PARTS.grip))` で求める:

| 部品 | パーツ (`*_PARTS`) | 追加の引数 |
|---|---|---|
| `Pot` 両手鍋 | `handleL` `handleR` `rim` `lid` | `lidOpen`(0〜1、ふたが右上へ) `lid`(false でふたなし) `fill` `soup` `steam`(0〜1) `color`。開けたふたのつまみは `potLidKnob(lidOpen)` |
| `FryingPan` フライパン | `grip` `center` `rim`（`PAN_PARTS`） | `food`(`.egg` `.veg` `.pancake`) `toss`(0〜1 であおる) `sizzle`(油はね) `flip`。末尾のクロージャで鍋肌の上（ローカル座標）に描く（`flip` しても左右反転しない） |
| `Knife` 包丁（横から、原点 = 刃の下辺の中ほど） | `grip` `edge` `tip` `spine` | `flip` |
| `CuttingBoard` まな板 | `top`（上に置く物の底。`CUTTING_BOARD_PARTS`） | `pieces`(切った輪切りの個数) `food`(その色) |
| `Bowl` ボウル（横から） | `rim` `gripL` `gripR` | `fill` `food` `color` |
| `MeasuringCup` 計量カップ | `handle` `spout` `rim`（`MEASURING_CUP_PARTS`） | `fill`(目盛り 4 本) `liquid` `flip` |
| `MeasuringSpoon` 計量スプーン | `grip` `bowl` `lip`（`MEASURING_SPOON_PARTS`） | `amount`(1 で山盛り) `color` `flip` |
| `Ladle` おたま（原点 = 器の底） | `grip` `bowl` `lip` | `fill` `soup` `flip`。注ぐときは負の角度（左へ傾ける）で `lip` から `Stream` |
| `Saibashi` 菜箸（原点 = 箸先） | `grip` `tip` | `open`(箸先を開く) `color` |
| `Microwave` 電子レンジ（幅 420） | `handle` `inside` `button` | `open`(扉が手前に倒れる) `on`(庫内の明かり) `display`(`"1:30"` など)。末尾のクロージャで庫内（`inside` が床の中心。扉を閉めても窓越しに見える）を描く。開けたときの取っ手は `microwaveHandle(open)` |
| `RiceCooker` 炊飯器 | `button` `rim` `lid`（`RICE_COOKER_PARTS`） | `open`(ふた) `display` `steam`。開けたときのふたの縁は `riceCookerLid(open)` |
| `Fridge` 冷蔵庫（高さ 600） | `handle` `shelf1` `shelf2` `shelf3` `drawer` | `open`(上の扉、右のちょうつがい) `color`。末尾のクロージャで庫内（棚の上面が `shelf1`〜`3`）を描く。開けたときの取っ手は `fridgeHandle(open)` |

- 鍋・フライパンを `Cooktop` に載せるときは、口の天板 `y = counterY - 30 * コンロの scale`、口の x は `コンロの x ± 110 * scale`。鍋 0.75・フライパン 0.8 とコンロ 1.1 なら、**鍋は左の口、フライパンは右の口**（柄が右へ伸びるので、フライパンを左の口に置くと柄が鍋に刺さる。左に置くときは `flip: true`）
- **冷蔵庫は床に立てる**: `Fridge(x: 1640, y: GUIDE.counterY + GUIDE.counterH, scale: 0.95)`（床 = y 870、x はおよそ 1490〜1790。上端は y 300 前後）。カウンターの上には置かない。人物から遠いので、扉を開ける場面は拡大カードで見せる
- おたまで鍋からすくう間は、おたまを鍋より先に描く（鍋の前面で器が隠れる）。持ち上げたら鍋の後に描く

**一覧画像 [props-catalog.png](props-catalog.png)** を Read すると、kit の道具の見た目・原点（赤）・パーツ（橙）を一度に確認できる。道具を選ぶ前に見る。kit に道具を足したら `Sources/JGVKit/PropsCatalog.swift`（または各ファイルの `CATALOG_*`）にも追加し、`jgv catalog` で作った `out/props-catalog.png` をこの画像と差し替える。

新しい道具は `Placed` を使って同じタッチで描く（描き方は [prop-style.md](prop-style.md)）。

演出: `Stream(from:to:color:width:active:)`（注がれる液体）、`Steam(x:y:count:height:opacity:)`（湯気）、`Grains(x:y:spread:count:color:size:seed:)`（茶葉・粉）、`Shadow(x:y:w:)`（置いた物の影。`y` の既定は天板）、`Callout(x:y:text:at:)`（小さな注釈）、`CheckBadge(x:y:at:r:)`（完了のチェック）

`place(x, y, scale, angle, localPoint)` で部品のローカル座標を画面座標へ、`mix(a, b, t)` で 2 点を補間する。逆に、部品のある点（スプーンの先・フォークの先・持ち手）を決めた位置に合わせたいときは `originFor(at, scale, angle, localPoint)` で原点を求める（包丁の刃先を切る位置に当てる: `let o = originFor(cutAt, 0.7, -10, TOP_KNIFE_PARTS.tip)` → `TopKnife(x: o.x, y: o.y, angle: -10, scale: 0.7)`）。手元俯瞰型の道具（原点 = 中心）にも使える。

注ぐ動き（`pourFrom`）: やかん・急須・湯のみ・洗剤ボトルなど、注ぎ口と持つ所がある道具を **持ち上げ → 傾けて注ぐ → 起こす → 戻す**。傾けきったとき注ぎ口がちょうど `target` に来るよう原点を逆算する。
```swift
let rim = place(MUG.x, MUG.y, 1, 0, MUG_PARTS.rim)
let k = pourFrom(n.frame, n.fps, PourOptions(
  from: n.atPhrase(0, 1, -0.4), to: n.endOf(0) + 6,   // 持ち上げ始め / 戻し終わり
  rest: KETTLE,                                        // 置いてある原点
  target: Pt(rim.x - 40, rim.y - 70),                  // 注ぎ口を持ってくる位置 (縁の少し上)
  angle: 40, scale: 0.85,                              // 注ぎ口が右なら正、左 (急須) なら負
  spout: KETTLE_PARTS.spout, grip: KETTLE_PARTS.handle
))
Mug(x: MUG.x, y: MUG.y, fill: k.poured)
Stream(from: k.spout, to: Pt(rim.x - 20, rim.y + 8), active: k.pouring)
Kettle(x: k.pos.x, y: k.pos.y, scale: 0.85, angle: k.tilt)
Presenter(handR: mix(PRESENTER.restR, k.grip, k.reach))
```

注ぎ先がやかんの左にあるときは、やかんを最初から `flip: true`（注ぎ口が左）で置き、`spout: flipPart(KETTLE_PARTS.spout)`・`angle` を負（例: `-38`）にして、描くときも `Kettle(x: k.pos.x, y: k.pos.y, scale: 0.85, angle: k.tilt, flip: true)` とする（置いてある工程も含め、全工程で `flip: true` にそろえる。持ち上げてから向きを変えない）。

| 戻り値 | 内容 |
|---|---|
| `pos` / `tilt` | 道具に渡す原点と角度 |
| `grip` | 手の位置（`Presenter` の `handR` / `handL`、`SleeveArm` の `to`） |
| `spout` | 注ぎ口の画面座標（`Stream` の `from`） |
| `pouring` | 傾けきって注いでいる間 true（`Stream` の `active`） |
| `poured` | 注いだ量 0→1（注ぎ先の `fill` に） |
| `reach` | 手を伸ばす度合い。`from` の少し前に 0→1、`to` の後に 1→0 |

- 急須なら `spout: TEAPOT_PARTS.spout, grip: TEAPOT_PARTS.grip`、`angle: -38`、洗剤なら `spout: DETERGENT_PARTS.nozzle`。湯のみを傾けて移すときは縁の端（`Pt(-66, -128)`）を `spout` にする
- 区間 `from`〜`to` が短くても各動きの時間を縮めて動く（1 秒程度でも可）
- 複数の注ぎ先へ順に注ぐ（1→2→2→1）ときは、区間ごとに `pourFrom` を呼び、`rest` に前の注ぎ位置を渡す

### 拡大カード

```swift
CloseUp(steps: [
  CloseUpStep("茶葉をすくう", at: n.atPhrase(0, 0)),   // 句ごとに小手順ラベルが切り替わる (番号 ①② は自動で付くので label に書かない)
  CloseUpStep("急須に入れる", at: n.atPhrase(0, 1)),   // 「② 急須に入れる」と表示される
]) {
  // GUIDE.closeUp の範囲に、大きめ (scale 1.2〜1.4) の道具と SleeveArm を描く
}
```

カードはシーン頭でポップインし、シーン末尾で縮んで消える。人物はカードの左で `gestureR` のまま指し示す。引数は `CloseUp(label:steps:at:box:enter:exit:) { … }`。

**拡大カードの工程が続くとき**は、前の工程を `CloseUp(exit: false)`、次の工程を `CloseUp(enter: false)` にして、境目でカードを開いたままにする（3 つ以上続くときは、間の工程に `enter: false, exit: false` の両方を付ける）。カードの枠は同じ位置のまま中身だけが次の工程に変わるので、前の工程の最後と次の工程の最初で、カードの中身（道具の位置・状態）もそろえる。片方だけに付けると、境目でカードが急に消える・急に現れる。`enter: false` のとき `at` は使われない。つなぐ工程どうしは `box` も同じにする。どの工程に付けるかは絵コンテの「始まりと終わりの状態」に書いてある。

### 句単位の同期

`n.atPhrase(行, k)` は行を読点・句点で区切った k 番目の句の開始フレーム。「急須と湯のみ、茶葉を用意します。」なら `atPhrase(0, 0)` で急須と湯のみ、`atPhrase(0, 1)` で茶葉を出す、のように **名詞が読まれた瞬間にその物を出す**。句の開始は、`jgv tts` が音声の無音（読点・句点の間）を検出して、実際に声が戻る時刻に合わせている（間を取らずに読んだ読点だけは文字数の比率で推定）。

**読点の無い行は句が 1 つ（`atPhrase(行, 0)` だけ）**。`atPhrase(行, 1)` は行の途中の推定時刻になり、意図した瞬間に動かない。行の中で動きを分けるときは `n.at(行, 秒)` や `n.endOf(行)` からの時間で指定する。各工程の行・句の番号と秒は `jgv timing`（`out/brief.md` にも同じ一覧が載る）で確かめる（台本に無い行の番号を渡すと、シーンの外のフレームになって何も起きない）。

### ガイドレイアウトの演出の型

- **全景（人物＋カウンター）**: 道具が句ごとに上から落ちて置かれる → 人物が手を伸ばして持ち上げ、傾けて注ぐ → 元に戻す
- **拡大カード**: 手元の細かい作業（開ける・すくう・注ぎ分ける・最後の一滴）。小手順ラベル ①②③ を句に合わせて切り替える
- 実際の待ち時間（蒸らし・抽出）はタイマー（`ArcTimer`、または `arcPath` + `CountUp`）で短縮表示し、`Callout` で「待ち時間は短縮しています」と断る
- 最後は完成品を持ち上げる＋ `CheckBadge`

## ガイドの型（layout）と縦型

| layout | 背景 | 主な部品 |
|---|---|---|
| `guide` | 部屋（壁・丸窓・観葉植物・カウンター） | `Presenter` と道具、`CloseUp` |
| `guide-screen` | やわらかい壁色と水玉 | `PhoneFrame` / `BrowserFrame`、`Tap` / `Cursor`、`Spotlight`、`StepNotes`、UI 部品 |
| `guide-topdown` | 真上から見た木目の作業台（見出しの下に座布団） | `TopHand`、`TopBowl` `TopPlate` `TopShaker` `Sprinkle` |
| `guide-manual` | 白い方眼紙 | `IsoBox`、`DashArrow`、`RotateArrow`、`PartTag`、`PartsList`、`Screw` `Screwdriver` |

縦型（`width < height`、1080×1920）は配置が自動で切り替わる。**縦型にも対応する visual は固定値 `GUIDE` / `PRESENTER` ではなく `useStage()` を使う**:

```swift
let st = useStage()   // st.counterY / st.presenter / st.closeUp / st.content / st.subtitle …（今の配置の値）と st.pose.restL / restR / gestureR
Presenter(handR: mix(st.pose.restR, st.pose.gestureR, n.ease(0)))
Mug(x: 680, y: st.counterY)
CloseUp { /* st.closeUp の範囲 */ }
```

- 横型: `content` = x 100〜1820 / y 230〜870、縦型: `content` = x 50〜1030 / y 320〜1650、拡大カードは y 1235〜1655（カウンターの下に常設）
- 縦型の工程バッジは `STEP 02 / 05` のように総数も出る

### 画面操作型（screen）

```swift
private let SAVE = Box(x: 40, y: 700, w: 310, h: 56)        // ボタンの設計座標 (UIButton にも同じ値を渡す)

func Save(_ props: Props) {
  let n = useNarration()
  let ph = phoneSpace(x: 560, y: 226, h: 652)               // スマホの左上と画面の高さ → 設計座標との対応
  let tapAt = n.atPhrase(0, 1, 0.4)
  let t = pressAt(n.frame, n.fps, tapAt)                    // (t: 波紋 0〜1, pressed, done)
  let finger = moveAlong(n.frame, n.fps, [(at: 0, p: ph.pt(Pt(300, 600))), (at: tapAt - 14, p: ph.center(SAVE))])
  Stage {
    PhoneFrame(x: ph.x, y: ph.y, h: ph.h) {
      UIButton(x: SAVE.x, y: SAVE.y, w: SAVE.w, h: SAVE.h, label: n.t("save", "保存"), pressed: t.pressed)
    }
    Spotlight(rect: ph.rect(SAVE), opacity: n.ease(0, 0.5), area: ph.box)   // area: スマホの画面の中だけ暗くする
    Tap(x: finger.x, y: finger.y, press: t.t)
    StepNotes(x: 1000, y: 270, w: 820, items: [(label: n.t("k1", "保存をタップ"), at: n.at(0))])
  }
}
```

| 部品 | 用途 |
|---|---|
| `PhoneFrame(x:y:h:time:dark:) { … }` | スマホ枠（中身は 390×844 の設計座標 = `PHONE.w` × `PHONE.h`）。ステータスバー・ノッチ・ホームバー付き |
| `BrowserFrame(x:y:w:url:) { … }` | ブラウザ枠（中身は 1280×720、アドレスバーの下が y 56） |
| `Tap(x:y:press:scale:)` / `Cursor(x:y:click:scale:)` | 指のタップ / マウスカーソル（波紋付き） |
| `Spotlight(rect:opacity:r:area:)` | `area`（既定はコンテンツ領域）のうち rect 以外を暗くし、枠で囲む（見出し・字幕は暗くしない）。画面操作型では `area: ph.box`（`phoneSpace` / `browserSpace` の戻り値の枠）を渡し、右のポイントメモを暗くしない。rect は area の中に収める（はみ出した所は逆に暗くなる） |
| `Camera(focus:zoom:) { … }` | ズーム（使うときは見出し・字幕にかからない倍率で） |
| `StepNotes(x:y:w:items:size:)` | 右側のポイントメモ。`items: [(label: String, at: Double)]` が順に現れ、次へ進むとチェック |
| `UIAppBar` `UIButton` `UIField` `UIListRow` `UIBanner` `UIText` | アプリ画面の部品（設計座標で使う。`UIButton(x:y:w:h:label:pressed:outline:color:size:)`、`UIField(x:y:w:h:label:value:placeholder:focus:caret:mono:select:size:)`、`UIText("文字", x:y:size:weight:color:anchor:mono:)` など） |
| `phoneSpace(x:y:h:)` / `browserSpace(x:y:w:)` | 設計座標 → 画面座標の `ScreenSpace`。`pt(p)`（点）、`rect(box)`（矩形、`Spotlight` に）、`center(box)`（ボタンの中心）、`k`（倍率）、`x y w h`（枠に渡す位置と実寸）、`box`（枠の範囲、`Spotlight` の `area` に）。`PhoneFrame` / `BrowserFrame` と同じ変換なので、タップ位置がボタンに正確に重なる |
| `moveAlong(frame, fps, [(at:p:)])` `pressAt(frame, fps, at)` `typed(text, frame, at, fps)` | 指 / カーソルの移動、押下、タイプ中の文字列 |

ブラウザの場合（キューの `notes`（ポイントメモ）を右に出すなら、ブラウザの右端を x 980 ほどまでにする。メモは x 1000 から幅 820）:
```swift
let br = browserSpace(x: 100, y: 250, w: 860)
BrowserFrame(x: br.x, y: br.y, w: br.w, url: "…") { … }
let c = br.center(SEND)   // Cursor(x: c.x, y: c.y)
```

### 手元俯瞰型（topdown）

- 原点はどれも中心。`TopHand(from: topArmFrom(手のひら, .R), to: 手のひら, angle: 指先の向き(0 = 上), cup: 丸め 0〜1, side: .L / .R)`
- 腕の付け根は `topArmFrom(手のひら, side)`（手の真下の画面の外。左手は `.L`。縦型なら 3 つ目に画面の高さ 1920 を渡す）にすると、手を左右に動かしても腕が画面を斜めに横切らない。手を引っ込めるときは手のひらを `topOffscreenY()`（横型 1170、縦型は `topOffscreenY(1920)`）より下へ動かす（そこより下では `TopHand` は描かれず、袖の端も字幕バーの下からのぞかない）
- 腕の付け根は画面下（字幕バーの下に隠れる）。両手で作業するときは左右から
- `TopBowl(x:y:r:color:fill:level:grains:)`（中身と粒）、`Sprinkle(x:y:r:amount:color:seed:)`（塩・ごま）
- 台所の道具（`Sources/JGVKit/guide/Kitchen.swift`）:
  - `TopCuttingBoard(x:y:w:h:color:)`（まな板、既定 560×360）
  - `TopVeg(x:y:kind:angle:scale:cuts:gap:)` — 野菜（`.carrot`（既定） `.cucumber` `.onion` `.tomato`）。横向きで右端から切り、`cuts`（0〜`vegMaxCuts(kind)`）回分の切れ端が右へずれて並ぶ
  - `TopKnife(x:y:angle:scale:lift:)` — 包丁（angle 0 で刃先が上、原点 = 刃の中ほど。**`angle` が `scale` より前**）。`TOP_KNIFE_PARTS.grip` を `place()` して `TopHand` の `to` に
  - `chop(frame, from, to, count)` → `cuts` `pos` `lift`。刻む動き: `cuts` を `TopVeg` に、`lift` を `TopKnife` に、包丁の x は `veg.x + vegCutX(kind, pos) * scale`（刃の真ん中が野菜に来るよう y は野菜より 60〜70 下）
    ```swift
    let ch = chop(n.frame, n.at(1), n.endOf(1), 8)
    let knife = Pt(VEG.x + vegCutX(.carrot, ch.pos) * VEG.s, VEG.y + 70)
    let grip = place(knife.x, knife.y, 1, 0, TOP_KNIFE_PARTS.grip)
    let press = Pt(knife.x - 150, VEG.y - 10)
    TopVeg(x: VEG.x, y: VEG.y, scale: VEG.s, cuts: ch.cuts)
    TopKnife(x: knife.x, y: knife.y, lift: ch.lift)
    TopHand(from: topArmFrom(grip, .R), to: grip, angle: -8, cup: 0.6)
    TopHand(from: topArmFrom(press, .L), to: press, angle: 70, cup: 0.8, side: .L)   // 猫の手で押さえる
    ```
  - `TopPan(x:y:r:angle:oil:sizzle:) { … }` — フライパン（angle = 柄の向き、0 = 右）。末尾のクロージャで中身を画面座標で描く。柄を握る位置は `topPanGrip(x, y, r, angle)`

### 組み立て説明書型（manual）

```swift
private let ISO = Iso(ox: 880, oy: 700, s: 4.4)   // 1 cm = 4.4 px

let u = useAssemble(n.atPhrase(0, 1))             // 1 → 0 (組み付け)
IsoBox(iso: ISO, x: 1.8, y: 34 * u, z: 29, w: 36.4, d: 28, h: 1.8, fill: "#f6eddd")
DashArrow(from: isoPoint(ISO, 20, 49, 30), to: isoPoint(ISO, 20, 15, 30), progress: n.progress(0, 0.5))
```

- 座標: x が右下、y が左下、z が上。見える面は上・左手前 (y = 最大)・右手前 (x = 最大)。**奥 (x・y が小さい) から手前の順に描く**
- `IsoBox(…, dashed: true)` で点線の輪郭（これから付ける位置の予告）
- `PartsList(x:y:w:title:items:)` は `items: [PartsListItem(letter:name:qty:at:)]`。句ごとに行が光る
- ほかに `RotateArrow(x:y:r:spin:color:opacity:)`、`PartTag(x:y:letter:to:opacity:)`、`Screw(x:y:angle:scale:)`、`Screwdriver(tip:angle:spin:)`

### 画面上の文言の多言語化

`n.t("キー", "既定の文")` は `script.json` の `strings[キー]` を返す（無ければ既定の文）。言語別の台本 `script.<言語>.json` の `strings` を翻訳すれば、同じ visual で多言語版になる。フォントは `lang` から自動選択（`fontForLang`）。

## SVG の素材（assets）

道具などの静止した見た目は、プロジェクトの `assets/<名前>.svg` に置いて `Svg("<名前>", …)` で描ける。ブラウザ・Finder のクイックルックで見られ、Inkscape・Figma などで直せる。ユーザーが持っている SVG（製品のロゴ・アイコン・イラスト）もそのまま使える。動き（いつ・どこへ）は visual の Swift で付ける。

```swift
let TIMER_PARTS = svgParts("kitchen-timer")     // part-… の印の位置 (原点からの座標)
let button = place(680, 760, 1, 0, TIMER_PARTS.button)   // 画面座標にする (kit の道具の XXX_PARTS と同じ)
Svg("kitchen-timer", x: 680, y: 760, scale: 1, angle: 0, flip: false, opacity: 1, layers: [
  "button": SvgLayer(transform: [.translate(0, 6 * press)]),  // 原点からの座標で動かす・回す
  "steam": .hidden,                                            // 隠す (display:none の要素を出すのは .shown)
  "soup": SvgLayer(opacity: water, fill: Paint("#f1dcae").mix("#c98a4a", soup)),  // 透明度・色を変える
]) {
  // 変わる文字・数字などは末尾の { } に Swift で描く。原点からの座標 (svgParts と同じ) で、SVG と一緒に拡大・回転する
  text(display, x: TIMER_PARTS.display.x, y: TIMER_PARTS.display.y, fontSize: 32, fill: "#9fe0b4", stroke: "none", textAnchor: .middle, dominantBaseline: .central)
}
```

- **原点**は `id="part-origin"` の要素の中心、無ければ viewBox の底の中心（kit の道具と同じ）。SVG の 1 単位 = 動画の 1 ピクセル（`scale: 1` のとき）。kit の道具に合わせて、人物の手に持つ大きさなら幅 100〜250 くらいで描く。`viewBox="-90 -140 180 140"` のように原点を (0, 0) にしておくと、SVG の座標と Swift の座標が同じ数になる
- **持つ所**は `id="part-<名前>"` の要素（小さな円など）で印を付ける。描かれず、中心の位置が `svgParts` の `<名前>` になる。重ねて描く文字の位置にも使える
- **レイヤー**は `id`（Inkscape のレイヤーは名前 = `inkscape:label` でもよい）を付けたグループか図形。visual から `layers: ["名前": SvgLayer(…)]` で、隠す（`hidden`）・透明度（`opacity`）・変形（`transform`。原点からの座標で、`.rotate(角度, 中心x, 中心y)` などを掛ける）・色（`fill` / `stroke`。中のすべての図形を塗り替える）を変える。動かしたい部分ごとにグループにしておく
- **配色の色**: `fill` / `stroke`（属性でも style でもよい）に `var(--ink, #353b35)` のように書くと、動画の配色（script.json の `guide.palette`）の色で塗る。名前は `ink` `primary` `accent` `skin` `hair` `apron` `cream` `metal` `counter` `counterEdge` `floor` `wallTop` `wallBottom` `windowRing` `windowGlass`。輪郭線は `var(--ink, …)` にしておくと、配色を変えても kit の道具とそろう。`,` の後ろはブラウザ・描画ツールで見える代わりの色（必ず書く）。`Svg(…, colors: ["ink": "#1d4e89", "label": "#d9534f"])` で名前ごとに上書き・追加できる。グラデーションの `stop-color` に書いた var は、配色ではなく代わりの色で描く。描画ツールで直して保存し直したら、var が残っているかを `jgv overview` の「配色の色」で確かめる
- **末尾の `{ }`** は `flip: true` のときも一緒に左右反転するので、文字は鏡文字になる。反転して使う道具の文字は、文字の位置を軸に戻す: `g(transform: flip ? [.translate(p.x, 0), .scale(-1, 1), .translate(-p.x, 0)] : []) { text(…, x: p.x, …) }`。中の図形は `Svg` を呼んだ所の線・塗りの属性を引き継ぐ（`Placed` の中なら ink・太さ 6）ので、文字には `stroke: "none"` を付ける
- 値で形そのものが変わる部分（めくれる紙の反り・液面の高さの曲線など）は SVG では表せない。その部分だけ末尾の `{ }` に Swift の `path` で描いて重ねるか、状態ごとのレイヤーを用意して透明度で切り替える
- 対応する要素は `g` `path` `rect` `circle` `ellipse` `line` `polyline` `polygon` `text`、塗りは単色と `linearGradient`（`radialGradient` は最初の色の単色）。`<image>` `<use>` は描かずに警告し、`clipPath` `mask` `filter` は無視して（切り抜き・効果の無い形で）描いて警告する。`<style>` のクラス以外のセレクタも警告する（描画ツールで「オブジェクトをパスに」「クローンを解除」してから保存する）
- 輪郭線の色・太さは SVG に書いたとおりに描く（`Placed` の中でも ink・太さ 6 を引き継がない）。kit の道具と並べるときは、線を `var(--ink, #353b35)`・太さ 6・`stroke-linecap="round"` `stroke-linejoin="round"` にそろえると馴染む（[prop-style.md](prop-style.md)）
- 見た目の確認は SVG のテキストを読むより、`jgv overview`（`out/overview.html` に原点・持つ所の印つきで並ぶ）か、`props.swift` の見本に `PreviewItem(name: "kitchen-timer", scale: 1, parts: svgParts("kitchen-timer")) { x, y, s in Svg("kitchen-timer", x: x, y: y, scale: s) }` を入れて `jgv preview`
- `jgv brief` は assets の SVG ごとに、大きさ・レイヤーの名前・配色の色・持つ所を工程担当の資料に載せる
