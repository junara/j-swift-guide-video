# visual の実装ルール

> 工程全体を Swift の visual で書くとき（キューで書けない動きが多いとき）の手順。ふだんはキュー（[cue.md](cue.md)）で書く。SKILL.md の 3〜4（binding とキュー）の代わりに、ここの「流れ」で進める。

visual を書くときのルール。工程担当には `jgv brief` がこの型に必要な節だけを抜き出して渡す（この文書と visual-kit.md の見出しを変えたら `Sources/JGVTools/Brief.swift` も直す）。

型ごとの部品と配置は **[visual-kit.md](visual-kit.md) の「ガイドレイアウト」と「ガイドの型」節** を読む。縦型にも対応するよう、配置は `useStage()`（`counterY` `presenter` `pose` `closeUp` `content`）から取る。

## 流れ（Swift の visual で書くとき）

1. `jgv new` のときに `--swift-stubs` を付ける（`jgv md2script procedure.md -o script.json --stubs visuals --swift-stubs` でも同じ）。キューの雛形の代わりに、工程ごとの仮の visual `visuals/<Visual>.swift` ができる。キューで作り始めた後に 1 工程だけ Swift にするなら、その工程の `CueScene` の 1 行を `func <Visual>(_ props: Props) { … }` の本実装に置き換える（キューの工程と混ぜてよい）
2. **絵コンテ**: 工程ごとに見せ方・道具・句ごとの動き・始まりと終わりの状態を `<dir>/storyboard.md` に書く（[storyboard.md](storyboard.md)）
3. **共通の土台**: 複数の工程で使う配置・動き（`visuals/shared.swift`）、新しい道具（`visuals/props.swift`。[prop-style.md](prop-style.md)）、画面操作型の画面の状態の struct と描画関数を、工程を書く前にメインで作り、`jgv preview` / `jgv snapshots` が通ることを確かめる
4. **工程の実装**: `jgv brief` で `out/brief.md` を作り、工程ごとに並列のサブエージェントに任せる（[scene-agent.md](scene-agent.md)。工程が少なければメインで順に書いてもよい）。各工程は `jgv snapshots --scene=N --phrases` で確かめる
5. 全員の報告がそろったら `jgv snapshots --seams`（工程の境目。visual の登録表はビルドのたびに作り直される）→ SKILL.md の 5（`jgv dev` → `jgv render` → `jgv overview`）へ

## 型ごとの要点

- **部屋**: 下の必須ルールのとおり
- **画面操作**: `PhoneFrame(x:y:h:) { … }`／`BrowserFrame(x:y:w:url:) { … }` の中を設計座標（スマホ 390×844、ブラウザ 1280×720）で描く。画面の状態（ページ・入力値・押下中・トースト）を 1 つの struct と描画関数（例: `BudgetScreen(s: BudgetState)`）にまとめ、各工程はその state を時間で変えるだけにする。設計座標と画面座標の変換は `phoneSpace(x:y:h:)`／`browserSpace(x:y:w:)` の `pt` `rect` `center` を使う（自前の `toScreen` を書かない）。操作は `moveAlong()` で指／カーソルを動かし `pressAt()` で押す、入力は `typed()`、注目箇所は `Spotlight(rect:opacity:area: ph.box)`（スマホ・ブラウザの画面の中だけを暗くする）、右側に `StepNotes(x:y:w:items:)` で「いま何をしているか」を大きく出す。画面の UI は `UIAppBar` `UIButton` `UIField` `UIListRow` `UIBanner` を組み合わせる
- **手元俯瞰**: 道具は真上から見た図（`TopBowl` `TopPlate` `TopShaker` `Sprinkle`、台所の `TopCuttingBoard` `TopKnife` `TopVeg` `TopPan` と刻む動き `chop()`、題材固有のものは `visuals/props.swift`）。手は `TopHand(from: topArmFrom(手のひら, .R), to: 手のひら, angle:, cup:)`（付け根は手の真下の画面の外）。作業台の常設アイテムは共通の関数にして全工程で同じ位置に置く
- **組み立て説明書**: 部品を `IsoBox`（等角図の直方体）で定義し、奥から手前の順に描く。組み付けは `useAssemble(at)` でずらし量を 1→0 にし、`DashArrow` で動きの向きを示す。ネジは `Screw` と `Screwdriver(tip:angle:spin: true)`＋`RotateArrow(x:y:spin: true)`、部品は `PartTag` と `PartsList`（句ごとに行が光る）
- **縦型**: 部屋型は上半分が全景、カウンター下の拡大カード（`useStage().closeUp`）を常に表示して手元を見せる（シーンの型を使う工程は、型がその範囲を使うので拡大カードは出さない）。拡大カードの工程どうしの境目は `exit: false` / `enter: false` でつなぎ、カードを開いたままにする（シーンの型の工程の前後だけ開閉する）。字幕は 1 行 18 字程度
- **説明文**: `style.notes: false`（`--no-notes` / `--no-text`）のときは `Callout`・`StepNotes`・拡大カードの小手順ラベルが自動で消える。それ以外に visual に直接書く説明の文字は `if n.notes { … }` で囲み、消えても絵と動きだけで工程が分かるようにする
- **終わりの状態へ向かう動き**（どの型でも）: 道具を片付ける・置く・手を戻すなど、工程の「終わり」の状態へ向かう動きは、工程の最後の 0.5 秒前（`n.durationInFrames - n.fps * 0.5`）までに終える。工程の最後の約 0.4 秒は拡大カードが縮むので、確認用の静止画（`--phrases` の右端、`--seams` の左端）はこの時刻で撮る。台本の既定の間（`gap` 0.45・`sceneGap` 0.9）では、最後の行の読み終わり（`n.endOf(最後の行)`）からこの時刻まで約 0.4 秒しかないので、片付けは最後の行を読んでいる間に始める（読み終わりから始めると間に合わない）
- **多言語にする予定があるもの**: 画面上の文言（注釈・小手順ラベル・ポイントメモ）は `n.t("キー", "既定の文")` で書く

