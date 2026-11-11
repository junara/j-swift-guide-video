# 道具（prop）の描き方

ガイドレイアウトの道具は、すべて同じタッチで描く。新しい道具はこのルールに従って `visuals/props.swift`（その動画専用）に描く。汎用的なものは、動画が完成した後でユーザーのライブラリに保存する（[library.md](library.md)）。描く前に [一覧画像](props-catalog.png) とプロジェクトの `parts/`（ライブラリの部品）で、似た道具が無いか確認する。

## タッチ

- **輪郭線**: 色 `palette.ink`、太さ 6（細部は 3〜5）、線の端・角は丸（`strokeLinecap: .round` `strokeLinejoin: .round`）。`Placed` で囲めば自動で付く
- **塗り**: フラットな単色。グラデーション・写実的な陰影は使わない。ハイライトは明るい色の太線 1 本程度（`Mug` の縦線のように）
- **配色**: `palette` の色（`primary` 深緑・`accent` テラコッタ・`metal` 青緑・`cream`・`apron`）と、木・紙・陶器の落ち着いた中間色。彩度の高い原色は避ける
- **形**: 角を丸めた単純な図形の組み合わせ。細かいディテールは描かない（ロゴ・文字は最小限）
- **大きさ**: scale 1 で、マグ ≈ 幅 245 × 高さ 175、やかん ≈ 幅 290 × 高さ 230 が基準。人物の手（半径 21）と釣り合う大きさにする
- **大きさの書き方**: 部品のコメントには、scale 1 での「幅 W × 高さ H」を書く（円や楕円も半径ではなく外形の幅と高さ。`PrepareItem` の `w` `h` にそのまま渡せる）。半径で書くと、読む人が幅と取り違える

## コードの形

```swift
// visuals/props.swift
import JGVKit

// ---------- フライパン (原点 = 底の中心、幅 500 × 高さ 80) ----------
// fill: 中身の量 (0〜1)。持つ・注ぐ位置は *_PARTS にローカル座標で書く
let SKILLET_PARTS = Parts(["handle": Pt(230, -40), "center": Pt(0, -50)])

func Skillet(x: Double, y: Double, scale: Double = 1, angle: Double = 0, fill: Double = 0) {
  let palette = useGuide().palette
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M 120 -40 L 250 -48", strokeWidth: 22)                        // 取っ手 (輪郭)
    path("M 120 -40 L 250 -48", stroke: palette.hair, strokeWidth: 12)  // 取っ手 (塗り)
    path("M -140 -70 L -120 -10 Q -115 0 -100 0 L 100 0 Q 115 0 120 -10 L 140 -70 Z", fill: "#4b5563")
    if fill > 0 { ellipse(cx: 0, cy: -70 + 50 * fill, rx: 130, ry: 14, fill: "#c08552", strokeWidth: 4) }
  }
}
```

- 引数は `x: Double, y: Double, scale: Double = 1, angle: Double = 0` を先頭に並べ、`Placed(x:y:scale:angle:) { … }` の中にローカル座標で描く（kit の道具と同じ並び。呼ぶ側が迷わない）。`Placed` は線の色・太さ・丸めも付ける
- 状態は 0〜1 の `Double` の引数にする（`open` `fill` `lidOpen` `hooks` `wet` など）。visual 側で `interpolate` してアニメーションさせる。オン・オフしかないものは `Bool`、種類は `enum`（`enum Lid { case open, closed }`）
- **追加の引数には必ず既定値を書く**（`fill: Double = 0`）。既定値の無い引数は呼ぶたびに書く必要があり、ほかの工程で使うときに書き忘れてビルドが止まる
- パーツは `Parts(["名前": Pt(x, y), …])` にして、`SKILLET_PARTS.handle` のように名前で読む（無い名前を読むと実行時に止まる）。傾けたときの持ち手・注ぎ口の位置は `place(x, y, scale, angle, SKILLET_PARTS.handle)` で求められる
- 名前は kit の部品・定数（一覧画像の名前、`PAN_PARTS` など）と重ねない（同じ名前を作ると kit のほうが隠れる）。props.swift の中だけで使う色や補助の関数は `private` にする
- 中の文字（ラベル）は `text(…, stroke: "none")` か `T(…)` で描く（`Placed` の中は線が付くので、`stroke: "none"` が無いと文字がふちどられる）
- 透明は `fill: "none"`（`fill: .none` は「外側から引き継ぐ」になり、黒く塗られる）
- 液体: `Stream`（注ぐ流れ）、`Steam`（湯気）、`Grains`（粉・葉・粒）を組み合わせる

