---
name: j-guide-video
description: 手順書（Markdown やテキスト）から、イラストの手順動画（MP4。Swift で描くアニメーション＋ナレーション＋字幕）を作る。左上にタイトルと「STEP 01」工程バッジ、下部に字幕バーと進捗バー。型は 5 種類：部屋に立つ人物が道具を持って作業する「部屋」（拡大カードで手元）、スマホ・ブラウザの画面をタップ／クリックで操作する「画面操作」、真上から作業台に手が伸びる「手元俯瞰」、線画の等角図と矢印で見せる「組み立て説明書」、1080×1920 の「縦型」。料理・家事・掃除・アプリや Web サービスの操作・家具の組み立て・機器の設置・手入れなどの「やり方」「作り方」「手順」「マニュアル」「使い方」「How to」「チュートリアル」の動画や、手順書・説明書・メモを動画にしたい依頼、既にこの skill で作った動画の手直し・多言語版（日本語・英語・中国語・ベトナム語など）の追加に使う。ナレーションは既定では macOS の音声で、書き出した動画は個人的・非商用の利用に限る（Apple の使用許諾）。公開・業務に使うなら Google・Azure・Amazon・OpenAI のクラウドの TTS（環境変数にキーを入れるだけ）か、コマンドでつないだ TTS に切り替える。
license: MIT
compatibility: macOS（最新の Xcode が動く版。動作確認は Apple シリコン）の Claude Code（CLI・デスクトップアプリ・IDE 拡張）専用。シェル実行と、最新の Xcode か Command Line Tools（swift。描画・書き出し・読み上げをすべて Swift で行う）が必要。初回だけ swift-argument-parser の取得にインターネット接続が要る。Node.js・ffmpeg は使わない。Linux・Windows・Claude Code on the web・Claude.ai は非対応。既定の macOS の音声では、使用許諾により書き出した動画は個人的・非商用の利用に限る
---

# イラスト手順動画（ガイドレイアウト）

手順書の 1 工程 = 1 シーン。ナレーションの句に合わせて、道具を取り、注ぎ、開け、タップし、組み付ける。描画・音声・書き出しはすべて Swift（CoreGraphics・AVFoundation）で行い、CLI `jgv` が台本・音声・字幕・静止画・動画の書き出しをまとめて受け持つ。

- `<skill>` はこの SKILL.md のディレクトリ（`${CLAUDE_SKILL_DIR}`。使えなければ、plugin で入れたときは `${CLAUDE_PLUGIN_ROOT}/.claude/skills/j-guide-video`、それ以外は `~/.claude/skills/j-guide-video` か `.claude/skills/j-guide-video` の、あるほう）
- **以下の `jgv` は `<skill>/bin/jgv` のこと**。初回と skill を更新した後だけ、自分自身と kit（描画 DSL と部品）を Swift でビルドするので数十秒〜数分かかる。ビルドはキャッシュ（`~/Library/Caches/j-guide-video/`）に置き、動画のプロジェクトには題材ごとのファイル（台本・binding・キュー・SVG の素材）だけが入る（仕組みは [reference/environment.md](reference/environment.md)）。ユーザーにキャッシュを消してと頼まれたら `jgv clean --stale --dry-run` で消すものを見せてから `jgv clean --stale`、全部なら既定の置き場 `rm -rf ~/Library/Caches/j-guide-video`（消しても次のビルドで作り直す）。`J_GUIDE_VIDEO_CACHE` で置き場を変えているときは、そのフォルダごとは消さず、中の `build-*`・`shared-*`・`projects`・`avtts` だけを消す（専用のフォルダとは限らないため）
- 引数とオプションは `jgv help <サブコマンド>` で出る。知らないオプションはエラーになる
- `<library>` はユーザーのライブラリ（環境変数 `J_GUIDE_VIDEO_LIBRARY`、未設定なら `~/.config/j-guide-video`。`XDG_CONFIG_HOME` があればその下）。前の動画で作った道具・動き（`parts/`）と好みの設定（`defaults.json`）が入っていて、skill を更新しても消えない（[reference/library.md](reference/library.md)）

