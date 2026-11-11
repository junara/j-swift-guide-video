# 動作環境（詳細）

SKILL.md の「動作環境」の詳細。

**macOS 専用**。動作を確認した環境だけを対象にする。

| 項目 | 要件 |
|---|---|
| OS | 最新の Xcode が動く macOS（`jgv` は macOS 14.5 より古いと止まる）。動作確認は Apple シリコンのみ。動作確認: macOS 27.2。Linux・Windows（WSL2 を含む）は非対応。Intel Mac は動作未確認 |
| 製品 | macOS 上の Claude Code（CLI・デスクトップアプリ・IDE 拡張）。Claude Code on the web（Linux のクラウド環境）、Claude.ai や Claude API のスキル実行環境は非対応 |
| コマンド | `bash`、最新の Xcode か Command Line Tools（`swift`。`xcode-select --install`。古い版は確かめていない。Swift 6.0 より古いと `bin/jgv` が止まる）。Node.js・npm・ffmpeg は使わない |
| TTS | macOS の音声（`apple`、既定）、組み込みのクラウドの TTS（`google` / `azure` / `amazon` / `openai`。キーは環境変数）、自分でつなぐ TTS（`command`）。下の「TTS エンジン」 |
| ネットワーク | 初回の `jgv` のビルドで、Swift Package Manager が swift-argument-parser（Apple の公開パッケージ）を GitHub から取得する。動画のプロジェクトは外部のパッケージを使わないので、それ以降はオフラインで動く |
| ディスク | jgv のビルド約 200 MB（`~/Library/Caches/j-guide-video/`）、動画のビルドのキャッシュに約 150〜200 MB（`~/Library/Caches/j-guide-video/shared-<ハッシュ>/`。全プロジェクトで共有。古いものは `jgv clean --stale` で消せる。skill を更新して置き場が変わった後の古い jgv のビルド（`build-*`）も同じコマンドで消せる）。プロジェクトのフォルダには台本・visual・音声・動画だけが入る |

動作確認に使った版: macOS 27.2（Apple シリコン）、Xcode 27.2、Swift 6.4。対象は最新の Xcode / Swift だけで、古い版は確かめていない。

