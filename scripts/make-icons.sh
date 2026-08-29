#!/usr/bin/env bash
# 런처 아이콘을 SVG 에서 만들어 android/ 리소스에 넣습니다. (macOS 전용 — qlmanage + sips)
# 결과 PNG 는 커밋되므로 CI 에서는 실행하지 않습니다.
set -euo pipefail
cd "$(dirname "$0")/.."
RES="android/app/src/main/res"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

render() { qlmanage -t -s 1024 -o "$TMP" "$1" >/dev/null 2>&1; echo "$TMP/$(basename "$1").png"; }
SQUARE="$(render assets/icon.svg)"
FRONT="$(render scripts/icon-foreground.svg)"

emit() { # <source> <name> <mdpi크기>
  local src=$1 name=$2 base=$3 i=0
  for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    local mul=(1 1.5 2 3 4); local px
    px=$(python3 -c "print(round($base*${mul[$i]}))")
    mkdir -p "$RES/mipmap-$d"
    sips -z "$px" "$px" "$src" --out "$RES/mipmap-$d/$name.png" >/dev/null
    i=$((i+1))
  done
  echo "  $name  (mdpi ${base}px 기준 5종)"
}

emit "$SQUARE" ic_launcher       48
emit "$SQUARE" ic_launcher_round 48
emit "$FRONT"  ic_launcher_foreground 108

cat > "$RES/values/ic_launcher_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0A5236</color>
</resources>
XML
echo "  ic_launcher_background = #0A5236"
