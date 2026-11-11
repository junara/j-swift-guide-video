# 実例・調整・トラブルシュート

SKILL.md から参照する補足。必要になったときだけ読む。

## 実例

リポジトリにある場合は参照する:
- `demo/01-green-tea-guide/` — 日本語の急須で緑茶（拡大: 茶葉をすくう・注ぎ分け・最後の一滴）
- `demo/02-drip-coffee-en/` — `procedure.md` から作った英語版ドリップバッグコーヒー（全景: 準備・蒸らし・注ぐ・取り出す / 拡大: 開封・装着）。`visuals/shared.swift` にやかんの注ぎ動作。**多言語版**: `script.ja.json` `script.zh.json` `script.vi.json` `script.uk.json` を追加し、画面上の文言は `n.t()` と `strings`
- `demo/03-address-book/` — 部屋型で Web サービスの操作（ブラウザのアドレス帳の画面 UI を拡大カードで見せる）
- `demo/04-aircon-filter/` — 部屋型で家電の手入れ（壁掛けエアコン・コンセントを部屋に描き足す）
- `demo/05-budget-app-screen/` — 画面操作型（家計簿アプリの状態を `BudgetState` と `BudgetScreen` にまとめる）
- `demo/06-onigiri-topdown/` — 手元俯瞰型（ご飯の形が丸から三角に変わる `ricePath`）
- `demo/07-mug-stain-vertical/` — 縦型（部屋型 + 常設の拡大カード）
- `demo/08-shelf-assembly-manual/` — 組み立て説明書型（部品定義 `PARTS` と `ColorBox`、ネジ締め `Screwing`）
- `demo/09-rabbit-cage/` — 部屋型で家事（ケージ・うさぎ・掃除道具を `visuals/props.swift` に描き足す）
- `demo/10-range-hood/` — 部屋型で長めの家事（換気扇フード・フィルター・コンロを `visuals/props.swift` に描き足す）

## 調整

- 人物の見た目: `script.json` の `"guide": { "presenter": "female" }`（`male` 男性 / `female` 女性 / `neutral` 中性。既定は `neutral`）。1 つの工程だけ別の人物にするなら `Presenter(look: .male)`
- 配色: `script.json` の `"guide": { "palette": { "primary": "#315e4a", "accent": "#d98a5c", ... } }`（キーは skill の `Sources/JGVKit/guide/Theme.swift` の `GuidePalette`）
- クレジット: `"credit"` で上書き（既定は apple なら声の名前から自動、command と google / azure / amazon なら無し、openai なら「AI 音声 (OpenAI)」）
- 声・速さ: `"tts": { "voice": "auto", "rate": 0.48 }`（`jgv voices` で一覧。英語は `jgv voices en-US`）。command でつないだ TTS は、声も速さもそのスクリプトの側で決める。クラウドの TTS は `"tts": { "engine": "google", "voice": "ja-JP-Neural2-B" }` のように書く（`jgv voices --google` / `--azure` / `--amazon` / `--openai` で一覧。速さは変えられない）
- 毎回同じ kicker・配色・声・速さにする: ユーザーのライブラリの `defaults.json` に書く（[library.md](library.md)。声と速さは言語ごとに `voices` / `rates`。クラウドの TTS の声は `voices.google` / `voices.azure` / `voices.amazon` / `voices.openai`）
- 途中の 1 コマだけを見る: `cd <dir> && jgv still --frame=120 --scale=0.5`（`out/still.png`。`--at` で秒を指定するなら `jgv snapshots --scene=N --at=1.5`。N は 0 始まり）
- 書き出した動画からコマを抜き出す: `jgv snapshots --video=out/video.mp4`（描き直さない）

## 日本語の読み方

SKILL.md の「日本語の読み方を直す」の詳細。読みに直すときはカタカナで書く。

- `jgv yomi` で語ごとの読み（macOS の解析による目安）と警告を見て、意図と違う読み（額(がく)・便(びん)・砂(さ) など）を直す。警告は `jgv tts` の最後にも出る
- 警告が出るもの: ひらがなの読みが前後とつながる所、続けると音が変わる漢数字と助数詞（一本・一回・八分・三本）や解析が濁らせて読む二杯・四本（正しい読みを確かめて `イッポン` のようにカタカナにする。警告に出る読みの例は目安）、1 字の漢字が前後とつながらない読み（画面下 → 下(か)、時と分 → 分(ぶん)、この箱を → 箱(ばこ)）
- `speak` を直したら `jgv tts`（直した行だけ読み上げ直す）→ `jgv timing`（時刻の表を出し直す）
- ライブラリの `defaults.json` の `readings` に入れた語は `jgv md2script` が自動で `speak` に当てる（`library: 読み方の辞書 … を当てます` と出る）。ユーザーに読み方を指摘されたら、直した後で `readings` に足すかを聞く（SKILL.md の「7」）

