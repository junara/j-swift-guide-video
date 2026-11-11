# キューで書いた完成例

型ごとの、キュー（`cues/*.cue`）と binding（`visuals/bind.swift`）で書いた動画のプロジェクト。どれも今の kit で `jgv check` が「OK: 問題なし」になる。キューと binding を書く前に、同じ型の例を 1 つ読み、似た動きはそこから書き写す（書き方は [../reference/cue.md](../reference/cue.md)）。

| フォルダ | 型 | 題材 | 見どころ |
|---|---|---|---|
| `room-microwave-rice` | 部屋 | 冷凍ごはんの温め方（4 工程） | SVG の道具（`assets/microwave.svg`、扉を開ける）、物を運ぶ・置く（`dish@PLATE`）、表示のカウントダウン（`cd`）、円弧タイマー（`timer`）と「待ち時間は短縮しています」、拡大カードでラップを外す・ほぐす・盛る、`shrink` で全景へ戻ってチェック。新しく描いた道具は `visuals/props.swift` |
| `room-mug-wash` | 部屋 | マグカップの洗い方（4 工程） | 拡大カードを工程をまたいで開いたままにする（`card.exit=0` / `card.enter=0`）、スポンジでこする往復（`wave`）、落ちてくる道具（`drop`）。道具はすべて kit |
| `screen-alarm` | 画面操作（スマホ） | スマホでアラームを設定する（4 工程） | `hand: .finger`、タップ（`P 点`）の後に指を離す（`H>rest`）、画面の切り替え（`page=…`）、注目の枠（`spot`）、右のポイントメモ（`notes`） |
| `topdown-cucumber` | 手元俯瞰 | きゅうりの塩もみ（3 工程） | `hand: .none` で両手を `TopHand` で描く（右手 `H`・左手 `C`）、刻む動き、手の待機位置を画面の外に置く |
| `manual-smallbox` | 組み立て説明書 | 小物入れの組み立て（3 工程） | `IsoBox` の板を値で組み付ける、`Screwdriver` を `H` の位置に描く、部品リスト（`parts`） |
| `vertical-coffee` | 縦型（部屋） | インスタントコーヒーの入れ方（3 工程） | 1080×1920、下の拡大カードを全工程で開いたまま、湯気（`steam`） |

各フォルダの中身: `procedure.md`（手順書）・`script.json`（台本）・`visuals/bind.swift`（binding）・`visuals/<工程>.swift`（キューを呼ぶ 1 行）・`cues/<工程>.cue`・必要なら `visuals/props.swift` `visuals/shared.swift` `assets/`。

動かして見るときは、フォルダごと別の場所に写してから、そのフォルダで `jgv dev`（音声 → ビルド → `jgv check` → 静止画）を実行する（skill のフォルダの中には生成物を作らない）。時刻の表は `jgv tts` の後に `jgv timing` で出る。