```
procedure.md ─(jgv new = init・md2script --stubs・tts・timing)→ script.json・キューと binding の雛形・音声・timeline・字幕・時刻の表
visuals/bind.swift (道具・画面の描き方と名前) + cues/<工程>.cue (句ごとの動き) ─(jgv check → jgv dev → jgv render → jgv overview)→ out/video.mp4
```

## はじめに確認すること

### 動作環境

- **macOS（最新の Xcode が動く版。動作確認は Apple シリコンのみで、Intel Mac は未確認）上の Claude Code 専用**。Linux・Windows（WSL2 を含む）・Claude Code on the web・Claude.ai では使えないことを伝えて止める
- 必要なのは最新の Xcode か Command Line Tools（`swift`。`xcode-select --install`。古い版は確かめていない）。`jgv` は足りない・古いと止まるので、インストール方法をユーザーに伝える（`sudo` が要るものは勝手に実行しない）。初回の `jgv` のビルドだけネットワークが要る
- ナレーションは既定で macOS の声（`"voice": "auto"` で台本の言語の最高品質の声。一覧は `jgv voices`）
- 商用で使える TTS は、組み込みのクラウドの TTS と、任意のコマンドでつなぐ `command`。クラウドの TTS はキーを環境変数に入れるだけで使える: `google`（`GOOGLE_TTS_API_KEY`。サービスアカウントの鍵なら `GOOGLE_APPLICATION_CREDENTIALS`）・`azure`（`AZURE_SPEECH_KEY`・`AZURE_SPEECH_REGION`）・`amazon`（`AWS_ACCESS_KEY_ID`・`AWS_SECRET_ACCESS_KEY`・`AWS_REGION`）・`openai`（`OPENAI_API_KEY`。モデルが 2027-01-06 に停止予定なので、長く使う動画には勧めない）
- **キーやスクリプトはユーザーが用意する。Claude は API キーを入力・表示せず、サービスアカウントの鍵のファイル（`GOOGLE_APPLICATION_CREDENTIALS`）も開かず、勝手に有料の API を呼ばない**
- **ユーザーが作ったのではない動画のプロジェクト（zip・他人のリポジトリ・`--base` に渡す他人の台本）を扱うときは、`jgv` を実行する前に** `script.json` と `script.<言語>.json`（`jgv tts` などに渡す台本すべて）の `tts`（`engine` が有料のクラウドの TTS か、`command` に何が書いてあるか）と、`visuals/`・`parts/`・`kit/` の Swift のファイルがあることをユーザーに示して確かめる。`jgv tts` / `timing` / `dev` / `check` / `snapshots` / `still` / `preview` / `catalog` / `render` / `build-langs`（音声を作る・visual をビルドして描くコマンドすべて） は、それらのコマンドとコードをそのまま実行する
- 有料のクラウドの TTS は、プロジェクトと engine ごとに一度 `jgv tts --allow-cloud` で認めるまで呼ばれない（`jgv tts` が行数・字数を出して止まる）。**`--allow-cloud` は、その engine と料金がかかることをユーザーに伝えて OK をもらってから付ける**（`jgv new --tts …` と、ライブラリの `defaults.json` の engine で `jgv new` した台本は自動で認められる。`jgv new --base` で他人の台本のクラウドの engine を引き継ぐときは、`jgv new` が何も作る前に止まって `--tts` で選ぶよう伝える）
- 声・速さ・各 TTS の設定・ディスク・キャッシュの仕組みは [reference/environment.md](reference/environment.md)

### 生成した動画の利用条件

