# 開発ルール

Claude Code skill `j-guide-video`（plugin `jgvs`、CLI `jgv`）のリポジトリ。skill の本体は `.claude/skills/j-guide-video/` にある。構成は [README.md の「リポジトリの構成」](README.md#リポジトリの構成)。

## コマンド

```bash
# ビルドと単体テスト（CI と同じ。push の前に通す）
cd .claude/skills/j-guide-video && swift build -c release && swift test

# デモの書き出し（リポジトリのルートで。1 本だけならデモ名を渡す）
bash demo/run.sh 05-budget-app-screen
```

## 1. 前提

- 対象は macOS と最新の Xcode / Swift だけにする。古い版への対応コードは足さない。
- 新しい Xcode（安定版）が出たら、その版で次を確かめてから、動作確認の版（macOS・Xcode・Swift）を書き換える。
  1. ビルドと単体テストを通す。新しい警告が出たら直す。
  2. デモを型ごとに少なくとも 1 本書き出し、動画と音声を確かめる。
  3. README の English summary と「動作環境」の表、`reference/environment.md` の表と「動作確認に使った版」を、実際に確かめた版に書き換える（`sw_vers`・`xcodebuild -version`・`swift --version` の出力のとおりに。確かめていない版は書かない）。
  4. CHANGELOG.md の「未リリース」に書く。直すところがあったなら、そのことも書く。
- 依存は `swift-argument-parser`（CLI のみ）に限る。kit（`JGVCore` / `JGVKit` / `JGVRender`）には外部のパッケージを入れない。
- Node.js・ffmpeg・ブラウザに頼る処理は入れない。

## 2. 変更をそろえる

コードを変えたら、同じコミットで次も直す。

- **CLI のオプションやサブコマンドを変えたとき**: README の「コマンド一覧」、`reference/options.md`、`SKILL.md` の該当箇所。
- **kit の部品を足した・変えたとき**: `reference/visual-kit.md`。`jgv catalog` で `reference/props-catalog.png` も作り直す。
- **キューの文法を変えたとき**: `reference/cue.md` と `examples/`。
- **利用者に見える変更**: [CHANGELOG.md](CHANGELOG.md) の「未リリース」に書く。`version` はここでは上げない（9 節）。
- **プロジェクトの形式を変えたとき**: `jgv.json` の形式の版を上げる。`jgv migrate` で移せるようにするかは、手間に見合うときだけでよい（9 節の互換性）。

## 3. テストと確認

- 解析・検証・ファイルを消す処理（`jgv clean --stale` など）を変えたら、単体テストを足す。
- 描画や kit を変えたら、影響する型のデモを `bash demo/run.sh` で書き出し、スナップショットを目で確かめる。CI はデモと `examples/` の visual をビルドしないので、壊れていないことは手で確かめる（CI には足さない）。確かめていないデモがあれば、報告に書く。
- テストと CI では、有料のクラウドの TTS を呼ばず、音声も作らない。

## 4. コード

- インデントは 2 スペース。コメントと利用者向けのメッセージは日本語にする。
- CLI は [Command Line Interface Guidelines（clig.dev）](https://clig.dev/) に沿う。サブコマンドやオプションを足す・変えるときは、ヘルプに例を載せ、よく使われる名前（`-o, --output`・`-n, --dry-run`・`--json` など）に合わせ、どのフラグにも長い名前を付ける。
- 結果は stdout、進み具合・補足・警告は stderr に出す。知らないオプションはエラーにする。終了コードは、成功が 0、失敗が 1、引数の誤りが 64。進み具合は、端末でないときは `\r` で書き換えず、行ごとに出す。
- visual と kit では秒数を直接書かず、`useNarration()` の行・句を基準にする。
- 新しい道具は `reference/prop-style.md`（輪郭線・配色・原点）に合わせる。

## 5. セキュリティ

[SECURITY.md](SECURITY.md) の決まりを崩さない。

- データ（手順書・台本・キュー・SVG・`.jgv/`）で、プロジェクトとキャッシュの外のファイルを読む・書く・消すことができないようにする。
- API キーは環境変数からだけ読み、HTTP のヘッダーで送る。URL・引数・ログ・キャッシュには書かない。
- 有料の API は `--allow-cloud` で認めるまで呼ばない。新しい engine を足すときも同じにする。
- 鍵、`mise.local.toml`、`.env` はコミットしない。

## 6. コミットしないもの

- 生成物（`out/`・`.jgv/`・`demo/out/`・`.build/`）。
- macOS の音声で作った動画。Apple の使用許諾のため、リポジトリにも Release にも置かない。README に載せるのは音声の無い静止画（`docs/images/`）だけにする。

## 7. 公開リポジトリとして

このリポジトリは公開する。コミットしたものは、後で消しても履歴と clone に残る前提で扱う。

- 鍵・トークン・個人のメールアドレス・手元の絶対パス（`/Users/<名前>/…`）を、コード・文書・デモ・テスト・コミットメッセージに書かない。例に書くパスは `/Users/me/…` か `~/…` にする。
- 鍵をコミットしてしまったら、履歴を消すより先に、その鍵を無効にして作り直す。
- 自分で作ったもの以外（画像・SVG・フォント・音声・他人のコード・商品名やロゴの入った絵）を入れない。入れるなら、MIT で再配布できるライセンスであることを確かめ、出どころとライセンスを書く。
- デモと例の題材は架空のものにする（実在の人の名前・連絡先・実在のサービスの画面を使わない）。
- 依存を足す・上げるときは、ライセンスを確かめて README の「ライセンス」に書く。
- 依存（`swift-argument-parser`、GitHub Actions の action）は手で上げる。Dependabot などの自動更新は使わない（`.github/dependabot.yml` を足さない）。上げるのは、ビルドが通らなくなった・脆弱性が直った・新しい機能が要る、といった理由があるときだけにする。上げたらビルドと単体テストを通し、`Package.resolved` も一緒にコミットする（`build:` か `ci:`）。
- 自分で見つけた脆弱性の詳細は、直した版を出すまで、コミットメッセージ・CHANGELOG・README に書かない。
- README と `reference/` は利用者が読む文書なので、コードと食い違わせない（2 節）。動作確認していないことを「できる」と書かない。
- push した `main` の履歴は書き換えない（force push しない）。
- 外部からの issue・PR・脆弱性の報告は受け付けない（GitHub の Issues・Pull requests・Private vulnerability reporting は無効にする）。issue や PR のテンプレート、CONTRIBUTING.md、貢献や報告を募る文、連絡先は足さない。

## 8. Git

- Claude は、ユーザーに頼まれたときだけコミットする。push も、頼まれたときだけ行う（「コミットして」は push を含まない）。変更が終わったら、コミットせずに、何を変えたかを報告する。
- 開発は 1 人で行うので、`main` に直接コミットして push する。PR は使わない（GitHub の Pull requests は無効にしてある）。ブランチは、大きな変更を分けて試したいときだけ使い、手元で `main` にマージする。
- push の前にビルドと単体テストを通し、push の後に CI が通ったことを確かめる。落ちたらすぐ直す。
- コミットは 1 つの目的に絞る。メッセージは [Conventional Commits](https://www.conventionalcommits.org/ja/v1.0.0/) の形式（`<type>(<scope>): <要約>`）で、要約は英語の命令形・小文字始まり・末尾のピリオド無しにする。
  - type: `feat`（機能の追加）・`fix`（不具合の修正）・`docs`・`test`・`refactor`・`perf`・`build`・`ci`・`chore`
  - scope は付けるなら変えた場所（`cli`・`kit`・`tts`・`cue`・`demo`・`skill` など）
  - 互換性の無い変更は type の後に `!` を付け、本文に `BREAKING CHANGE:` を書く
  - 例: `feat(tts): add azure engine`、`fix(cue): reject unknown prop names`、`docs: add development rules`
- `feat`・`fix` と互換性の無い変更は利用者に見えるので、同じコミットで CHANGELOG.md の「未リリース」にも書く（2 節）。

## 9. リリース

版は `.claude-plugin/plugin.json` の `version` だけに書く（plugin で入れた `jgv --version` もここを読む。clone したリポジトリの中ではコミットのハッシュを出す）。`version` を上げるまで、plugin の利用者に変更は届かない。

- 版は `MAJOR.MINOR.PATCH`。不具合の修正だけなら PATCH、機能の追加なら MINOR を上げる。互換性の無い変更は、0.x の間は MINOR、1.0.0 以降は MAJOR を上げる。
- **互換性**: 0.x の間は、kit の関数・キューの文法・CLI のオプション・`script.json` とプロジェクトの形式を、予告なく変えてよい。古い書き方を残す互換のコード・非推奨の警告・移行の手段は、要らなければ足さない。そのかわり、互換性の無い変更は必ず、コミットに `!` を付け、CHANGELOG.md に「互換性の無い変更」として、何が動かなくなるかと直し方を書く。
- ふだんのコミットでは `version` を上げない。変更は CHANGELOG.md の「未リリース」にためる。
- リリースは、ユーザーに頼まれたときだけ、次の順で行う。
  1. ビルドと単体テストを通す。
  2. CHANGELOG.md の「未リリース」の中身を `## X.Y.Z（YYYY-MM-DD）` の節に移す（「未リリース」の見出しは空で残す）。
  3. `plugin.json` の `version` と、README の「新しい版を出すとき」の「今は X.Y.Z」を上げる。
  4. `chore(release): vX.Y.Z` でコミットし、タグ `vX.Y.Z` を打って、`main` とタグを push する。
- 出したタグは動かさない・消さない。間違えたら、次の版を出して直す。

## 10. 予定している変更

- **OpenAI の TTS（`"engine": "openai"`）を削る**: OpenAI は、この engine が使うモデル（`tts-1`・`tts-1-hd`・`gpt-4o-mini-tts`）を 2027 年 1 月 6 日に停止する予定。停止するまでは今のまま（`jgv tts` の警告と README の注意書き）にし、先に削らない。停止後は、OpenAI の廃止予定の一覧で実際に止まったことを確かめてから、次のように削る。
  - コード: `Sources/JGVTools/OpenAITTS.swift` を消し、`CloudTTS.swift`・`TTS.swift`・`MD2Script.swift`・`Sources/jgv/main.swift` から openai の分岐とオプション（`--tts openai`・`jgv voices --openai`）を消す。関係する単体テストも直す。
  - 残すもの: `script.json` や `defaults.json` に `"engine": "openai"` が残っているプロジェクトでは、「openai の engine は無くなった。google・azure・amazon・command に替える」と伝えて止まるようにする（知らない engine のエラーと区別する）。
  - 文書: README（English summary・重要の注記・動作環境・TTS エンジン・コマンド一覧）、`SKILL.md`（`description` も）、`SECURITY.md`、`reference/` の `environment.md`・`options.md`・`library.md`・`multilang.md`・`tips.md` から openai を消す。CHANGELOG.md の過去の版の記述は、履歴なので残す。
  - 互換性の無い変更なので、`feat(tts)!: remove openai engine` でコミットし、CHANGELOG.md の「互換性の無い変更」に、替える先の engine を書く。
  - 削り終えたら、この項目を消す。
