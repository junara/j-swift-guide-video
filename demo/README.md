# デモ

`j-guide-video` skill のデモ 10 本です。各デモは **原稿（`script.json`）** と、ナレーションに同期して画面全体を動かす **カスタム visual（`visuals/*.swift`）** のセットで、フォルダがそのまま動画のプロジェクト（`jgv.json`）です。

書き出した動画のナレーションは macOS の音声なので、個人的・非商用の利用に限られます（[生成した動画の利用条件](../README.md#生成した動画の利用条件)）。

```
demo/<デモ名>/
├── jgv.json             # 動画のプロジェクトの印
├── procedure.md         # 手順書 (jgv md2script で script.json に変換した元。01 は script.json だけ)
├── script.json          # 原稿・台本 (シーン、行、使う visual、画面上の文言 strings)
├── script.<言語>.json   # 多言語版の台本 (02 のみ: ja / zh / vi / uk)
└── visuals/
    ├── <Visual>.swift   # シーンごとの全画面アニメーション (大文字で始まるファイルの func <Visual>(_ props: Props) = visual)
    ├── props.swift      # このデモ専用の道具・画面 (小文字のファイルは visual として登録されない)
    └── shared.swift     # 複数シーンで共通の配置・動き
```

## デモ一覧

左上にタイトルと「STEP 01」工程バッジ、下部に字幕バー・進捗バー・クレジットが付く手順動画です。型（`layout`）ごとに見た目が変わります。

| デモ | 内容 | 型 | 形式 | 長さ | シーンの映像 |
|---|---|---|---|---|---|
| [01-green-tea-guide](01-green-tea-guide/) | 急須で緑茶を淹れる | 部屋 | 横 | 約47秒 | 部屋に立つ人物が、句ごとに置かれる道具を指し、やかんでお湯を注ぐ → 拡大カードで茶葉をすくう → 湯のみのお湯を急須へ・1 分タイマー → 拡大カードで 1→2→2→1 と注ぎ分け → 最後の一滴 → 湯のみを持ち上げて完成 |
| [02-drip-coffee-en](02-drip-coffee-en/) | How to Brew Drip Bag Coffee | 部屋・**多言語** | 横 | 約53〜63秒 | 道具が句ごとに置かれ 100→90°C → 拡大カードで帯を破って開封 → フックを広げてマグに掛け、確認して手を離す → 少し注いで 20 秒蒸らし → 3 回に分けて注ぐ → バッグを外して完成。英語に加えて日本語・中国語・ベトナム語・ウクライナ語版を同じ visual で書き出す |
| [03-address-book](03-address-book/) | Web のアドレス帳に連絡先を登録する | 部屋（画面 UI を拡大カードで） | 横 | 約75秒 | ノートPC と「アカウントが必要」バッジ → 拡大カードでログイン（URL・メール・パスワード入力→クリック）→ 左メニューから連絡先の一覧 → 「新規登録」→ 名前・メール・グループを入力 → 登録して完了通知 → 重複不可とスマホへの同期 |
| [04-aircon-filter](04-aircon-filter/) | エアコンのフィルターを掃除する方法 | 部屋 | 横 | 約102秒 | ホコリと効率低下 → リモコンで停止・プラグを抜く → 拡大でパネルを開ける・フィルターを外す・掃除機・裏から水洗い・日陰で乾燥 → 取り付けて運転確認 → 注意カード 3 枚 |
| [05-budget-app-screen](05-budget-app-screen/) | 家計簿アプリでレシートを記録する | **画面操作** | 横 | 約45秒 | ホーム画面から家計簿アプリをタップ → レシートを枠に合わせて撮影 → 日付・金額の自動読み取りと費目の選択 → 記録して一覧の先頭に追加 → グラフで今月の支出と予算の残りを確かめる。右側にポイントメモ、注目箇所以外を暗く |
| [06-onigiri-topdown](06-onigiri-topdown/) | おにぎりの作り方 | **手元俯瞰** | 横 | 約41秒 | 真上から見た作業台にご飯・塩・梅干し・海苔が並ぶ → ラップに塩とご飯 → 梅干しをのせてかぶせる → 両手で回しながら三角に → 海苔を巻いて皿へ |
| [07-mug-stain-vertical](07-mug-stain-vertical/) | マグの茶渋を落とす | 部屋・**縦型** | 縦 1080×1920 | 約23秒 | 上に人物と道具、カウンターの下の拡大カードにマグの内側。重曹 → ペースト → スポンジでくるくる → すすいでピカピカ |
| [08-shelf-assembly-manual](08-shelf-assembly-manual/) | カラーボックスの組み立て | **組み立て説明書** | 横 | 約40秒 | 部品の分解図と部品リスト → 棚板を差し込んでネジ留め → 天板・底板・反対側の側板 → 背板をはめる → 完成と耐荷重の注意 |
| [09-rabbit-cage](09-rabbit-cage/) | うさぎのケージを掃除する方法（ケージ・うさぎ・サークル・トイレ・掃除道具を `visuals/props.swift` に描画） | 部屋 | 横 | 約125秒 | 跳ねるうさぎときらめくケージ → 掃除道具が句ごとに並ぶ → 扉を開けて両手でサークルへ → トイレ・食器・おもちゃを出し、牧草と毛をゴミ袋へ → 拡大でトイレ（捨てる・シーツ交換・水洗い・拭く）と床（集める・シートで拭く・ブラシ） → 戻して牧草と水を補充 → うさぎを戻して扉を閉める → 注意カード 5 枚 |
| [10-range-hood](10-range-hood/) | キッチンの換気扇を掃除する方法（換気扇フード・フィルター・コンロ・掃除道具を `visuals/props.swift` に描画） | 部屋 | 横 | 約182秒 | 湯気を吸う換気扇に油汚れがたまり効率メーターが下がる → 道具 8 種が句ごとに並び新聞紙を敷く → スイッチを押して羽根が止まる・プラグを抜く（またはブレーカー） → 拡大で手袋・つまみを回して外す・新聞紙へ → シンクでぬるま湯・洗剤とスポンジ（泡）・歯ブラシで隙間 → すすぎ・タオル・乾燥タイマー → 雑巾を絞って本体を洗剤拭き・水拭き・乾拭き → 取り付けてつまみを戻し運転確認 → 注意カード 7 枚 |

型の選び方と実装の要点は [j-guide-video の SKILL.md](../.claude/skills/j-guide-video/SKILL.md) を参照してください。

## 使い方

### まとめて動画にする

リポジトリのルートで実行します（初回は jgv のビルドと kit のビルド（全デモで共有。1 回だけ）が走ります。デモごとには visual のビルド（数秒）だけです。各デモのフォルダに `.jgv/`（音声・timeline）と `out/` ができます。どちらも git 管理外）。

```bash
bash demo/run.sh
```

1 本だけ作る場合はデモ名を指定します。

```bash
bash demo/run.sh 05-budget-app-screen
```

各行のアニメーションの静止画一覧も作る場合:

```bash
SNAPSHOTS=1 bash demo/run.sh 05-budget-app-screen
```

出力先は `demo/out/` です（git 管理外）。

- `<デモ名>.mp4` — ナレーション・字幕・イラストのアニメーション付きの動画
- `<デモ名>.srt` — 字幕ファイル
- `<デモ名>.<言語>.mp4` / `.srt` — 多言語版（`script.<言語>.json` があるデモ。02 なら `.ja` `.zh` `.vi` `.uk`）
- `<デモ名>-sheet.png` — 各行の静止画一覧（`SNAPSHOTS=1` のとき）

### Claude Code から使う

```
demo/04-aircon-filter を参考に、浴室の排水口の掃除方法の動画を作って
```

```
この手順書を、demo/05-budget-app-screen のような画面操作の動画にして
```

```
demo/06-onigiri-topdown のように、卵焼きの作り方を真上から見た手元の動画にして
```

```
demo/02-drip-coffee-en のように、英語と中国語の版も作って
```

### 自分のプロジェクトで使う

```bash
.claude/skills/j-guide-video/bin/jgv init my-video
```

```bash
cp demo/05-budget-app-screen/script.json my-video/ && cp demo/05-budget-app-screen/visuals/*.swift my-video/visuals/
```

```bash
cd my-video && ../.claude/skills/j-guide-video/bin/jgv tts && ../.claude/skills/j-guide-video/bin/jgv render
```

多言語版のデモ（02）は `script.<言語>.json` もコピーして、`jgv build-langs` で全言語を書き出します。

## カスタム visual の読みどころ

### 共通

- **タイミングは行・句から取る**: `n.at(1)`（2 行目の開始）、`n.atPhrase(0, 1)`（1 行目の 2 つ目の句）、`n.progress(0, 0.8)`（1 行目から 0.8 秒で 0→1）、`n.endOf(1)`（2 行目の終わり）。秒数を直書きしていないので、原稿や声を変えても同期が保たれます
- **登場 → 変化 → 余韻**: `Draw` で線を描く → `Pop` で中身 → `Burst` / `Pulse` / `CheckBadge` で強調、の順に少しずつずらす
- **常に動かす**: 湯気・しずく・液面の揺れ・タイマーなど、ナレーション中ずっと何かが動いています
- **使い回し**: 複数シーンで共通の配置・動きは `shared.swift`、そのデモ専用の道具は `props.swift` にまとめる（同じモジュールなので import は要らない。ファイルの中だけで使うものは `private`）

### 型ごと

- **部屋**（01〜04、09、10）: 人物は全シーン同じ位置で、手の位置だけを動かす。道具の持ち手は `place(x, y, scale, angle, KETTLE_PARTS.handle)` で求めて手に渡す。注ぐ動作は 02 `shared.swift` の `kettlePour()`、題材専用の道具は 04 `props.swift`（エアコン・コンセント・フィルターなど）
- **画面操作**（05）: アプリの画面を `BudgetScreen(s: BudgetState)` に 1 つにまとめ、各シーンは state（ページ・入力値・押下中）を時間で変えるだけ。指は `moveAlong()`、押下は `pressAt()`、入力は `typed()`、注目箇所は `Spotlight`、右側に `StepNotes`
- **手元俯瞰**（06）: 作業台の常設アイテムを `TableItems` にまとめて全シーン同じ位置に。手は `TopHand`、ご飯の形は `ricePath()` で丸から三角へ変形
- **縦型**（07）: 配置は固定値でなく `useStage()`（`counterY` `pose` `closeUp`）から取るので、同じ部品が縦型でも使える
- **組み立て説明書**（08）: 部品を `PARTS`（cm 単位の直方体）で定義し、奥から手前の順に `IsoBox` で描く。組み付けは `useAssemble()`、ネジ締めは `screwing.swift` の `Screwing`
- **多言語**（02）: 画面上の文言は `n.t("open.step2", "Tear off the top strip")` で書き、各言語の `script.<言語>.json` の `strings` に翻訳を入れる

部品の一覧は [visual kit リファレンス](../.claude/skills/j-guide-video/reference/visual-kit.md) を参照してください。
