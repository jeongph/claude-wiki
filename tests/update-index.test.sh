#!/usr/bin/env bash
# update-index.sh 회귀 테스트
#
# 목적: _INDEX.md 생성 결과가 실행 환경의 로케일에 좌우되지 않음을 보장한다.
#   glob 확장 정렬은 LC_COLLATE에 종속되므로, 로케일을 고정하지 않으면
#   같은 디렉토리에서도 머신마다 다른 순서의 _INDEX.md가 만들어진다.
#   그 결과 노드를 건드리지 않은 커밋에 순서 diff가 딸려 들어간다.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/hooks/scripts/update-index.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

ok()   { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
nope() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

# 정렬 차이를 드러내는 픽스처를 만든다.
#  - 한글 노드: 로케일별 한글 정렬 규칙 차이를 드러낸다
#  - ASCII 대/소문자 혼합: C(코드포인트)와 UTF-8 로케일(대소문자 무시)의 차이를 드러낸다
make_fixture() {
  local dir="$1"
  mkdir -p "$dir"
  local n
  for n in 릴리스-트랙과-호환성 모바일-스토어-배포-자동화 세션-자정-분할-집계 Alpha beta Gamma-node; do
    printf -- '---\ntype: Concept\ndescription: %s 설명\n---\n\n# %s\n' "$n" "$n" > "$dir/$n.md"
  done
}

# history 노드 픽스처. 파일명은 yyyy-MM-dd-NNN-<author>-<작업명>.md 규칙을 따른다.
# 2026-01-02에 순번(001, 002)만 다른 문서 두 개를 둬서, 날짜가 같을 때
# 순번 역순으로 정렬되는지 검증할 수 있게 한다.
# 마지막 문서는 본문에도 YAML 리스트처럼 보이는 줄을 둬서, frontmatter 범위를
# 벗어난 항목이 tags에 섞이지 않는지 확인한다.
make_history_fixture() {
  local dir="$1"
  mkdir -p "$dir"
  printf -- '---\ntype: History\ntitle: 첫 작업\ndescription: 첫 작업 설명\ntags:\n  - feat\n---\n\n# 첫 작업\n' \
    > "$dir/2026-01-02-001-claude-첫-작업.md"
  printf -- '---\ntype: History\ntitle: 같은 날 두 번째 작업\ndescription: 같은 날짜 순번 역순 검증용\ntags:\n  - docs\n---\n\n# 같은 날 두 번째 작업\n' \
    > "$dir/2026-01-02-002-claude-같은날-두번째-작업.md"
  printf -- '---\ntype: History\ntitle: 둘째 작업\ndescription: 둘째 작업 설명\ntags:\n  - fix\n  - ci\n---\n\n# 둘째 작업\n\n본문 목록:\n  - 본문에 있는 항목\n' \
    > "$dir/2026-03-04-001-claude-둘째-작업.md"
}

# 플로우 스타일(tags: [a, b]) frontmatter 픽스처. OKF 컨벤션 문서의 필드
# 템플릿이 이 표기를 예시로 보여주므로 실제로 파싱되는지 확인해야 한다.
# 간격이 일관되지 않은 표기, 단일 항목, 빈 목록을 각각 검증하고, 첫 문서는
# 본문에도 리스트처럼 보이는 줄을 둬서 frontmatter 밖 내용이 섞이지 않는지
# 함께 확인한다.
make_history_flow_tags_fixture() {
  local dir="$1"
  mkdir -p "$dir"
  printf -- '---\ntype: History\ntitle: 플로우 다중\ndescription: 플로우 스타일 다중 tags\ntags: [feat, fix]\n---\n\n# 플로우 다중\n\n본문 목록:\n  - 본문에 있는 항목\n' \
    > "$dir/2026-05-01-001-claude-플로우-다중.md"
  printf -- '---\ntype: History\ntitle: 플로우 간격 불균일\ndescription: 플로우 스타일 간격 불균일\ntags:  [  feat ,fix  ]\n---\n\n# 플로우 간격 불균일\n' \
    > "$dir/2026-05-01-002-claude-플로우-간격.md"
  printf -- '---\ntype: History\ntitle: 플로우 단일\ndescription: 플로우 스타일 단일 항목\ntags: [feat]\n---\n\n# 플로우 단일\n' \
    > "$dir/2026-05-01-003-claude-플로우-단일.md"
  printf -- '---\ntype: History\ntitle: 플로우 빈 목록\ndescription: 플로우 스타일 빈 목록\ntags: []\n---\n\n# 플로우 빈 목록\n' \
    > "$dir/2026-05-01-004-claude-플로우-빈목록.md"
}

# 시스템에 실재하는 로케일만 테스트 대상으로 삼는다.
# 없는 로케일은 경고 없이 C로 폴백하므로 테스트가 무의미해진다.
# (macOS 기본 bash 3.2에는 mapfile이 없어 공백 구분 문자열로 넘긴다)
available_locales() {
  local all cand found=""
  all=$(locale -a 2>/dev/null || true)
  for cand in C en_US.UTF-8 ko_KR.UTF-8 ja_JP.UTF-8 de_DE.UTF-8; do
    # grep -q는 매치 즉시 종료해 상류에 SIGPIPE를 보낸다.
    # pipefail이 켜져 있으면 그 141이 파이프라인 결과가 되므로 -q를 쓰지 않는다.
    if [ "$cand" = "C" ] || printf '%s\n' "$all" | grep -xF "$cand" >/dev/null; then
      found="$found $cand"
    fi
  done
  printf '%s' "${found# }"
}

# --- 테스트 1: 로케일이 달라도 index.md 내용이 동일하다 ---
test_locale_independent_output() {
  local dir="$WORK/case1/docs/knowledge"
  make_fixture "$dir"

  local baseline="" baseline_locale="" differing="" locales count
  locales=$(available_locales)
  count=$(printf '%s\n' $locales | grep -c .)

  if [ "$count" -lt 2 ]; then
    nope "로케일 독립성: 비교할 로케일이 2개 미만이라 검증 불가 (${locales:-없음})"
    return
  fi

  local loc out
  for loc in $locales; do
    LC_ALL="$loc" bash "$SCRIPT" "$dir" >/dev/null 2>&1
    out=$(cat "$dir/_INDEX.md")
    if [ -z "$baseline" ]; then
      baseline="$out"
      baseline_locale="$loc"
    elif [ "$out" != "$baseline" ]; then
      differing="$differing $loc"
    fi
  done
  differing="${differing# }"

  if [ -z "$differing" ]; then
    ok "로케일 독립성: ${count}개 로케일($locales)에서 index.md 동일"
  else
    local first
    first=$(printf '%s' "$differing" | cut -d' ' -f1)
    nope "로케일 독립성: ${baseline_locale} 대비 ${differing}에서 index.md가 다름"
    printf '       --- %s vs %s ---\n' "$baseline_locale" "$first"
    LC_ALL="$first" bash "$SCRIPT" "$dir" >/dev/null 2>&1
    diff <(printf '%s\n' "$baseline") "$dir/_INDEX.md" | sed 's/^/       /'
  fi
}

# --- 테스트 2: 같은 로케일에서 반복 실행하면 결과가 멱등하다 ---
test_idempotent() {
  local dir="$WORK/case2/docs/knowledge"
  make_fixture "$dir"

  bash "$SCRIPT" "$dir" >/dev/null 2>&1
  local first
  first=$(cat "$dir/_INDEX.md")
  bash "$SCRIPT" "$dir" >/dev/null 2>&1

  if [ "$first" = "$(cat "$dir/_INDEX.md")" ]; then
    ok "멱등성: 반복 실행해도 index.md 동일"
  else
    nope "멱등성: 반복 실행 결과가 다름"
  fi
}

# --- 테스트 3: index.md 자신은 목록에 포함되지 않는다 ---
test_excludes_self() {
  local dir="$WORK/case3/docs/knowledge"
  make_fixture "$dir"

  bash "$SCRIPT" "$dir" >/dev/null 2>&1
  bash "$SCRIPT" "$dir" >/dev/null 2>&1

  if grep -q '\[_INDEX\](\./_INDEX\.md)' "$dir/_INDEX.md"; then
    nope "자기 제외: _INDEX.md가 자기 자신을 목록에 포함함"
  else
    ok "자기 제외: _INDEX.md가 목록에서 빠짐"
  fi
}

# --- 테스트 4: 노드의 type과 description이 그대로 반영된다 (정렬 수정의 부작용 감시) ---
test_preserves_metadata() {
  local dir="$WORK/case4/docs/knowledge"
  make_fixture "$dir"

  bash "$SCRIPT" "$dir" >/dev/null 2>&1

  if grep -qF '| [릴리스-트랙과-호환성](./릴리스-트랙과-호환성.md) | Concept | 릴리스-트랙과-호환성 설명 |' "$dir/_INDEX.md"; then
    ok "메타데이터: 한글 노드의 type과 description이 온전히 반영됨"
  else
    nope "메타데이터: 한글 노드 행이 기대와 다름"
    grep '릴리스' "$dir/_INDEX.md" | sed 's/^/       /'
  fi
}

# --- 테스트 5: history 디렉토리는 전용 스키마로 생성된다 ---
test_history_schema() {
  local dir="$WORK/case5/docs/history"
  make_history_fixture "$dir"

  bash "$SCRIPT" "$dir" >/dev/null 2>&1

  if grep -qF '| 날짜 | 제목 | tags |' "$dir/_INDEX.md"; then
    ok "history 스키마: 헤더가 날짜|제목|tags"
  else
    nope "history 스키마: 헤더가 기대와 다름"
    head -10 "$dir/_INDEX.md" | sed 's/^/       /'
  fi

  if grep -qF '| 2026-03-04 | [둘째 작업](./2026-03-04-001-claude-둘째-작업.md) | fix, ci |' "$dir/_INDEX.md"; then
    ok "history 행: 날짜, 제목, 다중 tags가 정확하고 본문 목록이 섞이지 않음"
  else
    nope "history 행: 기대와 다름"
    grep '둘째' "$dir/_INDEX.md" | sed 's/^/       /'
  fi
}

# --- 테스트 6: history는 날짜 역순(최신 우선)으로, 같은 날짜 안에서는
#     순번 역순으로 정렬된다 ---
test_history_order() {
  local dir="$WORK/case6/docs/history"
  make_history_fixture "$dir"

  bash "$SCRIPT" "$dir" >/dev/null 2>&1

  local first_row
  first_row=$(grep '^| 2026-' "$dir/_INDEX.md" | head -1)
  case "$first_row" in
    *2026-03-04*) ok "history 정렬: 최신이 맨 위" ;;
    *)            nope "history 정렬: 최신이 맨 위가 아님 (첫 행: $first_row)" ;;
  esac

  # 날짜 문자열(앞 10자)만 비교하면 같은 날짜 안의 순번 역순은 드러나지
  # 않는다. 파일명 전체(날짜+순번) 기준 정렬인지 별도로 확인한다.
  local same_date_rows first_same second_same
  same_date_rows=$(grep '^| 2026-01-02 ' "$dir/_INDEX.md")
  first_same=$(printf '%s\n' "$same_date_rows" | sed -n '1p')
  second_same=$(printf '%s\n' "$same_date_rows" | sed -n '2p')
  if printf '%s' "$first_same" | grep -qF '2026-01-02-002-claude-같은날-두번째-작업' \
     && printf '%s' "$second_same" | grep -qF '2026-01-02-001-claude-첫-작업'; then
    ok "history 정렬: 같은 날짜 안에서는 순번 역순"
  else
    nope "history 정렬: 같은 날짜 안에서 순번 역순이 아님"
    printf '%s\n' "$same_date_rows" | sed 's/^/       /'
  fi
}

