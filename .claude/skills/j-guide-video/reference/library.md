# ユーザーのライブラリ

作った道具・動きと、好みの設定（kicker・配色・声・速さ）を skill の外に残し、次の動画で使い回す。skill を更新・入れ直しても消えない。

## 置き場所と中身

`<library>` は環境変数 `J_GUIDE_VIDEO_LIBRARY`（空文字にすると使わない）、未設定なら `~/.config/j-guide-video`（`XDG_CONFIG_HOME` があればその下）。

```
<library>/
  parts/*.swift    … 自作の道具・動き。jgv init が新しいプロジェクトの parts/ にコピーする
  defaults.json    … 台本の既定値。jgv md2script が使う（--no-library で使わない）
```

### parts/

- 1 ファイル = 1 分野（例: `kitchen.swift`、`cleaning.swift`、`phone-screens.swift`）。visual と同じモジュールに入るので、visual からは import せずに `Steamer(x: …, y: …)` のように呼ぶ
- 先頭は `import JGVKit` だけにする。ほかの部品のファイルの名前もそのまま使える（同じモジュールなので）
- 動画ごとの座標に依存させない。位置・大きさ・角度・状態は props で受け取る（`x` `y` `scale` `angle` と、`open` `fill` などの状態）
- 持つ位置などのパーツ座標は `public let POT_PARTS = Parts(["grip": Pt(…)])` のような定数にする（kit の `XXX_PARTS` と同じ形。`place()` で画面座標にできる）
- 部品の関数・定数は `public` にし、ファイルの中だけで使う補助は `private` にする（ほかのファイルや visual の名前とぶつからないように）
- 部品ごとに `///` の 1 行のコメントを付ける。`jgv brief` がコメントとシグネチャを工程担当に渡す
- 道具の見本 `<ファイル名を大文字にした名前>_PREVIEW`（例: kitchen.swift なら `KITCHEN_PREVIEW`。[prop-style.md](prop-style.md) の「道具の見本」）があれば、一緒に保存する。次の動画で `jgv preview <ファイル名>` を実行すれば、ライブラリの道具の見た目を確かめられる
- kit の関数・定数と同じ名前にしない（同じモジュールではないので名前は隠れるだけでエラーにならず、気づかないうちに kit の部品が使えなくなる）
- 絵の描き方は [prop-style.md](prop-style.md) に合わせる

### defaults.json

```json
{
  "kicker": "JUNARA'S KITCHEN",
  "layout": "guide",
  "presenter": "female",
  "palette": { "primary": "#2f5d8a", "accent": "#e0a040", "hair": "#2b2620" },
  "tts": { "pitch": 1.0 },
  "voices": { "ja": "com.apple.ttsbundle.gryphon-neural_Sakura_ja-JP_premium", "en-US": "com.apple.voice.compact.en-US.Samantha" },
  "rates": { "ja": 0.5, "en": 0.46 },
  "readings": { "ja": { "排泄物": "ハイセツブツ", "滑り": "スベリ" } },
  "captions": true,
  "notes": true
}
```

| キー | 台本の項目 | 内容 |
|---|---|---|
| `kicker` | `guide.kicker` | 左上のシリーズ名（どの題材にも使う名前。題材ごとの名前は入れない） |
| `layout` | `layout` | いつも使う型（題材に合わなければ SKILL.md の 0 で別の型を選ぶ） |
| `presenter` | `guide.presenter` | 人物の見た目。`male`（男性）/ `female`（女性）/ `neutral`（中性。既定） |
| `palette` | `guide.palette` | 配色と人物の見た目（肌・髪・服）。キーは skill の `Sources/JGVKit/guide/Theme.swift` の `GuidePalette` |
| `tts` | `tts` | `engine`（`apple` / `command` / `google` / `azure` / `amazon` / `openai`）と、言語によらない設定。apple なら `pitch`（ここに書いた `rate` は全言語に効く）、command なら `command` / `format` / `parallel`、google と azure なら `parallel`、amazon なら `parallel` / `pollyEngine`、openai なら `parallel` / `model` / `instructions`（[environment.md](environment.md) の「TTS エンジン」）。その engine で使えない設定は使わない。声は `voices` に書く（`tts.voice` は無視される） |
| `voices` | `tts.voice` | 言語ごとの声。apple は identifier（`jgv voices`。`com.apple.` で始まる）、command は使う TTS の声の名前。クラウドの TTS の声は `voices.google` / `voices.azure` / `voices.amazon` / `voices.openai` に言語ごとに書く（`{ "azure": { "ja-JP": "ja-JP-NanamiNeural" } }`。名前は `jgv voices --google` / `--azure` / `--amazon` / `--openai`）。台本の言語（`ja-JP`）、無ければ言語の頭（`ja`）で探す。engine に合わない声（command のときの `com.apple.…` など）は使わない。`voices` の直下の声は apple / command 用で、クラウドの TTS では使わない |
| `rates` | `tts.rate` | 言語ごとの読む速さ（0.0〜1.0。apple のときだけ）。探し方は `voices` と同じ |
| `readings` | 各行の `speak` | 言語ごとの読み方の辞書 `{ "語": "読み" }`。jgv md2script が本文の語を読みに置き換えて `speak` にする（長い語が優先）。日本語の読みはカタカナで書く（ひらがなは前後とつながって区切りを誤る）。探し方は `voices` と同じ |
| `captions` / `notes` | `style.captions` / `style.notes` | `false` で字幕バー / 説明文を出さない |

