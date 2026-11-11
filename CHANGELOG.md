# 変更履歴

利用者に見える変更を、新しい版を上にして書きます。版は [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) の `version` で、リリースごとに `v0.1.0` のようなタグを打ちます。「未リリース」は、まだ版を上げていない変更です（plugin で入れた利用者には、次の版で届きます）。

## 未リリース

### 互換性の無い変更

- `jgv render` / `jgv still` / `jgv catalog` の出力先のオプション `--out` を `-o` / `--output` にしました（[clig.dev](https://clig.dev/) の慣習と `jgv md2script -o` に合わせる）。`--out=…` と書いていたところは `-o …` か `--output=…` に直してください
- `jgv vendor-kit` で kit を写したプロジェクトでは、言語版の台本の timeline で `jgv render` したときの案内が、古い `--out=…` のままです。kit も新しくするなら、`kit/` を消してから `jgv vendor-kit` をやり直してください

### 変更

- `jgv` をサブコマンド無しで実行すると、全部のヘルプではなく短い使い方と例を出し、終了コード 64 で終わるようにしました（全部は `jgv --help`）
- `jgv --help` のサブコマンドを「作る・確かめる・書き出す・管理」に分け、例と文書の URL を載せました。主なサブコマンドのヘルプにも例を足しました
- 打ち間違えたサブコマンド（`jgv rendr` など）に、近い名前を出すようにしました
- `jgv md2script` と `jgv new` の `-o` に長い名前 `--output` を、`jgv clean --dry-run` に短い名前 `-n` を足しました
- `jgv render` の進み具合は、端末でない（ログやパイプに流す）ときは `\r` で書き換えず、10 秒ごとに 1 行ずつ出すようにしました

## 0.1.0

最初の版。

- 手順書（Markdown）から、ナレーションと字幕に同期したイラストの手順動画（MP4）と字幕（SRT）を書き出す skill `j-guide-video` と CLI `jgv`
- 型: 部屋・画面操作・手元俯瞰・組み立て説明書・縦型
- 工程の動きを句ごとに 1 行で書くキュー（`cues/*.cue`）と、Swift の visual
- TTS: macOS の音声（既定）、Google Cloud Text-to-Speech・Azure AI Speech・Amazon Polly・OpenAI、コマンドでつなぐ TTS
- 多言語版の一括書き出し（`jgv build-langs`）
- ユーザーのライブラリ（自作の部品と既定値）