- `jgv` は skill の `bin/jgv`。初回と skill を更新したときだけ、`swift build -c release` で `~/Library/Caches/j-guide-video/build-*/` にビルドする（数十秒〜数分。skill のフォルダには書かない。ログは同じフォルダの `build.log`）。置き場所は環境変数 `J_GUIDE_VIDEO_CACHE` で変えられる（`jgv clean --stale` は、その中の jgv が作ったと分かるものだけを消す: 名前が 12 桁のハッシュで、`projects/<ハッシュ>` は `project-path`、`shared-<ハッシュ>` は `kit-built`、`build-<ハッシュ>` は `skill-path` か SwiftPM のビルドの印（`CACHEDIR.TAG` / `workspace-state.json`）があるもの）
- Swift のツールチェインは最新のものを使う（Swift 6.0 より古いと `bin/jgv` が止まる）。パッケージの言語モードは Swift 5（`swiftLanguageModes: [.v5]`。厳密な並行性の検査は無し）。kit や visual に手を入れる人向けの注意
- 有料のクラウドの TTS（`google` / `azure` / `amazon` / `openai`）は、プロジェクトごとに一度 `jgv tts --allow-cloud` で使うことを認めるまで呼ばない（合成する行数と字数を出して止まる）。認めたことはキャッシュの `projects/<ハッシュ>/allow-cloud-<engine>` に覚える（プロジェクトのフォルダには書かないので、配られたプロジェクトに印を仕込めない。印にはフォルダと `jgv.json` の識別を書くので、同じパスに別のプロジェクトを置き直すとまた聞く）。`jgv new --tts …` と、ライブラリの `defaults.json` の engine で作った台本は、利用者が選んだものとして自動で認める。`jgv new --base` で基準の台本のクラウドの engine を引き継ぐだけのときと、自分の `defaults.json` に `tts.command` が無いまま基準の台本の `command` を使うことになるとき（`--tts command` を付けても）は、何も作る前に止まる（`command` は基準の台本のコマンドを実行することになるため）。声を書いていない azure / amazon で声の一覧の API を呼ぶときも同意が要る。認めた印は `jgv clean` では消えない
- 環境変数 `JGV_ASSETS` を設定すると、visual が読む `assets/` の代わりにそのフォルダを使う（ふつうは設定しない。既定はプロジェクトの `assets/`）
- `jgv` の引数とオプションは `jgv help <サブコマンド>`（`jgv <サブコマンド> --help`）で出る。知らないオプションはエラーになる。`jgv --version` で skill の版が出る（git のコミット。未コミットの変更があれば末尾に `+`。plugin で入れて git が無いときは `plugin.json` の version。`~/.claude/skills/` にコピーして入れたときは `unknown`）
- 確認: `bin/jgv` は macOS 以外か、Xcode Command Line Tools が無いか、Swift が 6.0 より古いと止まる。足りないものがあれば、インストール方法をユーザーに伝える（`sudo` が要るものは勝手に実行しない）。macOS 以外の環境では、この skill は使えないことを伝えて止める
- 動画のプロジェクトには Swift のパッケージを置かない。`jgv render` / `jgv snapshots` / `jgv preview` が、キャッシュ（`~/Library/Caches/j-guide-video/shared-<skill の kit のパスのハッシュ>/pkg`）のパッケージを `swift build -c release` でビルドしてから描く。パッケージの中身はシンボリックリンクで、kit は skill の `Sources/`、visual はプロジェクトの `visuals/`・`parts/` を指す。パッケージは全プロジェクトで共有し、ビルドのたびにリンクをそのプロジェクトへ向け直すので、kit のビルド（15〜40 秒）は skill を入れた・更新した後の 1 回だけ（`jgv init`・`jgv tts` が、kit が古ければ裏で先にビルドしておく。ログは同じフォルダの `prebuild.log`）。プロジェクトを切り替えた後や visual だけを直したときは 1〜数秒。できた実行ファイルはプロジェクトごとのキャッシュ（`projects/<プロジェクトのパスのハッシュ>/bin`）に写して実行する。`jgv vendor-kit` で kit を固定したプロジェクトだけは、自分のパッケージ（`projects/<ハッシュ>/pkg`）を使う
- `jgv snapshots --scene=N`（N は 0 始まり）は、同じパッケージの中の、工程 N の visual と補助ファイルだけを集めたターゲット（`Scene<N>`）をビルドする。kit のビルドは全工程で共通。並列の工程担当や、別のプロジェクトの jgv が同時にビルドしても、キャッシュのロックで順番に進むので衝突しない
- プロジェクトのフォルダを移したり名前を変えたりすると、プロジェクトごとのキャッシュ（実行ファイルの写し）が別になる（kit は共有なので作り直さない。古いキャッシュは `jgv clean --stale` で消す）
- Xcode の補完を使って visual を書くときは `jgv open`（キャッシュのパッケージを Xcode で開く。visual はリンクなので、Xcode で直すとプロジェクトのファイルが変わる）
- 書き出しは CoreGraphics で描いたフレームを AVAssetWriter で H.264 にする（音声は AAC）。フレームは CPU のコア数に合わせて並列に描く

## TTS エンジン

`script.json` の `tts.engine` で選ぶ。`apple`（既定）・`command`・`google`・`azure`・`amazon`・`openai` の 6 つで、ほかの値や、その engine で使えない設定（`command` での `rate` など）は `jgv tts` がエラーで止める。どれでも、句の区切りは音声の中の無音から求めるので、同じように字幕と動きが合う。

### apple（macOS の音声）

macOS の AVSpeechSynthesizer を使う（`"tts": { "engine": "apple" }`）。Xcode Command Line Tools の `swift` が必要。コンパイルしたバイナリからはプレミアム/ニューラル音声（Sakura など）が見えないので、`jgv tts` は合成の部分だけを `swift` コマンド（インタプリタ）で 1 行ずつ子プロセスとして実行する（起動に約 1 秒かかるので、未生成の行を最大 8 並列で生成する）。書き出した動画は個人的・非商用の利用に限る（SKILL.md の「生成した動画の利用条件」）。