優先順は「組み込みの既定 < defaults.json < コマンドのオプション（`--kicker` `--presenter` `--layout` `--tts` `--no-*`）」。書いていないキーは組み込みの既定のまま。多言語版（`--base`）では、型・大きさ・kicker・人物の見た目・配色・字幕と説明文の表示を基準の台本から引き継ぎ（上書きできるのは `--kicker` `--presenter` と `--no-*`）、読み上げの engine は `--tts` も defaults.json の `tts.engine` も無いときだけ基準の台本から引き継ぎ（engine が同じなら、その engine の設定も基準の台本から引き継ぐ）、声と速さと読み方だけ defaults.json の `voices` / `rates` / `readings` からその言語のものを使う。

## 動画が完成したら保存する

`jgv render` で書き出した後、ユーザーに「この動画で作ったものをライブラリに保存しますか？」と、候補を挙げて聞く（候補が無ければ聞かない。部品も設定もすでにライブラリにあるものと同じなら候補にしない）。保存するものはユーザーが選ぶ。

### 部品の候補

- `visuals/props.swift`・`shared.swift` のうち、ほかの題材でも使えそうな道具・画面の部品・動き（せいろ、スマホの画面の枠、拭く動きなど。kit にすでにあるものは候補にしない）
- 候補にしないもの: この動画の配置だけの関数（`mugPos()` など）、工程の状態をまとめただけの関数

### 部品の保存

1. 上の「parts/」の決まりに合うよう書き直して、`<library>/parts/<分野>.swift` に入れる
   - 同じ分野のファイルがあっても、追記より**新しいファイルに分ける**のを勧める（例: `pets.swift` があるなら爪切りの道具は `pet-nails.swift`）。既存の部品はそのまま名前で呼べる（同じモジュールになる）。既存の部品と名前がぶつからず、移した名前の抜けも確かめやすい
   - **部品が使っている同じファイルの中の名前（色・寸法の定数、パーツ座標、補助関数、型）も一緒に移す**。`props.swift` から部品の関数だけを写すと、`private let FUR: Paint = "#…"` のような定数が抜けやすい。移した後、ファイルの中で使っている名前がすべて、そのファイルか kit かライブラリのほかのファイルで定義されているかを確かめる（次の 2 のビルドで分かる）
   - 同じ名前の部品がライブラリのほかのファイルにあれば、どちらを残すかユーザーに聞く（同じモジュールに入るので、両方あるとビルドが止まる）
2. **ライブラリへ移した部品は、プロジェクトの `visuals/props.swift`（など移したもとのファイル）から消す**（同じ名前が両方にあると再宣言でビルドが止まる）
3. ビルドの確認: プロジェクトの `parts/` に `<library>/parts/` の `*.swift` をコピーし、`jgv snapshots` が通ることを確かめる（ビルドが通らなければ `<library>/parts/` の方を直す。移したのではない別の物が、プロジェクトの visual で同じ名前になっているときだけ、ライブラリの方の名前を変える）
4. 保存したファイルと部品の名前をユーザーに伝える

### 設定の保存

この動画でユーザーが好みとして選んだ設定（配色・声・速さ・字幕と説明文の表示）が、組み込みの既定や今の defaults.json と違えば、defaults.json に入れるか聞く。

- kicker と型は、ユーザーが「いつもこれ」と言ったときだけ候補にする（`DAILY RITUAL / TEA GUIDE` のような題材ごとの kicker は入れない）
- 声は `voices`、速さは `rates` に、台本の言語（`ja-JP` か `ja`）をキーにして入れる
- ユーザーに読み方を指摘されて `speak` を直した語は、`readings` に入れるかを聞く（例: `"readings": { "ja": { "排泄物": "ハイセツブツ" } }`）。次の動画から jgv md2script が自動で当てる
- 既存の defaults.json に足す。ほかのキーは消さず、`palette` `tts` `voices` `rates` `readings` はキーごとに足す（オブジェクトごと置き換えない）。すでにある値を変えるときは、前の値と新しい値を示して聞く

## 使うとき

- `jgv init` が `parts/` にコピーした部品は、`jgv api`（`parts/` の宣言も出る）と `jgv brief`（工程担当の資料）に載る。binding や共通の土台（[implementation.md](implementation.md) の「流れ」の 3）を書く前に `parts/` を見て、あるものは描き直さない
- `parts/` のファイルのビルドエラーで止まったとき（skill を更新して kit の API が変わったときなど）は、プロジェクトの `parts/` は直さない。`<library>/parts/` の方を直してからプロジェクトにコピーし直すか、この動画で使わないファイルならプロジェクトの `parts/` から削除する
- ライブラリを git で管理しておくと、変更を戻せて、ほかの Mac にも持っていける
