#!/usr/bin/env bash
# デモ原稿から動画を生成する
# usage: bash demo/run.sh [デモ名 ...]   (省略時は全デモ)
#   各デモは demo/<デモ名>/ がそのまま動画のプロジェクト (jgv.json・script.json・visuals/*.swift)
#   例: bash demo/run.sh 01-green-tea-guide
set -euo pipefail
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
JGV="$DEMO_DIR/../.claude/skills/j-guide-video/bin/jgv"
OUT="$DEMO_DIR/out"
mkdir -p "$OUT"

if [ $# -eq 0 ]; then
  # 名前に空白があっても 1 つのデモとして扱う
  names=()
  for d in "$DEMO_DIR"/*/; do [ -f "$d/jgv.json" ] && names+=("$(basename "$d")"); done
  [ ${#names[@]} -gt 0 ] || { echo "ERROR: $DEMO_DIR にデモがありません" >&2; exit 1; }
  set -- "${names[@]}"
fi

for name in "$@"; do
  name="${name%/}"
  dir="$DEMO_DIR/$name"
  [ -f "$dir/jgv.json" ] || { echo "ERROR: $dir/jgv.json がありません" >&2; exit 1; }
  echo "=== $name ==="
  (cd "$dir" && "$JGV" tts script.json && "$JGV" render -o "$OUT/$name.mp4")
  cp "$dir/out/subtitles.srt" "$OUT/$name.srt"
  # SNAPSHOTS=1 で各行の静止画一覧 demo/out/<デモ名>-sheet.png も作る (timeline が多言語版で上書きされる前に撮る)
  if [ "${SNAPSHOTS:-0}" = "1" ]; then
    (cd "$dir" && "$JGV" snapshots >/dev/null)
    cp "$dir/out/snapshots/sheet.png" "$OUT/$name-sheet.png"
  fi
  # 多言語版 (script.<言語>.json) があれば、同じ visual で書き出す
  langs=0
  for extra in "$dir"/script.*.json; do
    [ -f "$extra" ] || continue
    lang="$(basename "$extra" .json)"; lang="${lang#script.}"
    echo "--- $name ($lang) ---"
    (cd "$dir" && "$JGV" tts "$(basename "$extra")" --keep-audio && "$JGV" render -o "$OUT/$name.$lang.mp4")
    cp "$dir/out/subtitles.srt" "$OUT/$name.$lang.srt"
    echo "-> demo/out/$name.$lang.mp4"
    langs=$((langs + 1))
  done
  # 言語版を書き出したら、timeline と字幕を基準の台本のものに戻す (この後の jgv check・snapshots・dev が基準の台本で動くように)
  if [ "$langs" -gt 0 ]; then (cd "$dir" && "$JGV" tts script.json --keep-audio >/dev/null); fi
  echo "-> demo/out/$name.mp4, demo/out/$name.srt"
done
