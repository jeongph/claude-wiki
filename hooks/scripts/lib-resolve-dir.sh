#!/usr/bin/env bash
# OKF 노드 디렉토리를 결정한다.
#  1) 인자로 경로가 주어지면 그대로 사용한다.
#  2) 없으면 PostToolUse hook이 stdin으로 넘긴 JSON에서 file_path를 읽고,
#     그 파일이 노드 디렉토리(docs/knowledge 또는 docs/history) 안에 있을 때만 반환한다.
# 찾지 못하면 빈 문자열을 반환한다(호출 측에서 무동작 처리).
#
# 편집한 파일이 위키 "안"인지만 본다. 예전처럼 상위를 거슬러 올라가며 위키를
# 탐색하면 레포 안 어떤 파일을 건드려도(README, src/**) index가 재생성되고,
# 루프가 /까지 올라가 레포 경계까지 넘는다.
resolve_wiki_dir() {
  local dir="${1:-}"
  if [ -n "$dir" ]; then
    printf '%s' "$dir"
    return 0
  fi

  local payload file d p
  payload=$(cat 2>/dev/null || true)
  file=$(printf '%s' "$payload" \
    | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' || true)
  [ -z "$file" ] && return 0

  # 조상 중에 위키 디렉토리 자신이 있는지 본다(위키 하위 폴더의 노드도 포함).
  d=$(dirname "$file")
  while [ "$d" != "/" ] && [ "$d" != "." ]; do
    case "$d" in
      */docs/knowledge|docs/knowledge|*/docs/history|docs/history)
        [ -d "$d" ] && { printf '%s' "$d"; return 0; }
        ;;
    esac
    p=$(dirname "$d")
    [ "$p" = "$d" ] && break
    d="$p"
  done
  return 0
}
