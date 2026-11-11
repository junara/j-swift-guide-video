# セキュリティ

## 対応する版

最新の版（[`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) の `version`）だけを直します。

## 報告について

個人で開発しているリポジトリなので、脆弱性の報告は受け付けていません（Issues・PR・Security advisories のどれも）。MIT License のとおり無保証です。下の考え方を読んだうえで、自分の責任で使ってください。問題を見つけて直したいときは、fork して直せます。

## 考え方（他人のプロジェクトを開くとき）

j-guide-video の動画のプロジェクトは、データだけでなく**コード**を含みます。

| 中身 | 扱い |
|---|---|
| `visuals/*.swift`・`parts/*.swift`・`kit/` | ビルドして実行する Swift のコード |
| `script.json`・`script.<言語>.json` の `tts.command` | そのまま実行するコマンド（`jgv new --base` で、自分の `defaults.json` に `tts.command` が無いまま他人の台本の command を使うことになるときは、何も作る前に止まる。`jgv md2script --base` は引き継ぐコマンドを WARN で見せる） |
| `script.json`・`script.<言語>.json` の `tts.engine`（`google` / `azure` / `amazon` / `openai`） | 有料の API。プロジェクトと engine ごとに `jgv tts --allow-cloud` で認めるまで呼ばない（合成も、`jgv tts` が自動で読む声の一覧も。`jgv voices --<engine>` で自分から頼んだときはすぐ呼ぶ） |
| 手順書・台本・キュー・`assets/*.svg`・`.jgv/` | データ。プロジェクトの外のファイルを消す・読む・書くことはできない（できたら脆弱性） |

そのため、**他人から受け取ったプロジェクトで `jgv tts` / `timing` / `dev` / `check` / `snapshots` / `still` / `preview` / `catalog` / `render` / `build-langs`（音声を作る・visual をビルドして描くコマンドすべて） を実行するのは、そのコードを実行するのと同じ**です。信頼できるものだけを使ってください。Claude には、実行する前に `tts` と Swift のファイルの有無をユーザーに示して確かめるよう、SKILL.md で指示しています。

`out/` は別のディスクへのシンボリックリンクにできます。visual をビルド・実行しない `jgv tts`（`tts.command` のコマンドは実行します）は、`out/` がリンクなら字幕を書きません（WARN を出す）。`jgv render` / `build-langs`（visual をビルドして実行するコマンド）は、リンクの先に動画と字幕を書きます。`jgv snapshots` と、それを呼ぶ `jgv dev` は、前回の静止画を消すので、`out/`・`out/snapshots/` がリンクだと止まります。

データ（コード以外）によって、プロジェクトとキャッシュ（`~/Library/Caches/j-guide-video/`）の外のファイルが消える・読まれる・書かれる、API キーが漏れる、認めていない有料の API が呼ばれる、といったことは、起きないように作っています（起きるなら脆弱性です）。

## API キー

クラウドの TTS のキーは環境変数（と、`GOOGLE_APPLICATION_CREDENTIALS` が指すサービスアカウントの鍵のファイル）だけから読み、HTTP のヘッダーで送ります（URL・コマンドの引数・ログ・キャッシュには書きません。HTTP のディスクキャッシュも使いません）。リダイレクトには従いません。送り先を変える環境変数（`JGV_*_BASE`）は localhost だけを受け付けます。
