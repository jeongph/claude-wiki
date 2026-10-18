---
description: 코드/소스를 OKF 노드로 추출(enrichment)
allowed-tools: [Bash, Read, Glob, Grep, Write, Task]
---

# OKF Ingest

인자로 받은 경로를 분석해 OKF 노드 초안을 생성하고, 사용자 검수 후 `docs/knowledge/`에 저장한다.

## 실행 흐름

단계 1 → 2 → 3 → 4 순서로 실행한다. 단계를 건너뛰거나 병합하지 않는다.

---

## 단계 1: 대상 경로 확인

인자로 받은 경로가 없으면 사용자에게 묻는다.

```
어떤 경로(파일 또는 디렉토리)를 OKF 노드로 추출할까요?
```

경로가 존재하는지 확인한다.

```bash
ls <경로>
```

---

## 단계 2: wiki-enrichment agent 호출

`Task` 도구로 `wiki-enrichment` agent를 호출한다.

- `description`: "OKF 노드 초안 생성"
- `prompt`: 대상 코드 경로와 함께 "wiki-authoring 양식을 따라 노드 초안을 만들되, 컬럼이나 시그니처를 복제하지 말고 관계와 맥락을 보강하라"는 지시를 담는다.

agent가 반환한 노드 초안을 화면에 출력한다.

---

## 단계 3: 사용자 검수

노드 초안을 사용자에게 보여주고 확인을 받는다.

- 수정이 필요한 부분을 사용자가 지정하면 반영한다.
- 저장 전까지 파일에 쓰지 않는다.

---

## 단계 4: docs/knowledge/ 저장 및 index·log 갱신

사용자가 승인하면 다음 순서로 저장한다.

1. 저장 경로 결정: `docs/knowledge/`. 파일명: `<경로>/<노드명>.md` (`wiki-authoring` skill의 날짜 표기 규칙 준수)
2. 파일 작성
3. `docs/knowledge/_INDEX.md`를 열어 새 노드 항목 추가
4. `docs/knowledge/log.md`에 아래 형식으로 한 줄 추가 (없으면 생성)

```
## [<yyyy-MM-dd>] ingest | <대상>
```

5. 변경 사항 요약 보고

```bash
# _INDEX.md 존재 확인
ls docs/knowledge/_INDEX.md
```

저장 완료 후 생성된 파일 경로와 index, log 변경 내용을 보고한다.