# --- 테스트 7: 플로우 스타일 tags(tags: [a, b])도 블록 스타일과 동일하게
#     파싱된다 ---
test_flow_style_tags() {
  local dir="$WORK/case7flow/docs/history"
  make_history_flow_tags_fixture "$dir"

  bash "$SCRIPT" "$dir" >/dev/null 2>&1

  if grep -qF '| 2026-05-01 | [플로우 다중](./2026-05-01-001-claude-플로우-다중.md) | feat, fix |' "$dir/_INDEX.md"; then
    ok "플로우 tags: 다중 항목이 블록 스타일과 동일하게 파싱됨"
  else
    nope "플로우 tags: 다중 항목 파싱이 기대와 다름"
    grep '플로우 다중' "$dir/_INDEX.md" | sed 's/^/       /'
  fi

  if grep -qF '| 2026-05-01 | [플로우 간격 불균일](./2026-05-01-002-claude-플로우-간격.md) | feat, fix |' "$dir/_INDEX.md"; then
    ok "플로우 tags: 불균일한 간격이 정규화됨"
  else
    nope "플로우 tags: 간격 불균일 케이스가 기대와 다름"
    grep '플로우 간격' "$dir/_INDEX.md" | sed 's/^/       /'
  fi

  if grep -qF '| 2026-05-01 | [플로우 단일](./2026-05-01-003-claude-플로우-단일.md) | feat |' "$dir/_INDEX.md"; then
    ok "플로우 tags: 단일 항목이 파싱됨"
  else
    nope "플로우 tags: 단일 항목이 기대와 다름"
    grep '플로우 단일' "$dir/_INDEX.md" | sed 's/^/       /'
  fi

  if grep -qF '| 2026-05-01 | [플로우 빈 목록](./2026-05-01-004-claude-플로우-빈목록.md) | - |' "$dir/_INDEX.md"; then
    ok "플로우 tags: 빈 목록은 빈 값으로 처리됨"
  else
    nope "플로우 tags: 빈 목록 케이스가 기대와 다름"
    grep '플로우 빈 목록' "$dir/_INDEX.md" | sed 's/^/       /'
  fi

  if grep -qF '본문에 있는 항목' "$dir/_INDEX.md"; then
    nope "플로우 tags: 본문 목록이 tags로 새어 나감"
  else
    ok "플로우 tags: 본문 목록이 섞이지 않음"
  fi
}