## 道具の見本（`jgv preview`）

新しく描いた道具は、工程で使う前に見た目を確かめる。`visuals/props.swift`・`shared.swift` とライブラリの部品のファイル（`parts/*.swift`）に見本の一覧を置くと、`jgv preview` が `out/preview.png` に、[props-catalog.png](props-catalog.png) と同じ並べ方の一覧を描く（ファイルごとに見出し。`jgv preview props` のようにファイル名を渡すと、そのファイルだけ）。

見本の一覧の名前は **ファイル名を大文字にした名前 + `_PREVIEW`**（`props.swift` なら `PROPS_PREVIEW`、`shared.swift` なら `SHARED_PREVIEW`、ライブラリの `parts/pets.swift` なら `PETS_PREVIEW`）。行の頭から `let <名前>_PREVIEW: [PreviewItem] = [` と書く（この形で探して登録する。型の注釈を省かない）。

```swift
let PROPS_PREVIEW: [PreviewItem] = [
  // name: 部品名、note: 主な引数、scale: 一覧での倍率、dx / dy: 原点のずらし量、parts: 橙の点で描く、末尾のクロージャ: (x, y, scale) で描く
  PreviewItem(name: "Skillet", note: "fill", scale: 0.55, parts: SKILLET_PARTS) { x, y, s in Skillet(x: x, y: y, scale: s, fill: 0.6) },
]
```

- 引数は `PreviewItem(name:note:scale:dx:dy:parts:draw:)` の順（`note` `dx` `dy` `parts` は省略可。`draw` は末尾のクロージャに書ける）
- 1 コマは幅 320 × 高さ 300。原点は赤い点、点線は dx・dy が 0 のときの原点（底）の高さ。はみ出す大きな道具は `scale` を小さくする
- 名前に「/」を入れると（`Outlet / Plug` のように 2 つ並べるとき）、原点の赤い点は描かれない
- `jgv preview` はプロジェクト全体（すべての工程の visual）をビルドする。工程担当が並列で作業している間は、書きかけの visual でビルドが止まることがあるので、工程担当は実行しない（工程担当は `jgv snapshots --scene=N` で確かめる）
- **画面操作型の画面**（`AlarmScreen(s:)` のような状態を受け取る関数）も見本にできる。状態ごとに小さなスマホを描き、タップ位置（設計座標の点。矩形の左上ではなく、ボタンの中心の点を渡す）を `parts` に渡すと、橙の点がボタンの上に重なってタップ位置の誤りが分かる。原点（`x` `y`）をスマホの画面の左上にし、`scale` を「スマホの高さ ÷ 844」（`H / PHONE.h`）にする:

  ```swift
  private let H = 205.0   // 1 コマに収まるスマホの高さ
  private func mini(_ s: AlarmState) -> (Double, Double, Double) -> Void {
    { x, y, _ in PhoneFrame(x: x, y: y, h: H) { AlarmScreen(s: s) } }
  }
  let SCREENS_PREVIEW: [PreviewItem] = [   // screens.swift に置いた場合
    PreviewItem(name: "home", scale: H / PHONE.h, dx: -47, dy: -205, parts: Parts(["icon": APP.icon]), draw: mini(AlarmState(page: .home))),
    PreviewItem(name: "edit", scale: H / PHONE.h, dx: -47, dy: -205, parts: Parts(["save": APP.save]), draw: mini(AlarmState(page: .edit))),
  ]
  ```

## チェック

- `jgv preview`（`<名前>_PREVIEW` に並べた見本の一覧 `out/preview.png`）で、形が崩れていないか、`XXX_PARTS` の橙の点が持ち手・注ぎ口に乗っているか
- `jgv snapshots` で人物の手と持ち手の位置が合っているか
- ライブラリに保存する道具は、`XXX_PARTS` の座標が持ち手・注ぎ口などに合っているか（別の動画で `place()` して手を付けても合うように）
- 置いたとき底がカウンター天板（`GUIDE.counterY`）にぴったり乗っているか、`Shadow` の幅が道具の幅と合っているか
- 拡大カードで scale 1.3〜1.6 にしても線が太すぎ・細すぎにならないか