- `"voice": "auto"` で、台本の言語でインストール済みの最高品質の声を自動選択する。プレミアム/ニューラル音声（日本語の Sakura など）はダウンロードしたときだけ使え、無ければ標準の声（日本語は Kyoko など）になる
- 使える音声は `jgv voices` で一覧（品質の高い順。英語は `jgv voices en-US`）。特定の声は `voice` に identifier を書く
- より良い音声は「システム設定 > アクセシビリティ > 読み上げコンテンツ > システムの声 > 声を管理」から拡張/プレミアム音声をダウンロードすると増える
- `rate` は 0.0〜1.0（既定 0.5）、`pitch` は 0.5〜2.0（既定 1.0）

### google（Google Cloud Text-to-Speech）

Google Cloud Text-to-Speech の API を `jgv tts` が直接呼ぶ（`"tts": { "engine": "google", "voice": "ja-JP-Neural2-B" }`）。スクリプトは要らない。API キーを環境変数 `GOOGLE_TTS_API_KEY` に入れておく（キーは URL ではなく `X-Goog-Api-Key` ヘッダーで送る）。API キーの代わりに、サービスアカウントの鍵（JSON）のパスを環境変数 `GOOGLE_APPLICATION_CREDENTIALS` に入れてもよい（両方あれば API キーを使う）。使った分の料金がかかり、利用条件は Google Cloud の規約に従う。

- 準備はユーザーがする: Google Cloud のプロジェクトで課金を設定し、Cloud Text-to-Speech API を有効にして、API キーを作る（使える API を Cloud Text-to-Speech API に制限しておく）。キーはエディタで `~/.zshrc` などに `export GOOGLE_TTS_API_KEY=…` と書く（`echo … >> ~/.zshrc` だとシェルの履歴に残る）。Claude はキーを入力・表示しない
- サービスアカウントで使うとき: 課金と Cloud Text-to-Speech API を設定したプロジェクトでサービスアカウントを作り、鍵（JSON）を作って、そのパスを `~/.zshrc` などに `export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json` と書く（鍵のファイルは人に渡さない・リポジトリに入れない。Claude は鍵のファイルを開かない・表示しない。困ったときは `jgv voices --google` のエラーを見る）。`jgv tts` は鍵で署名した JWT を `https://oauth2.googleapis.com/token` でアクセストークンに換え、`Authorization: Bearer` で送る（gcloud は要らない。トークンは期限の 5 分前まで使い回す）。最初にトークンを取ったとき、どのサービスアカウントで呼ぶかを 1 回だけ WARN で出す（ほかの用途で入れたままの `GOOGLE_APPLICATION_CREDENTIALS` で、気づかずにそのプロジェクトに料金がかからないように）。鍵の `token_uri` は使わない。使えるのは `type` が `service_account` の鍵だけで、`gcloud auth application-default login` で作った認証情報（`authorized_user`）は使えない
- 声の名前は `jgv voices --google`（既定 `ja-JP`。英語は `jgv voices en-US --google`。中国語の台本の `zh-CN` / `zh-TW` / `zh-HK` は、Google の言語コード `cmn-CN` / `cmn-TW` / `yue-HK` に置き換えて送る）。`voice` を書かなければ、Google が台本の言語の既定の声を選ぶ（品質は声の種類による。決まった声にしたいなら書く）。`voice` を書くと、送る言語は声の名前の頭（`ja-JP-Neural2-B` なら `ja-JP`）になる（台本の `lang` が `en-GB` で声が `en-US-…` のような食い違いでも API がエラーにならない）
- ライブラリの defaults.json では、google の声を `"voices": { "google": { "ja-JP": "ja-JP-Neural2-B" } }` のように `voices.google` に言語ごとに書く。`voices` の直下の声（apple / command 用）は google では使わない（command の声と名前の形が似ていて見分けられないため）。`voices.google` がオブジェクトでない、または声が文字列でないときは、jgv md2script が警告して使わない
- jgv md2script は、`GOOGLE_TTS_API_KEY`（か `GOOGLE_APPLICATION_CREDENTIALS`）が無くても台本を作る（警告だけ出す）。キーが要るのは音声を作る `jgv tts` から
- 書ける設定は `voice` と `parallel`（同時に合成する数。既定 2、16 まで）だけ。`rate` / `pitch` は使えない
- キーは作る音声があるときだけ要る（すべてキャッシュにあれば、キーが無くても timeline を作り直せる）。429・5xx と、接続できなかったとき（送る前の失敗）は、少し待って 3 回までやり直す。合成のリクエストを送った後のタイムアウト・切断は、料金が重ならないようやり直さない（`jgv tts` をもう一度実行すれば、できた行はキャッシュを使う）。読み上げる文が空の行があると、API を呼ぶ前に止まる
- 声を変えると、その台本の音声はすべて作り直す（料金がかかる）
- クレジットは自動では出ない（`jgv tts` が警告する）。表記が要るなら `script.json` の `credit` に書く