## 共通の必須ルール（部屋型）

`visuals/<Visual>.swift` の仮実装を本実装に置き換える。部品と API は **[visual-kit.md](visual-kit.md) の「ガイドレイアウト」節を読んでから書く**。必須ルール:

- **人物は全シーン同じ位置**: `Presenter(handL:handR:)`（位置は既定の `GUIDE.presenter` のまま）。手の位置だけを動かす。シーン頭は `PRESENTER.restR`/`gestureR` から始め、道具へは `mix(定位置, 持ち手, reach)` で手を伸ばす
- **道具を持つ**: 道具の原点・角度から `place(x, y, scale, angle, XXX_PARTS.handle)` で持ち手の画面座標を求めて手に渡す。注ぐ動きは `pourFrom()`、プラグを抜く・差す動きは `unplug()`／`plugIn()` と `PowerPlug` を使う（visual-kit.md の例。自前で逆算しない）。注ぎ口や取っ手のある道具は、注ぎ先・人物の側に向けて置く（やかん・フライパン・おたまなどは `flip: true` で左向き。工程の途中で向きを変えない）
- **タイミング**: `n.atPhrase(行, 句)` で名詞・動詞が読まれた瞬間に動かす。秒数の直書きはしない
- **置き場所**: 道具は `y: GUIDE.counterY`（カウンター天板）、`Shadow` を添える。左上の見出し領域（x 100〜900 / y 30〜210）と y 870 より下（字幕バー側）には描かない。注釈（`say` / `timer`）の白い吹き出しは、窓や明るい壁の上に置くと読みにくいので、背景の濃い所か道具の近くに置く
- **拡大カード**: `CloseUp(steps: [...]) { … }` の中に、`GUIDE.closeUp` の範囲で大きめ（scale 1.3〜1.6）の道具と `SleeveArm(from: カードの縁, to: 手の位置)` を描く（カードの中に胴を描く場面では、`from` はカードの縁ではなくその胴の肩）。人物はカードの左で指し示す。絵コンテの「始まり」「終わり」に「拡大カードは開いたまま」とあれば、`CloseUp(enter: false)` / `CloseUp(exit: false)` にする
- **複数工程で共通の配置・動き**（マグの位置、この動画の道具の定位置を入れた `pourFrom` の呼び出しなど）は `visuals/shared.swift` にまとめる（小文字のファイル名は visual として登録されない。同じモジュールなので import は要らない）
- **止まった画面を作らない**: 湯気・揺れ・液面・しずく・タイマーなど、ナレーション中は常に何かが動いているようにする

## 道具が足りないとき（全型共通）

まず **[props-catalog.png](props-catalog.png) を Read して** kit にある道具を確認する（飲み物の道具に加え、コンセント・リモコン・蛇口・シンク・洗面器・手袋・スポンジ・ブラシ・洗剤・雑巾・タオル・新聞紙・ゴミ袋・掃除機のノズル・コンロ・ノート PC・封筒・コンセントとプラグ・ブレーカー、台所の鍋・フライパン・包丁・まな板・ボウル・計量カップ・計量スプーン・おたま・菜箸・電子レンジ・炊飯器・冷蔵庫、水滴・きらめき・ハートなど。props は visual-kit.md の「道具」）。

無い道具は **[prop-style.md](prop-style.md) のルールで新しく描く**。その動画だけで使うものは `visuals/props.swift` に置く。ほかの題材でも使えそうなものは、動画が完成した後でユーザーに聞いて、ユーザーのライブラリ（`<library>/parts/`）に保存する（[library.md](library.md)）。次の動画で描く手間が減る。skill 本体の `Sources/` には入れない（skill を更新すると消える）。

新しく描く前に、プロジェクトの `parts/`（ライブラリの部品。`jgv init` がコピーする）も確認する。
