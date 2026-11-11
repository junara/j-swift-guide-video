# 台本とプロジェクトの細かいこと（`jgv init` / `jgv md2script`）

SKILL.md の「2. プロジェクトを作り、台本に変換する」の補足。

- `<dir>` はユーザー指定、未指定ならカレント配下の `j-guide-video/` など。プロジェクトの中身は `jgv.json`（印）・`procedure.md`・`script*.json`・`cues/`（工程ごとのキュー）・`visuals/`（binding・キューを呼ぶ 1 行・新しく描いた道具）・`parts/`（ライブラリの部品）・`assets/`（SVG の素材）・`out/`（動画・字幕・確認用の画像）・`.jgv/`（timeline と音声。途中の生成物）。kit は常に skill の版を使う（skill を更新すると次のビルドから新しい kit になる。固定したいときは `jgv vendor-kit`）
- 前の形式のプロジェクト（`Package.swift`・`Kit/`・`Sources/Video/` がある）は、そのプロジェクトで `jgv migrate` を実行してから使う
- 言語は本文から自動判定（かながあれば `ja-JP`、ハングル → `ko-KR`、漢字だけ → `zh-CN`、それ以外 → `en-US`）。`--lang en-GB` などで指定可。音声は、その言語でインストール済みの最高品質の macOS の声が自動で選ばれる（apple のとき）
- 読み上げだけで伝え、画面に文字を出したくないときは `--no-text`（字幕バーと説明文＝注釈・ポイントメモ・拡大カードの小手順ラベルを出さない）。字幕だけ消すなら `--no-captions`、説明文だけ消すなら `--no-notes`。あとから変えるときは `script.json` の `style.captions` / `style.notes` を `false` にして `jgv tts`。タイトル・工程バッジ・進捗バーは残り、`out/subtitles.srt` は書き出される
- ライブラリに `parts/` があれば、`jgv init` が `parts/` にコピーする（`library: … をコピーしました` と出る。プロジェクトの `parts/` に同じ名前のファイルが既にあれば上書きせず、そう知らせる）

## jgv new のオプション

SKILL.md の「2」の `jgv new` のオプションの詳細（オプションは `jgv md2script` と同じ）。

- 部屋の型の人物は `--presenter male`（男性）/ `female`（女性）/ `neutral`（中性。既定）で選ぶ。ユーザーが人物の性別・見た目を指定したときだけ付ける。あとから変えるときは `script.json` の `guide.presenter` を書き換える
- `<dir>` はユーザー指定、未指定ならカレント配下の `j-guide-video/` など。言語は本文から自動判定（`--lang en-GB` などで指定）
- ライブラリに `defaults.json` があれば、kicker・型・人物の見た目・配色・声・速さ・字幕と説明文の表示の既定値になる（`library: … を既定値にしました` と出る）。コマンドのオプションが優先するので、**defaults.json に `kicker` / `layout` があるなら、ユーザーが指定したときと、0 で選んだ型が違うときだけ `--kicker` / `--layout` を付ける**。`defaults.json` を使わないときは `--no-library`（ライブラリの `parts/` のコピーは止まらない）
- クラウドの TTS にするなら `--tts google` / `azure` / `amazon` / `openai`（`jgv md2script` はキーの環境変数が無くても台本を作り、`jgv tts` がそう伝えて止まる。`jgv new --tts …` は何も作る前に止まる）。`command` は defaults.json に `tts.command` があるときだけ `--tts command` で選べる（無いと md2script が止まるので、付けずに作ってから `script.json` の `tts` を書き換える）。defaults.json の `tts.engine` が設定済みなら付けなくてよい
- **`jgv new` がエラーで止まったら**（`--tts command` の設定不足・言語の声が無いなど）、`jgv new` は自分で作ったものを消して元に戻す（`jgv new が作ったものを消して元に戻しました` と出る。前からあったファイルはそのまま）。原因を直して、同じ `jgv new` をやり直す。Ctrl-C などで中断したときは元に戻らないので [tips.md](tips.md#トラブルシュート) のトラブルシュートを見る
- 画面に文字を出さない（`--no-text` / `--no-captions` / `--no-notes`）、プロジェクトの中身、前の形式のプロジェクト（`jgv migrate`）は、このファイルの上の項目
