# 多言語版を作る

映像 (visuals) はそのままで、言語ごとの台本 `script.<言語>.json` を足す。

1. 基準の台本 `script.json` に、画面上の文言を `"strings": { "キー": "文言" }` で入れる。キューでは `say 点 $キー:既定の文` のように書いた文字（[cue.md](cue.md)）、Swift の visual と binding（`visuals/bind.swift` の draw の中。画面操作型のボタンの文字や道具のラベル）では `let n = useNarration()` → `n.t("キー", "既定の文")` のキー
2. 各言語の手順書 `procedure.<言語>.md` を用意する（無ければ基準の手順書を翻訳。工程数と各工程の文の数をできるだけ揃える）
3. 基準の visual 名・配置を引き継いで変換し、`strings` を翻訳する

```bash
cd <dir> && jgv md2script procedure.zh.md -o script.zh.json --lang zh-CN --base script.json --kicker "DAILY RITUAL / 咖啡指南"
```

型・大きさ・配色・字幕と説明文の表示は `script.json` から引き継ぐ。読み上げの engine も、`--tts` も defaults.json の `tts.engine` も無ければ `script.json` から引き継ぐ。engine が `script.json` と同じなら（`--tts` などで同じ engine を選んだときも）、その engine の設定 `command` / `format` / `parallel` / `pitch` / `pollyEngine` / `model` / `instructions` も引き継ぐ（defaults.json に書いた設定が優先。声と速さは引き継がない）。声と速さは、ユーザーのライブラリの defaults.json に `voices` / `rates` があればその言語のもの、無ければ（速さは defaults.json の `tts.rate`、それも無ければ）その言語の既定（[library.md](library.md)）。

4. まとめて書き出す（`script.json` → `out/video.mp4`、`script.zh.json` → `out/video.zh.mp4` …）

```bash
cd <dir> && jgv build-langs
```

- 声は言語ごとに、インストール済みの最高品質の macOS の声が自動で選ばれる（例: 英語 Samantha、中国語 Tingting）。command でつないだ TTS は、言語ごとの声を defaults.json の `voices` に書くか、スクリプトが `{lang}` / `TTS_LANG` を見て選ぶ。google / azure / amazon / openai は、言語ごとの声を defaults.json の `voices.google` / `voices.azure` / `voices.amazon` / `voices.openai` に書く（書かなければ、その言語の声が選ばれる）。フォントも言語に合わせて切り替わる
- 文の数が基準と違う言語では、`n.at(2)` など存在しない行のタイミングはシーン末尾になる。重要な動きは行番号の小さい行に結びつける
- キューの時刻 `行.句` は言語ごとの読み上げに合わせて動く。句の数が基準と違う言語では、無い句の時刻は行の途中の推定になる。無い句を推定で埋めるのは言語版の台本だけで、基準の台本 `script.json` では無い句は誤り（`!`）になる。言語版の音声を作った後（`jgv tts script.<言語>.json`）に `jgv check` を実行すると（`jgv check script.<言語>.json` なら tts もまとめて行う）、無い行が `!`、無い句が `?` で出る。言語版の時刻の表は `jgv timing script.<言語>.json`（このとき timeline もその言語版になるので、基準の台本に戻るときは `jgv tts`。`check` / `dev` に言語版の台本を渡したときも同じ。timeline が言語版のまま `jgv render` すると、基準の動画 `out/video.mp4` を言語版で上書きしないよう止まる）。言語版の見た目は `jgv dev script.<言語>.json` で確かめられる
- timeline（`.jgv/timeline.json`）は 1 つで、最後に `jgv tts` / `jgv dev` を実行した台本のものになる。`jgv build-langs` は終わったら（エラーで止まっても。Ctrl-C で中断したときは、次の `jgv build-langs`・`render`・`check`・`snapshots` などの始めに）timeline と `out/subtitles.srt` を基準の台本のものに戻す（その前に `jgv tts` を実行したなら、それが作った timeline を使う）（基準の台本も書き出したならそのときのもの、書き出さなかったなら実行前のもの。実行前に無かったなら消す）。`jgv dev script.<言語>.json` などで言語版にした後、基準の台本に戻って `jgv check` / `jgv snapshots` を使うときは、先に `jgv tts`（または `jgv dev`）を実行し直す
- `jgv build-langs` は台本ごとに `jgv tts --keep-audio` → `jgv check` → `jgv render` を行い、`!` があればその言語で止まる（確かめずに書き出すなら `--no-check`）。`jgv build-langs en zh` のように言語を絞れる（基準の台本は `default`）
- **言語版で `!` が出たら**、キューをどの言語でも通るように直す（読み上げの長さが言語ごとに違うため）。片付け・手を戻す動きは `行.句` ではなく `end-秒` で書く、手の移動と移動の間に 0.2〜0.3 秒の余裕を持たせる、右手が自動で戻り始める `end-1.05` 秒までに持っている点の動きを終える
- `jgv tts script.<言語>.json` は、`strings` が `script.json` と同じ文のまま（未翻訳）のキーと、キュー（`$キー`）・visual（`n.t("キー")`）で使うのに `strings` に無いキーを WARN で出す。画面に元の言語の文が残らないよう、出なくなるまで訳す。漢字・かなを使わない言語の台本では、キューに `$キー` を使わずに直接書いた漢字・かなの文字（`say` / `card` / `notes` など）も WARN で出す（訳されずにそのまま出るので、`$キー:既定の文` にして `strings` で訳す）
- `jgv snapshots --video=out/video.<言語>.mp4` のコマの見出しは、今の timeline（最後に `jgv tts` した台本）のもの。言語版の動画を見るときは先に `jgv tts script.<言語>.json`
- 基準の台本が `style.captions` / `style.notes` を `false`（`--no-text` など）にしていれば、各言語版にも引き継がれる
- 拡大カードの見出し（拡大 / A closer look / 放大看 …）と部品リストの見出し（部品 / Parts / 零件 …）は自動で翻訳される（対応は ja / en / zh / ko / vi / uk。ほかの言語は英語になるので、`strings` に書いて訳す）
- 言語版で句の数が違い、キューの `L.P` の句が無いときは、`jgv check` は `?`（注意）を出して時刻を推定で埋める（止めない）。推定した時刻が起こす重なりや遅れも `?` になる。見た目は `jgv dev script.<lang>.json` で確かめる