- **macOS の音声（既定の `apple`）**: Apple の macOS 使用許諾（「Voices」の項）では、システムの音声を使えるのは自分のオリジナルの作品を個人的・非商用に作る場合だけ。**書き出した動画は個人的・非商用の利用に限り**、SNS・動画サイトへの公開や、仕事・会社での利用（社内向けのマニュアルも含まれると読める）には使えない（要約。原文は macOS の使用許諾の「Voices」の項）
- **`google` / `azure` / `amazon` / `openai` / `command` でつないだ TTS**: その TTS の利用規約に従う。商用で使える TTS なら公開・業務にも使える。クレジットや AI 音声であることの表示を求める TTS なら `script.json` の `credit` に書く
- **依頼が SNS・動画サイトへの公開や、仕事・会社での利用に見えるときは、作業を始める前に** これをユーザーに伝え、商用で使える TTS に切り替えられることも伝える。法的な判断はしない（Apple の使用許諾や、使う TTS の利用規約を確認するよう伝える）

## 0. 型を選ぶ

題材から型を決めてユーザーに一言伝える（迷う場合だけ確認する）。プロジェクトを作る場所（2 の `<dir>`）も、ここで一緒に伝える。

| 型 | `--layout` | 見た目 | 向いている題材 | 完成例（[examples/](examples/README.md)） |
|---|---|---|---|---|
| 部屋 | `guide`（既定） | 部屋に同じ人物が立ち、道具を持って作業。細かい手元は拡大カード | 飲み物・家事・家電の手入れなど「人が道具を扱う」もの | `room-microwave-rice`, `room-mug-wash` |
| 画面操作 | `guide-screen` | 人物なし。スマホ／ブラウザの画面をタップ・クリック・入力で操作。右にポイントメモ、注目箇所以外を暗く | アプリ・Web サービスの操作手順 | `screen-alarm`（スマホ） |
| 手元俯瞰 | `guide-topdown` | 真上から見た作業台に画面下から両手が伸びる | 料理・工作・ラッピングなど手元が主役のもの | `topdown-cucumber` |
| 組み立て説明書 | `guide-manual` | 白い方眼紙に線画の等角図、点線の矢印、ネジ締め、部品リスト | 家具の組み立て・機器の設置・部品交換 | `manual-smallbox` |
| 縦型 | 上のどれか + `--vertical` | 1080×1920。部屋型なら上に人物、カウンターの下に拡大カードが常に出る（動作確認は部屋型のみ） | スマホの縦画面で見る短い生活の小技・レシピ | `vertical-coffee` |

多言語版が必要でも、まず 1 言語で完成させてから「6. 多言語版を作る」で追加する。

## 1. 手順書を用意する

ユーザーの文章を次の Markdown にまとめ、`<dir>/procedure.md` に保存する（既にこの形式ならそのまま使う）。

```markdown
# How to Brew Drip Bag Coffee
## Get ready [prepare]
Prepare a mug, a drip coffee bag and a kettle. Boil the water and let it cool to about ninety degrees Celsius.
## Open the bag [open]
Hold the bag with both hands, tear off the top strip along the marked line. Open it gently to avoid spilling the coffee.
```

- `# タイトル`、`## 工程名 [tag]`、本文はそのまま読み上げる。tag は任意で visual 名になる（`open` → `Open`）。英字で始まる英数字・`-`・`_` だけで、それ以外は無視されて `Step01` などになる
- 箇条書き・番号付きリストは 1 項目 = 1 文。強調・リンク・インラインコードの記法は外して読む（HTML のタグとコメント、コードブロックは読まない。`<Enter>` `<URL>` のようなキーの名前・書き換える所の山かっこは残す）。日本語・中国語は改行も文の区切り（読点で終わる行は次の行へつながる）、英語などは空行が段落の区切り。文末の句点が無ければ補う。表（`| … |` の行）とコードブロックは読み上げない（表を外したときは警告が出る）
- 工程は 4〜8 個、1 工程 1〜3 文。**1 文 = アニメーションの 1 区切り、読点（, 、）= さらに細かい区切り**になるので、「何を → どうする」が句で分かれる文にする（例:「Spread the paper hooks, attach them to the rim of your mug.」）
- 実際の待ち時間（蒸らし・乾燥など）は動画内では短縮する前提で書く
- ユーザーの文章が説明書・メモなど自由な形のときは、[reference/rewriting.md](reference/rewriting.md) の基準で手順書に書き換える

## 2. プロジェクトを作り、台本に変換する