### azure（Azure AI Speech）

Azure AI Speech の音声合成の REST API を `jgv tts` が直接呼ぶ（`"tts": { "engine": "azure", "voice": "ja-JP-NanamiNeural" }`）。環境変数 `AZURE_SPEECH_KEY`（Speech リソースのキー）と `AZURE_SPEECH_REGION`（地域。`japaneast` など、英小文字と数字だけ）を入れておく。文は SSML に包んで送り（記号はエスケープする）、24kHz 16bit モノラルの wav で受け取る。

- 準備はユーザーがする: Azure portal で Speech のリソースを作り、「キーとエンドポイント」のキーと地域を `~/.zshrc` などに書く。Claude はキーを入力・表示しない
- 声の名前は `jgv voices --azure`（既定 `ja-JP`）。`voice` を書かなければ、音声を作る直前に声の一覧を読み、台本の言語の代表的な声（`ja-JP-NanamiNeural`・`en-US-JennyNeural` など。コードの `AzureTTS.preferred`）、無ければ正式版のニューラル音声から名前の順で最初の声を使う。選んだ声は `.jgv/narration/.default-voices.json` に覚えておき、次からも一覧の API を呼ばずに使う。選んだ声は `voice` に書いたときと同じようにキャッシュキーに入るので、一覧が変わったり覚えたファイルを消したりしても、1 本の動画に別の声が混ざらない（声が変われば全行を作り直す）
- 書ける設定は `voice` と `parallel` だけ。defaults.json では声を `voices.azure` に言語ごとに書く

### amazon（Amazon Polly）

Amazon Polly の API を `jgv tts` が直接呼ぶ（`"tts": { "engine": "amazon", "voice": "Kazuha" }`）。環境変数 `AWS_ACCESS_KEY_ID`・`AWS_SECRET_ACCESS_KEY`（一時的な認証情報なら `AWS_SESSION_TOKEN` も）と `AWS_REGION`（無ければ `AWS_DEFAULT_REGION`。`ap-northeast-1` など）を入れておく。リクエストには AWS の署名（Signature Version 4）を付け、mp3 で受け取る。

- 準備はユーザーがする: IAM で `polly:SynthesizeSpeech` と `polly:DescribeVoices` を許可したユーザーのアクセスキーを作り、`~/.zshrc` などに書く。`~/.aws/credentials` のプロファイルや SSO は読まない（AWS CLI v2 の `eval "$(aws configure export-credentials --format env)"` で環境変数にできる）
- 声の名前は `jgv voices --amazon`（既定 `ja-JP`。`neural` で使える声。ほかの種類は `--polly-engine=generative` などを付ける）。`voice` を書かなければ、台本の言語でその `pollyEngine` が使える代表的な声（`Kazuha`・`Joanna` など。`AmazonTTS.preferred`）、無ければ名前の順で最初の声を使い、azure と同じようにプロジェクトに覚えておく。中国語は Polly の `cmn-CN`（普通話）の声から、`zh-HK` は `yue-CN`（広東語）の声を先に選ぶ
- 書ける設定は `voice`・`pollyEngine`（`neural` 既定 / `standard` / `long-form` / `generative`。使える声と地域は種類ごとに違う）・`parallel`。defaults.json では声を `voices.amazon` に言語ごとに書く
- 流量制限（429、またはヘッダー `x-amzn-ErrorType` が Throttling・本文が Rate exceeded の 400）は、少し待って 3 回までやり直す

