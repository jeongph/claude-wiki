---
description: OKF 노드 frontmatter와 링크 검증
allowed-tools: [Bash]
---

# OKF Validate

`hooks/scripts/validate.sh`를 실행해 OKF 노드의 frontmatter 필드와 내부 링크를 검증하고 결과를 보고한다.

## 실행 흐름

---

## 단계 1: 검증 대상 경로 결정

검증 경로는 다음 순서로 정한다: ① 인자로 주어지면 그 경로 ② 없으면 `docs/knowledge/`. 이 단계에서 결정한 경로는 다음 단계에서 `validate.sh`에 인자로 명시적으로 전달한다. 인자 없이 실행하면 훅이 stdin으로 넘기는 편집 대상 파일 정보로만 경로를 찾는다. 그래서 그런 입력이 없는 수동 실행에서는 검증 대상이 없어 아무 출력 없이 종료된다.

---

## 단계 2: validate.sh 실행

`hooks/scripts/validate.sh`에 단계 1에서 결정한 경로를 인자로 넘겨 실행한다.

```bash
TARGET="${1:-docs/knowledge}"
bash hooks/scripts/validate.sh "$TARGET"
```

스크립트가 없으면 오류를 보고하고 중단한다.

```bash
[ -f hooks/scripts/validate.sh ] || echo "ERROR: hooks/scripts/validate.sh 없음"
```

---

## 단계 3: 결과 보고

스크립트 출력(exit code, 오류 목록)을 그대로 사용자에게 전달한다.

- exit code 0: 검증 통과. 이상 없음을 알린다.
- exit code 1 이상: 검증 실패. 오류 항목을 표로 정리해 보고한다.

**자동 수정 금지.** 오류 수정은 사용자 확인 후 별도 작업으로 진행한다.
