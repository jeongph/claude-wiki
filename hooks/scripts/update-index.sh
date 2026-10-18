#!/usr/bin/env bash
set -euo pipefail
# glob 확장 정렬은 LC_COLLATE에 종속된다. 고정하지 않으면 같은 노드 집합이라도
# 머신과 셸 로케일에 따라 _INDEX.md의 행 순서가 달라져, 노드를 건드리지 않은
# 커밋에까지 순서 diff가 딸려 들어간다. C 로케일은 어디에나 존재하고, UTF-8은
# 바이트 순서가 코드포인트 순서와 같아서 한글도 가나다순으로 정렬된다.
export LC_ALL=C
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-resolve-dir.sh"
DIR=$(resolve_wiki_dir "${1:-}")
[ -z "$DIR" ] && exit 0
[ -d "$DIR" ] || exit 0
OUT="$DIR/_INDEX.md"

# frontmatter(첫 --- 블록) 안에서만 필드를 읽는다. 본문에 같은 이름으로
# 시작하는 줄이 있어도 섞이지 않는다.
field() {
  awk -v key="$1" '
    /^---/ { n++; if (n == 2) exit; next }
    n == 1 && index($0, key ":") == 1 {
      sub(/^[^:]*:[[:space:]]*/, "")
      print
      exit
    }
  ' "$2"
}

# tags는 YAML 리스트다. 블록 스타일("tags:" 다음 줄부터 "  - 값")과 플로우
# 스타일("tags: [값, 값]") 둘 다 지원한다. OKF 컨벤션 문서의 필드 템플릿이
# 플로우 스타일을 예시로 쓰고 있어 이 표기도 실제로 파싱돼야 한다.
# frontmatter 범위 안에서만 읽는다. 범위를 제한하지 않으면 본문의 불릿
# 목록이 그대로 딸려 들어온다.
tags_of() {
  awk '
    /^---/ { n++; if (n == 2) exit; next }
    n == 1 && /^tags:/ {
      line = $0
      sub(/^tags:[[:space:]]*/, "", line)
      if (line ~ /^\[.*\]/) {
        # 플로우 스타일: 대괄호 안을 쉼표로 분리하고 항목별 공백을 정리한다.
        content = line
        sub(/^\[/, "", content)
        sub(/\][[:space:]]*$/, "", content)
        gsub(/[[:space:]]*,[[:space:]]*/, ", ", content)
        gsub(/^[[:space:]]+/, "", content)
        gsub(/[[:space:]]+$/, "", content)
        out = content
        exit
      }
      in_tags = 1
      next
    }
    n == 1 && in_tags && /^[[:space:]]+-[[:space:]]*/ {
      sub(/^[[:space:]]+-[[:space:]]*/, "")
      out = out (out ? ", " : "") $0
      next
    }
    n == 1 && in_tags && /^[^[:space:]]/ { in_tags = 0 }
    END { print out }
  ' "$1"
}

# 이전 버전이 만든 인덱스를 새 이름으로 옮긴다. 남겨 두면 일반 노드로 잡혀
# 목록에 인덱스 자신이 들어가고, 갱신이 멈춰 실제와 어긋난다.
# type: Index인 파일만 옮겨 사용자가 직접 만든 노드는 건드리지 않는다.
for legacy in index INDEX; do
  old="$DIR/$legacy.md"
  [ -f "$old" ] || continue
  [ "$old" = "$OUT" ] && continue
  if [ "$(field type "$old")" = "Index" ]; then
    mv "$old" "$OUT"
    echo "이전 인덱스를 옮겼습니다: $old -> $OUT"
  fi
done

case "$DIR" in
  */docs/history|docs/history) MODE=history ;;
  *)                           MODE=knowledge ;;
esac

if [ "$MODE" = history ]; then
  # 작업 이력은 최신이 위에 와야 쓸모가 있다. 파일명이 yyyy-MM-dd로 시작하므로
  # 오름차순 glob 결과를 뒤에서부터 훑으면 날짜 역순이 된다.
  {
    echo "---"; echo "type: Index"; echo "title: 작업 이력"; echo "---"; echo
    echo "# 작업 이력"; echo
    echo "| 날짜 | 제목 | tags |"; echo "|---|---|---|"
    files=("$DIR"/*.md)
    for ((i = ${#files[@]} - 1; i >= 0; i--)); do
      f="${files[$i]}"
      [ -f "$f" ] || continue
      name=$(basename "$f" .md)
      [ "$name" = "_INDEX" ] && continue
      date=$(printf '%s' "$name" | cut -c1-10)
      title=$(field title "$f")
      tags=$(tags_of "$f")
      echo "| $date | [${title:-$name}](./$name.md) | ${tags:--} |"
    done
  } > "$OUT"
else
  {
    echo "---"; echo "type: Index"; echo "title: OKF 노드 지도"; echo "---"; echo
    echo "# OKF 노드 지도"; echo
    echo "| 노드 | type | 요약 |"; echo "|---|---|---|"
    for f in "$DIR"/*.md; do
      [ -f "$f" ] || continue
      name=$(basename "$f" .md)
      [ "$name" = "_INDEX" ] && continue
      type=$(field type "$f")
      desc=$(field description "$f")
      echo "| [$name](./$name.md) | ${type:--} | ${desc:--} |"
    done
  } > "$OUT"
fi
echo "index 갱신: $OUT"