```bash
jgv new <dir> --kicker "DAILY RITUAL / COFFEE GUIDE" --layout guide
```

`jgv new` は 1 回で、プロジェクトを作り（`jgv init`）、台本とキューの雛形を作り（`jgv md2script procedure.md -o script.json --stubs visuals`）、音声と timeline を作り（`jgv tts`）、キューの時刻の表（`jgv timing`。工程ごとの `行.句` と工程の始まりからの秒）を出す。手順書は `<dir>/procedure.md` を使う（別の場所にあるなら `jgv new <dir> <手順書>` で渡すと写す）。オプションは `jgv md2script` と同じ。**後のコマンドは `cd <dir>` してから実行する。**

- `<dir>` は、ユーザーが場所を指定していればそこにする。指定が無ければ聞かずに、skill とそれを入れたリポジトリの外（例: `~/Movies/jgv/<題材>`）に作る。どちらのときも、作る前に（0 で型を伝えるときに）フルパスで伝える（例:「`~/Movies/jgv/shoulder-massage` に作ります。別の場所がよければ言ってください」）。カレントの下に作ると、リポジトリの中に `out/`・`.jgv/` の生成物ができることがある
- `--layout` は 0 で選んだ型。縦型は `--vertical` を足す。`--kicker` は左上のシリーズ名
- 人物の見た目（`--presenter`）、ライブラリの `defaults.json` との関係、クラウドの TTS（`--tts`）、文字を出さない（`--no-text` など）、前の形式のプロジェクト（`jgv migrate`）は [reference/options.md の「jgv new のオプション」](reference/options.md#jgv-new-のオプション)。**defaults.json に `kicker` / `layout` があるなら、ユーザーが指定したときと、0 で選んだ型が違うときだけ `--kicker` / `--layout` を付ける**
- **`jgv new` がエラーで止まったら**、`jgv new` は自分で作ったものを消して元に戻す（前からあったファイルはそのまま）。原因を直して、同じ `jgv new` をやり直す（中断したときは [reference/tips.md](reference/tips.md) のトラブルシュート）

できるもの（この時点で最後まで通して動く）: `script.json`、工程ごとの `cues/<Visual>.cue`（先頭に `行.句` の番号と文の注釈）、`visuals/<Visual>.swift`（キューを呼ぶ 1 行。触らない）、`visuals/bind.swift`（binding の雛形）、`.jgv/timeline.json`、`out/subtitles.srt`。

### 日本語の読み方を直す

- 日本語は `script.json` の各行の `speak` で、数字・英字・難読語を読みやすくする。**読みに直すときはカタカナで書く**（ひらがなは前後のひらがなとつながって区切りを誤る。「食欲やはいせつぶつ」→「や／は／いせつ…」。`ハイセツブツ` なら誤らない）
- `jgv yomi` で語ごとの読みと警告を見て、意図と違う読みを直す。`jgv yomi` は engine にかかわらず macOS の解析で読むので、クラウドの TTS では目安にする（カタカナに直すのはどの engine でも効く）（警告の種類と直し方は [reference/tips.md の「日本語の読み方」](reference/tips.md#日本語の読み方)）
- `speak` を直したら `jgv tts`（直した行だけ読み上げ直す）→ `jgv timing`（時刻の表を出し直す）
- ユーザーに読み方を指摘されたら、直した後でライブラリの `defaults.json` の `readings` に足すかを 7 で聞く

## 3. 道具と画面を決める（binding）

各工程で見せる物（道具・機器・画面）、置き場所、手を着ける所を決め、`visuals/bind.swift`（`jgv new` が雛形を作る）に **binding** として書く。全工程で共通の 1 つ。書き方は **[reference/cue.md](reference/cue.md) の「binding」**。

- **書く前に、同じ型の完成例を 1 つ読む**（[examples/README.md](examples/README.md) の一覧から選び、その `visuals/bind.swift` と `cues/*.cue` を Read。似た動き・道具の置き方はそこから書き写す）
- 道具は kit の部品とプロジェクトの `parts/`（ライブラリの部品）を優先する。見た目は [reference/props-catalog.png](reference/props-catalog.png) を Read、一覧は [reference/visual-kit.md](reference/visual-kit.md) の「道具」。引数・持つ所（`KETTLE_PARTS` など）は `jgv api やかん`（名前・日本語の名前・説明の語で引ける。`jgv api` だけで名前の一覧。プロジェクトの `parts/` も出る）で調べ、kit のソースを grep しない
- 無い道具は [reference/prop-style.md](reference/prop-style.md) のルールで `visuals/props.swift` に描き、見本（`PROPS_PREVIEW`）を `jgv preview` で確かめる。ユーザーが持っている SVG は `assets/` に置いて `Svg("名前")` で描ける（visual-kit.md の「SVG の素材（assets）」）
- 道具の定位置・倍率は名前付きの定数にする（`let MW = Pt(1080, GUIDE.counterY)`。縦型は `LAYOUT_PORTRAIT.counterY`）。直すときに 1 か所で済む
- **人物が手で触る道具・機器は、人物から近い所（横長なら x 1150 くらいまで）に置く**（`jgv check` は手が遠いと警告する）
- 「用意するもの」「注意点」「ビフォー・アフター」「まとめ」の工程は、kit のシーンの型（`PrepareItems` `NoteCards` `BeforeAfter` `SummaryList`）を binding の描き方で使える
- 型ごとの見た目の要点は [reference/implementation.md](reference/implementation.md) の「型ごとの要点」

## 4. 工程の動きをキューで書く

工程ごとに `cues/<Visual>.cue` を書く。時刻 `行.句` の番号は、雛形の先頭の注釈（`# 0.0 冷凍ごはんを、 0.1 ラップのまま、…`）と `jgv new` / `jgv timing` の時刻の表。文法は **[reference/cue.md](reference/cue.md)**。似た動きは同じ型の完成例（[examples/](examples/README.md)）のキューから書き写す。**キューは数行〜十数行なので、工程担当のサブエージェントは使わず、メインで全工程を続けて書く。**

```
init <Load
0.0+.3 H>mw.handle~.45
0.0+.35 mw.open=0~.6
0.2+.45 P mw.start;mw.on=1~.2;mw.disp=cd 2:00 0:00@1.0;timer timer 2分@1.0
1.1+.7 H>dish.gripL~.4;dish.in=0
1.1+.77 dish@PLATE~.5;steam dish.top
```

- 句ごとに「何を → どうする」を 1 行ずつ書く（名詞・動詞が読まれる句の時刻に動かす）。待ち時間は円弧タイマー（`timer`）と注釈「待ち時間は短縮しています」
- **手（`H>` `C>` `P`）は「着く時刻」、ほかは「始まる時刻」**。手の動きに値を合わせるときは、値の時刻を手の動きの長さだけ前にする
- 2 つ目からの工程は `init <前の工程` で始める（終わりの状態を引き継ぐ）。拡大カードを続けて開いたままにするなら、前の工程に `card.exit=0`、次の工程に `card.enter=0`
- 細かい手元（開ける・すくう・こする・ねじる）は拡大カード（`card`・`C>`）で見せる。人物はカードの左で指し示す（`H>gesture`）。最終工程は完成品＋チェック（`check`）＋湯気・きらめきの余韻
- **止まった画面を作らない**: 湯気・揺れ（`wave`）・波紋など、ナレーション中は何かが動いているようにする

```bash
cd <dir> && jgv check
```

`!` の行（名前の誤り・手が遠い・つまんだ物を動かしている途中で手を離す・終わりの 0.5 秒前より後の動き・文字や枠の重なり など）が無くなるまで、キューと binding を直す。`H` / `C` の行は手の時刻表（何秒〜何秒に、どこからどこへ）。`S1→S2` の行は工程の境目で違う値（わざと変えたものだけが出ていればよい）。キューだけを直したときはビルドしないので、すぐ確かめ直せる。行の読み方と直し方は cue.md の「jgv check」。

キューで書けない特別な動きは binding の描き方に Swift で書き、キューから値で動かす（cue.md の「Swift で書くとき」）。工程全体を Swift の visual で書く前の書き方（絵コンテ → 工程担当の並列実装）も使える（[reference/implementation.md](reference/implementation.md)）。

## 5. 全体の確認 → 書き出し

```bash
cd <dir> && jgv dev
```

`jgv dev` は確認をまとめて 1 回で行う: `jgv tts`（変わった行だけ読み上げ直す）→ ビルド → `jgv check`（`!` があればここで止まる）→ 前回の `jgv dev` から変わった工程だけ `jgv snapshots`。

- binding などのコンパイルエラーは `visuals/bind.swift:12:5: error: …` のようにファイル名と行番号付きで出る
- 最後の `確認する画像:` の行に Read する一覧が出る。初回と、Swift のファイル・`assets/`・配色などを変えたとき、すべての工程が変わったときは全体の `out/snapshots/sheet.png`。キューだけを変えたときは変わった工程の `out/snapshots/scene-N/sheet.png`（`init <前の工程` で引き継ぐ工程も含む）。台本を変えると動画の長さが変わって進捗バーが動くので、たいてい全体になる。すべて撮り直すなら `jgv dev --all`
- **`確認する画像:` の一覧を必ず Read で開いて確認し**、直してから `jgv dev` をやり直す（変わった工程だけを撮り直したときは、全体の `out/snapshots/sheet.png` は前のまま残るので取り違えない）。手の時刻のずれは画像より `jgv check` の手の時刻表で見る方が速い
- 一覧で小さくて見えない所（点線・注釈の文字・手と持ち手の位置）は、同じフォルダの 1 コマずつの静止画（動画の半分の大きさ。ファイル名は書き出したときに表示される各行の頭の番号。例: `03.png`。句ごとに撮る `jgv snapshots --scene=N --phrases` なら `02-04.png`。`jgv dev` には `--phrases` は無い）を Read する

画像で見ること:
- 手が道具の持ち手に付いているか、道具が宙に浮いたり重なったりしていないか
- 句の内容と画面の動作が合っているか（例:「tear off」の行で帯が破れているか）
- 拡大カードの小手順ラベル・注釈が読めるか。文字・注釈・枠の重なりと画面からのはみ出しは `jgv check` が `! 秒-秒s:` の行で出すので、画像では物どうしの重なり・二重に描かれた物と、binding の絵が見出し・字幕バーに重なっていないか（check では出ない）を見る。`--no-text` / `--no-notes` なら、説明文が出ていないか

問題がなければ書き出し、続けて概要ページを作る:

```bash
cd <dir> && jgv render && jgv overview
```

`out/overview.html` は工程ごとのナレーション・visual のファイル・静止画と SVG の素材を 1 ページに並べたもの（ブラウザで開く）。`out/video.mp4`・`out/subtitles.srt`・`out/overview.html` の場所を伝え、送れる環境なら動画を送る。続けて「7. ライブラリに保存する」に進む。

配色・声などの調整、エラーのときの対処、Swift で書いた実例（リポジトリの demo/）は [reference/tips.md](reference/tips.md)。

## 6. 多言語版を作る

まず 1 言語で完成させてから、[reference/multilang.md](reference/multilang.md) の手順で `script.<言語>.json` を足し、`jgv build-langs` でまとめて書き出す（映像は共通、台本と画面上の文言だけ差し替え）。

## 7. ライブラリに保存する

書き出した後、この動画で作ったもののうち、ほかの題材でも使えそうな道具・動き（`visuals/props.swift`・`shared.swift`、binding に書いた道具の描き方）と、ユーザーが好みとして選んだ設定（配色・声・速さなど。題材ごとの kicker は除く）、ユーザーに指摘されて直した読み方（`readings`）を候補に挙げて、**ライブラリに保存するかをユーザーに聞く**（候補が無いか、すべてライブラリと同じなら聞かない）。保存するときは [reference/library.md](reference/library.md) の「動画が完成したら保存する」の手順で `<library>/parts/` と `<library>/defaults.json` に入れる。次の動画では描く手間と、設定を伝える手間が減る。
