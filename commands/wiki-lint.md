---
description: 위키 health-check
allowed-tools: [Bash, Read, Grep, Glob]
---

# OKF Lint

`wiki-lint` skill을 실행해 OKF 지식 노드의 정합성을 점검한다.

## 실행 흐름

`wiki-lint` skill의 절차를 그대로 따른다. 아래 순서로 실행한다.

---

## 단계 1: 점검 범위 결정

점검 경로는 다음 순서로 정한다: ① 인자로 주어지면 그 경로 ② 없으면 `docs/knowledge/`. 아래 각 코드 블록은 독립적으로 실행되어 셸 변수를 이어받지 않으므로, 모든 블록이 이 결정 로직을 처음부터 다시 수행한다.

```bash
# 코드 블록은 각각 독립적으로 실행되어 앞 블록의 변수를 이어받지 않으므로 매 블록에서 경로를 다시 계산한다.
WIKI_DIR="${1:-}"
[ -z "$WIKI_DIR" ] && WIKI_DIR=docs/knowledge
case "$WIKI_DIR" in ""|/) echo "ERROR: 점검 경로를 확인할 수 없음 ($WIKI_DIR)" >&2; exit 1 ;; esac

find "$WIKI_DIR" -name "*.md" | sort
```

---

## 단계 2: 모순 (Contradiction) 점검

같은 `title` 또는 `resource` 값을 가진 노드를 찾아 충돌 여부를 확인한다.

```bash
# 코드 블록은 각각 독립적으로 실행되어 앞 블록의 변수를 이어받지 않으므로 매 블록에서 경로를 다시 계산한다.
WIKI_DIR="${1:-}"
[ -z "$WIKI_DIR" ] && WIKI_DIR=docs/knowledge
case "$WIKI_DIR" in ""|/) echo "ERROR: 점검 경로를 확인할 수 없음 ($WIKI_DIR)" >&2; exit 1 ;; esac

grep -rh '^resource:' "$WIKI_DIR/" | sort | uniq -d
grep -rh '^title:' "$WIKI_DIR/" | sort | uniq -d
```

---

## 단계 3: Stale (오래된 노드) 점검

노드 `timestamp`와 `resource`의 마지막 git 변경 시각을 비교한다.

```bash
# 코드 블록은 각각 독립적으로 실행되어 앞 블록의 변수를 이어받지 않으므로 매 블록에서 경로를 다시 계산한다.
WIKI_DIR="${1:-}"
[ -z "$WIKI_DIR" ] && WIKI_DIR=docs/knowledge
case "$WIKI_DIR" in ""|/) echo "ERROR: 점검 경로를 확인할 수 없음 ($WIKI_DIR)" >&2; exit 1 ;; esac

grep -rn '^timestamp:' "$WIKI_DIR/"
git log --follow -1 --format="%ci" -- <resource 경로>
```

---

## 단계 4: Orphan (고아 노드) 점검

어느 노드도 링크하지 않는 노드를 찾는다.

```bash
# 코드 블록은 각각 독립적으로 실행되어 앞 블록의 변수를 이어받지 않으므로 매 블록에서 경로를 다시 계산한다.
WIKI_DIR="${1:-}"
[ -z "$WIKI_DIR" ] && WIKI_DIR=docs/knowledge
case "$WIKI_DIR" in ""|/) echo "ERROR: 점검 경로를 확인할 수 없음 ($WIKI_DIR)" >&2; exit 1 ;; esac

while IFS= read -r f; do
  name=$(basename "$f" .md)
  count=$(grep -rl "$name" "$WIKI_DIR/" | grep -v "^$f$" | wc -l | tr -d ' ')
  if [ "$count" -eq 0 ]; then echo "ORPHAN: $f"; fi
done < <(find "$WIKI_DIR" -name "*.md" -not -name "_INDEX.md")
```

---

## 단계 5: 누락 cross-ref / 미작성 노드 점검

관계 섹션의 링크 대상 파일이 실제로 존재하는지 확인한다.

```bash
# 코드 블록은 각각 독립적으로 실행되어 앞 블록의 변수를 이어받지 않으므로 매 블록에서 경로를 다시 계산한다.
WIKI_DIR="${1:-}"
[ -z "$WIKI_DIR" ] && WIKI_DIR=docs/knowledge
case "$WIKI_DIR" in ""|/) echo "ERROR: 점검 경로를 확인할 수 없음 ($WIKI_DIR)" >&2; exit 1 ;; esac

# (이 절차는 wiki-lint skill과 동기화 대상)
grep -rh '\[.*\](\.\/.*\.md)' "$WIKI_DIR/" \
  | grep -oE '\(\.\/[A-Za-z0-9_-]+\.md\)' \
  | sed -E 's/\(\.\/([^)]+)\)/\1/' | sort -u \
  | while read -r target; do
      [ -f "$WIKI_DIR/$target" ] || echo "MISSING: $target"
    done
```

---

## 단계 6: 결과 보고

4가지 점검 결과를 표로 합산해 보고한다. **자동 수정 금지.** 모든 수정은 사용자 확인 후 별도 작업으로 진행한다.

```
## OKF Lint 결과

점검 경로: <점검 경로>
점검 시각: <ISO8601, KST>

### 모순 (N건)
### Stale (N건)
### Orphan (N건)
### 누락 cross-ref (N건)

이상 발견 없음: ✅ / 발견: ⚠️ N건
```