## トラブルシュート

- `jgv check` の `!` の行: 名前の誤り（`binding に無い値`・`点 … が無い`・`置き場所 … が無い`）は bind.swift の `keys` `objects` `points` `places` に足すかキューの綴りを直す。`手が遠い` は道具を人物に近づける（定数 1 か所）。`… はまだ動いている` は、つまんだ物を動かし終わる前に手を離しているので、次の手の動きを遅らせる。`終わりの 0.5 秒前より後` は動きを早める。`押した後 … そのまま` は、押した後の行に `H>rest` などを足して指を離す。`… に重なる`・`… に隠れる`・`画面からはみ出す`（`! 秒-秒s:` の行）は、注釈の点をずらす（`+dx,dy`）か、binding の点・置き場所を動かす（[cue.md](cue.md)）
- キューの動きがナレーションより遅れる・早い: 手（`H>` `C>` `P`）は「着く時刻」、値は「始まる時刻」。`jgv check` の手の時刻表（`H 1.23-1.73s …`）と読み上げの時刻を見比べる
- キューを直したのに静止画が変わらない: `jgv snapshots --scene=N` の出力は `out/snapshots/scene-N/`（全体の `out/snapshots/` は前のまま）

- `jgv render` / `jgv snapshots` がビルドで止まる: 表示されたエラーの行（`visuals/Pour.swift:12:5: error: …`）のファイルを直す。よくある原因は、引数の順番（Swift はラベル付き引数を宣言の順にしか書けない。`fill` → `stroke` → `strokeWidth` → … → `opacity` → `transform` の順）、Double と Int の混在（`Double(i)` で変換）、kit の関数と同じ名前のローカル変数（`path` `rect` `g` など。名前を変えるか `JGVKit.path(…)`）、ほかのファイルと同じ名前の関数・定数（ファイルの中だけで使うものは `private`）
- `unable to type-check this expression in reasonable time`: 長い式（数値の計算を何段も重ねた式）を、途中の値を `let` に分けて短くする
- `parts/`（ユーザーのライブラリの部品）でビルドが止まる: プロジェクトの `parts/` は直さず、[library.md](library.md) の「使うとき」の手順で `<library>/parts/` を直すか、使わないファイルをプロジェクトの `parts/` から削除する
- skill を更新した後、kit の新しい部品を使いたい: そのまま使える（プロジェクトは skill の kit を参照している）。`jgv vendor-kit` で kit を `kit/` に固定したプロジェクトは、`kit/` を消すか `jgv vendor-kit` をやり直す
- skill を更新したら、前に作った動画の見た目が変わった: 前の見た目のまま書き出したいプロジェクトは、更新する前に `jgv vendor-kit` で kit を固定しておく
- 前の形式のプロジェクト（`Package.swift`・`Kit/`・`Sources/Video/` がある）で「jgv migrate で今の形式にしてください」と出る: そのプロジェクトで `jgv migrate`（visual を `visuals/`、ライブラリの部品を `parts/`、timeline と音声を `.jgv/` に移し、`Kit/`・`Package.swift`・`.build` を消す。台本と `out/` はそのまま）
- ディスクが足りない: 動画のビルドは全プロジェクトで共有の `~/Library/Caches/j-guide-video/shared-<ハッシュ>/` に、実行ファイルの写しはプロジェクトごとに `~/Library/Caches/j-guide-video/projects/` にある。`jgv clean --stale` で、フォルダを消したプロジェクトの分・共有のビルドにする前のプロジェクトごとのビルド・置き場の無くなった skill の共有のビルドと jgv のビルド（`build-*`）を消す。消しても次のビルドで作り直す。全部消すなら `rm -rf ~/Library/Caches/j-guide-video`（`J_GUIDE_VIDEO_CACHE` で置き場を変えているときは、そのフォルダごとではなく中の `build-*`・`shared-*`・`projects`・`avtts` だけ。全部消すとクラウドの TTS を認めた印も消え、次の `jgv tts` でまた `--allow-cloud` が要る）
- `assets/<名前>.svg` が描かれない・形が違う: `jgv dev` / `jgv snapshots` などの描くときの出力の `WARN: assets/…` を見る（`<image>` `<use>` は描かない。clip-path・mask・filter は無視して、切り抜き・効果の無い形で描く）。描画ツールで「パスに変換」してから保存し直す。ファイルが無いと赤い破線の枠が出る
- `apple` で思った声にならない: `jgv voices` で identifier を確認し `voice` に指定する。コンパイルしたバイナリからはニューラル音声が見えないため、`jgv tts` は合成の部分を `swift` コマンドで直接実行している（起動に約 1 秒かかるので、未生成の行を最大 8 並列で生成する。生成した音声はキャッシュされ、文と設定が変わった行だけ作り直す）
- 字幕や句のタイミングが少しずれる: 句読点の区切りは音声の無音（読点・句点の間）に合わせているが、間を取らずに読んだ読点や、長い字幕を途中で分けた所は文字数の比率で推定している。気になる場合は文を短く分けるか、区切りたい所に読点を入れる
- フォントが豆腐になる: `style.fontFamily` にマシンにある日本語フォントを指定（例: Hiragino Sans）
- `jgv voices` で声の名前が「声2」などと出る: 表示名は OS の言語設定による。identifier（例: `…Sakura_ja-JP_premium`）で見分ける
- `visual "X" が見つかりません`: `visuals/X.swift` のファイル名と、その中の `func X(_ props: Props)` の名前、script.json の名前（大文字小文字）を揃える
- アニメーションがカクつく・毎回違う: `Date()` や `Double.random` を使っていないか確認（フレームから計算する。乱数は `random("seed")`）
- `jgv` の初回の起動が遅い / ビルドに失敗する: 初回は jgv 自体をビルドする（数十秒〜数分。ログは `~/Library/Caches/j-guide-video/build-*/build.log`）。swift-argument-parser の取得にネットワークが要る
- `jgv new` がエラーで止まった: 作ったものは消して元に戻っているので、表示された原因を直して同じ `jgv new` をやり直す
- `前の jgv new が途中で止まっています`: `jgv new` を Ctrl-C などで中断すると巻き戻せないので、次の `jgv new` がそう知らせる。続けるなら `cd <dir> && jgv tts && jgv timing`（成功すれば印は消える）。やり直すなら、jgv new が新しく作ったフォルダならフォルダごと、前からあったフォルダなら jgv new が作ったもの（メッセージに名前が出る）だけを消してから同じ `jgv new`。前からあったファイルは消さない
- `<dir> には既に jgv.json があります` / `既に procedure.md があります`: そこは既にプロジェクトか、手順書が置いてある。置いてある procedure.md を使うなら手順書を渡さずに `jgv new <dir>`。既存のプロジェクト（`jgv new` を Ctrl-C で中断したものを含む）なら `cd <dir>` して続ける: `script.json` が無ければ `jgv md2script procedure.md -o script.json --stubs visuals <オプション>` から、あれば `jgv tts` → `jgv timing`（SKILL.md の 2）。作り直したいときはフォルダごと消してから `jgv new`
- `jgv.json がありません`: プロジェクトの中で実行していない。`cd <dir>` する（`new` / `init` / `md2script` / `api` / `voices` / `clean --stale` 以外はプロジェクトの中で実行する。`brief` / `overview` は引数でプロジェクトのディレクトリを渡してもよい）
- `… がシンボリックリンクです`: `.jgv/`・`.jgv/narration/`・`out/snapshots/`・`kit/`・`parts/`・雛形を書く `visuals/`・`cues/`、`jgv build-langs` のときの `.jgv/timeline.json`・`out/subtitles.srt`、`jgv migrate` の移す元と移す先は、jgv がその中のファイルを消すので、シンボリックリンクにできない（リンクの先のファイルを消さないため）。ふつうのフォルダにする（`out/` を別のディスクへのリンクにできるのは `jgv tts`・`jgv render`・`jgv build-langs` だけ。`jgv snapshots` と、それを呼ぶ `jgv dev` は、前回の静止画を消すので `out/`・`out/snapshots/` がリンクだと止まる）
- 中断（Ctrl-C）: jgv は、書き出し・ビルド・音声の合成をしている子のプロセスも一緒に止める。書き出しは隠しファイル（`out/.video.mp4.writing-<プロセスの番号>.mp4`）に書いてから名前を変えるので、中断しても `out/video.mp4` は前に書き出したもののまま（壊れない）。隠しファイルは次の `jgv render` が消す。音声は書き終えた行だけキャッシュに残る
