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
# 작업 이력(docs/history)은 목차를 만들지 않는다. 그 시점의 기록이라 필요할 때
# 파일명과 본문으로 찾으면 되고, 커밋되는 목차는 여러 브랜치가 동시에 이력을
# 쓸 때마다 충돌한다. 이미 있는 파일도 건드리지 않는다.
case "$DIR" in
  */docs/history|docs/history) exit 0 ;;
esac
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
echo "index 갱신: $OUT"