# --- 테스트 8: 이전 이름의 인덱스는 새 이름으로 옮겨진다 ---
# 옮기지 않으면 일반 노드로 잡혀 목록에 인덱스 자신이 들어가고,
# 갱신이 멈춘 파일이 실제와 어긋난 채 남는다.
test_migrates_legacy_index() {
  local dir="$WORK/case7/docs/knowledge"
  make_fixture "$dir"
  printf -- '---\ntype: Index\ntitle: OKF 노드 지도\n---\n\n# OKF 노드 지도\n' > "$dir/index.md"

  bash "$SCRIPT" "$dir" >/dev/null 2>&1

  if [ -f "$dir/index.md" ]; then
    nope "레거시 이전: 이전 이름의 인덱스가 남아 있음"
  elif grep -q '\[index\](\./index\.md)' "$dir/_INDEX.md"; then
    nope "레거시 이전: 이전 인덱스가 목록에 노드로 들어감"
  else
    ok "레거시 이전: 이전 이름의 인덱스가 정리됨"
  fi
}

# --- 테스트 9: 사용자가 만든 index.md(인덱스가 아닌 노드)는 보존한다 ---
test_preserves_user_node_named_index() {
  local dir="$WORK/case8/docs/knowledge"
  mkdir -p "$dir"
  printf -- '---\ntype: Concept\ndescription: 사용자가 직접 쓴 노드\n---\n\n# index\n' > "$dir/index.md"

  bash "$SCRIPT" "$dir" >/dev/null 2>&1

  if [ ! -f "$dir/index.md" ]; then
    nope "사용자 노드 보존: type이 Index가 아닌 index.md를 지워버림"
  elif grep -qF '| [index](./index.md) | Concept | 사용자가 직접 쓴 노드 |' "$dir/_INDEX.md"; then
    ok "사용자 노드 보존: index.md가 일반 노드로 유지됨"
  else
    nope "사용자 노드 보존: 목록에서 기대한 행을 찾지 못함"
    grep '^|' "$dir/_INDEX.md" | sed 's/^/       /'
  fi
}

printf 'update-index.sh 회귀 테스트\n'
test_locale_independent_output
test_idempotent
test_excludes_self
test_preserves_metadata
test_history_schema
test_history_order
test_flow_style_tags
test_migrates_legacy_index
test_preserves_user_node_named_index

printf '\n통과 %d · 실패 %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
