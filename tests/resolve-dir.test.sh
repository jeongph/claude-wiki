#!/usr/bin/env bash
# lib-resolve-dir.sh 회귀 테스트
#
# 목적: 훅이 도는 범위를 "위키 안의 파일을 편집했을 때"로 한정한다.
#   이전에는 편집 파일의 상위를 거슬러 올라가며 docs/knowledge를 "찾았기" 때문에,
#   레포 안 어떤 파일을 건드려도(README, src/**) index가 재생성됐고
#   루프가 /까지 올라가 레포 경계마저 넘었다.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LIB="$ROOT/hooks/scripts/lib-resolve-dir.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

ok()   { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
nope() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

# 훅이 넘기는 형태의 stdin JSON으로 resolve_wiki_dir를 호출한다.
resolve() {
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1" \
    | bash -c "source '$LIB'; resolve_wiki_dir ''"
}

# 기대 경로와 실제 결과를 비교한다. want가 빈 문자열이면 "무동작"을 기대한다.
expect() {
  local label="$1" file="$2" want="$3" got
  got=$(resolve "$file")
  if [ "$got" = "$want" ]; then
    ok "$label"
  else
    nope "$label"
    printf '       file: %s\n' "$file"
    printf '       기대: %s\n' "${want:-<무동작>}"
    printf '       실제: %s\n' "${got:-<무동작>}"
  fi
}

# 레포 하나를 통째로 만든다. 위키가 있고, 위키와 무관한 파일도 함께 둔다.
REPO="$WORK/repo"
mkdir -p "$REPO/docs/knowledge/sub" \
         "$REPO/docs/superpowers/specs" \
         "$REPO/src/deep/nested"
mkdir -p "$REPO/.git"   # 레포 경계 표시용
: > "$REPO/docs/knowledge/노드.md"
: > "$REPO/docs/knowledge/sub/하위노드.md"
: > "$REPO/docs/superpowers/specs/spec.md"
: > "$REPO/src/deep/nested/App.tsx"
: > "$REPO/README.md"

# docs/history를 쓰는 레포를 만든다.
REPO2="$WORK/repo-history"
mkdir -p "$REPO2/docs/history"
: > "$REPO2/docs/history/2026-01-02-001-claude-작업.md"
: > "$REPO2/README.md"

# 지원이 끊긴 docs/okf 레포. 무동작이어야 한다.
REPO3="$WORK/repo-okf"
mkdir -p "$REPO3/docs/okf"
: > "$REPO3/docs/okf/노드.md"

# 위키 바깥, 상위 디렉토리에 위키가 있는 별개 프로젝트 (레포 경계 침범 검증용)
mkdir -p "$WORK/repo/other-project/src"
: > "$WORK/repo/other-project/src/index.ts"

printf 'lib-resolve-dir.sh 회귀 테스트\n'

# --- 위키 안의 파일이면 그 위키를 반환한다 ---
expect "위키 최상위 노드 → 위키 반환"   "$REPO/docs/knowledge/노드.md"        "$REPO/docs/knowledge"
expect "위키 하위 노드 → 위키 반환"     "$REPO/docs/knowledge/sub/하위노드.md" "$REPO/docs/knowledge"
expect "docs/history 노드 → 디렉토리 반환" "$REPO2/docs/history/2026-01-02-001-claude-작업.md" "$REPO2/docs/history"

# --- 위키 밖의 파일이면 무동작이어야 한다 ---
expect "레포 루트 README → 무동작"       "$REPO/README.md"                     ""
expect "src 깊은 파일 → 무동작"          "$REPO/src/deep/nested/App.tsx"       ""
expect "docs 아래 다른 폴더 → 무동작"    "$REPO/docs/superpowers/specs/spec.md" ""
expect "상위에 위키가 있는 별개 프로젝트 → 무동작" "$WORK/repo/other-project/src/index.ts" ""
expect "docs/okf 노드 → 무동작(지원 종료)"  "$REPO3/docs/okf/노드.md"             ""

# --- 인자로 경로를 직접 주는 경로는 그대로 유지된다 (커맨드에서 호출하는 방식) ---
direct=$(bash -c "source '$LIB'; resolve_wiki_dir '$REPO/docs/knowledge'" </dev/null)
if [ "$direct" = "$REPO/docs/knowledge" ]; then
  ok "인자 직접 지정 → 그대로 반환"
else
  nope "인자 직접 지정 → 그대로 반환 (실제: ${direct:-<빈값>})"
fi

# --- file_path가 없는 payload는 조용히 무동작 ---
empty=$(printf '{"tool_name":"Bash"}' | bash -c "source '$LIB'; resolve_wiki_dir ''")
if [ -z "$empty" ]; then
  ok "file_path 없는 payload → 무동작"
else
  nope "file_path 없는 payload → 무동작 (실제: $empty)"
fi

printf '\n통과 %d · 실패 %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