### openai（OpenAI の音声合成）

**OpenAI は、この API のモデル（`tts-1` / `tts-1-hd` / `gpt-4o-mini-tts`）を 2027-01-06 に停止する予定**（後継の `gpt-realtime-2.1-mini` は Realtime API 用で、この API では使えない）。`jgv tts` は openai のたびに警告し、モデルが見つからないエラー（404 など）にもこのことを添える。長く使う動画には google / azure / amazon を勧める。

OpenAI の `/v1/audio/speech` を `jgv tts` が直接呼ぶ（`"tts": { "engine": "openai", "voice": "coral" }`）。環境変数 `OPENAI_API_KEY` を入れておく。wav で受け取る。言語は文から自動で判断される（API に言語を渡さない）。

- 準備はユーザーがする: OpenAI Platform で支払い方法を設定し、API キーを作って `~/.zshrc` などに書く。Claude はキーを入力・表示しない
- 声の名前は `jgv voices --openai`（声の一覧を返す API が無いので、決まった一覧。最新は OpenAI のドキュメント）。`voice` を書かなければ、OpenAI が勧める `marin`（`tts-1` / `tts-1-hd` では `alloy`。既定の声もキャッシュキーに入る）
- 書ける設定は `voice`・`model`（`gpt-4o-mini-tts` 既定 / `tts-1` / `tts-1-hd` など）・`instructions`（話し方の指示。`tts-1` / `tts-1-hd` では使えないので止める）・`parallel`。defaults.json では声を `voices.openai` に言語ごとに書く
- OpenAI の利用規約で AI が作った音声であることを伝える必要があるので、クレジットの既定は「ナレーション: AI 音声 (OpenAI)」（`credit` で変えられる）
- 残高・上限が尽きた 429（insufficient_quota）はやり直さない

google・azure・amazon・openai に共通: キーは作る音声があるときだけ要る（md2script はキーが無くても台本を作り、警告だけ出す。azure / amazon で `voice` を書かず、まだ声を覚えていないときだけは、声の一覧を読むために先にキーが要る）。`"voice": "auto"`（apple から engine だけ変えた台本）は書かなかったのと同じに扱う。空の文は API を呼ぶ前に止める。429・5xx と、接続できなかったときは 3 回までやり直す（合成のリクエストを送った後の失敗はやり直さない）。クレジットは自動では出ない（`jgv tts` が警告する。openai は「AI 音声」を出す）。キャッシュのキーには送る言語も入る（amazon は声で言語が決まり、openai は言語を送らないので入れない）。

### command（自分でつなぐ TTS）

`tts.command` に書いたコマンドを 1 行ごとに実行して音声ファイルを作る。クラウドの TTS（ElevenLabs など）やローカルの TTS を、API を呼ぶ小さなスクリプトでつなぐ（Google・Azure・Amazon・OpenAI は組み込みの `google` / `azure` / `amazon` / `openai` を使えばスクリプトは要らない）。商用で使える TTS をつなげば、macOS の使用許諾の制限を受けない（使う TTS の利用規約に従う）。

```json
"tts": { "engine": "command", "command": ["swift", "/Users/me/.config/j-guide-video/tts-openai.swift"], "voice": "alloy", "format": "wav", "parallel": 2 }
```

| 設定 | 内容 |
|---|---|
| `command` | コマンドと引数の配列（必須）。シェルを通さずに実行する。引数の `{text}`（読み上げる文。`speak` があればそれ）・`{out}`（書き出す音声ファイルのパス）・`{lang}`（台本の言語、例 `ja-JP`）・`{voice}`（`tts.voice`）を置き換える。同じ値が環境変数 `TTS_TEXT` / `TTS_OUT` / `TTS_LANG` / `TTS_VOICE` にも入る。作業フォルダはプロジェクト。ユーザーのライブラリの defaults.json に書くときは、スクリプトを絶対パスで書く（`~` は展開されない） |
| `voice` | `{voice}` / `TTS_VOICE` に渡す声の名前（任意。中身は使う TTS に合わせる） |
| `format` | コマンドが書く音声の形式（`{out}` の拡張子。既定 `wav`。`mp3` `aiff` `m4a` `caf` など macOS（AVFoundation）が読めるもの） |
| `parallel` | 同時に実行する数（既定 2。API の同時接続の上限に合わせる） |

- コマンドは `{out}` に 1 行分の音声を書いて、終了コード 0 で終わる。失敗したら 0 以外で終わり、理由を標準エラーに出す（`jgv tts` がそれを表示して止まる）
- パイプやリダイレクトを使うときは `["bash", "-c", "… \"$TTS_TEXT\" … > \"$TTS_OUT\""]` のように環境変数で受け取る（文を直接コマンド文字列に埋め込むと、記号で壊れる）
- 音量・サンプリングレートは後でそろえる（48kHz モノラル、ラウドネスを -16 LUFS に正規化し、ピークを -1.5 dBFS に抑える）ので、コマンドの側では気にしなくてよい
- 生成した音声はキャッシュされ、文と `tts` の設定が変わった行だけ作り直す。スクリプトの中身（声・モデル）を変えたときは、`.jgv/narration/` を消して作り直す
- 使わなくなった音声は、apple のときだけ消す。command とクラウドの TTS では残す（多言語版で、ほかの言語の台本の音声を消して有料の API を呼び直さないように）。容量を空けたいときは `.jgv/narration/` を消す
- クレジットは自動では出ない（どの TTS か分からないため）。使う TTS が表記（「ナレーション: ○○」、AI 音声であることの開示など）を求めるなら、`script.json` の `credit` に書く
- 試すだけなら、macOS の `say` でつなげる（`["say", "-v", "{voice}", "-o", "{out}", "--", "{text}"]` と `"voice": "Kyoko"`, `"format": "aiff"`。これは macOS の音声なので、利用条件は apple と同じ）
- `{text}` を引数で受け取るコマンドは、文が `-` で始まる（「-5 度まで…」など）とオプションと取り違える。上の `say` のように `--` の後に `{text}` を置くか、環境変数 `TTS_TEXT` で受け取る

スクリプトの書き方の例として、OpenAI の音声 API につなぐもの（OpenAI は組み込みの `openai` を使えばスクリプトは要らない。`OPENAI_API_KEY` が必要。料金がかかる。`swift` で直接実行するのでビルドは要らない）:

```swift
// tts-openai.swift: TTS_TEXT を読み上げた音声を TTS_OUT に書く
import Foundation

let env = ProcessInfo.processInfo.environment
var req = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/speech")!)
req.httpMethod = "POST"
req.setValue("Bearer \(env["OPENAI_API_KEY"] ?? "")", forHTTPHeaderField: "Authorization")
req.setValue("application/json", forHTTPHeaderField: "Content-Type")
let voice = (env["TTS_VOICE"] ?? "").isEmpty ? "alloy" : env["TTS_VOICE"]!
req.httpBody = try JSONSerialization.data(withJSONObject: [
  "model": "gpt-4o-mini-tts", "voice": voice, "input": env["TTS_TEXT"] ?? "", "response_format": "wav",
])
let (data, res) = try await URLSession.shared.data(for: req)
guard (res as? HTTPURLResponse)?.statusCode == 200 else {
  FileHandle.standardError.write("OpenAI TTS: \((res as? HTTPURLResponse)?.statusCode ?? 0) \(String(decoding: data, as: UTF8.self))\n".data(using: .utf8)!)
  exit(1)
}
try data.write(to: URL(fileURLWithPath: env["TTS_OUT"]!))
```
