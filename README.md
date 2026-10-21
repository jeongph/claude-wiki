# claude-wiki

[![version](https://img.shields.io/github/v/release/jeongph/claude-wiki?label=version&color=blue)](https://github.com/jeongph/claude-wiki/releases)
[![license](https://img.shields.io/github/license/jeongph/claude-wiki?color=lightgrey)](LICENSE)

코드와 문서를 바탕으로 위키를 작성하고, 내용을 점검하거나 위키에서 답을 찾습니다.

코드에서 위키 문서인 노드의 초안을 만들고, 저장할 때 형식을 검증하며 지식 노드 목차(`docs/knowledge/_INDEX.md`)를 갱신합니다. 문서 간 모순과 오래된 내용을 점검하고, 위키에 기록된 근거를 바탕으로 질문에 답합니다.

## 개념

- **OKF** (Open Knowledge Format, Google): 지식 노드를 마크다운과 YAML frontmatter로 작성하는 형식이다. `type` 필드로 노드 종류를 지정하고 마크다운 링크로 노드 간 관계를 연결한다
- **LLM-wiki** (Andrej Karpathy): 에이전트가 읽고 관리하는 마크다운 지식베이스다. 원본 자료(`raw`), 정리된 문서(`wiki`), 스키마를 구분하고 자료 추가, 질의, 검사를 수행한다
- **claude-wiki**: OKF의 문서 형식과 LLM-wiki의 운영 절차를 Claude Code에서 사용하도록 구성한 플러그인이다

## 설치

[jeongph/claude-plugins 마켓플레이스](https://github.com/jeongph/claude-plugins)에서 설치한다.

마켓플레이스 등록(최초 1회):

```sh
/plugin marketplace add jeongph/claude-plugins
```

플러그인 설치:

```sh
/plugin install claude-wiki@jeongph-claude-plugins
```

설치 후 Claude Code를 재시작하면 플러그인이 자동 활성화된다.

### 이전 이름(claude-okf)을 쓰던 경우

플러그인 이름이 `claude-okf`에서 `claude-wiki`로 바뀌었다. OKF는 노드 포맷 표준의 이름이라 플러그인이 포맷 검사기처럼 읽혔으나, 실제 역할은 노드 작성, 검증, 인덱스 생성, 질의응답까지 포함한다.

식별자가 달라져 자동 전환되지 않으므로 이전 것을 제거하고 새로 설치한다.

```sh
/plugin uninstall claude-okf@jeongph-claude-plugins
/plugin marketplace update jeongph-claude-plugins
/plugin install claude-wiki@jeongph-claude-plugins
```

명령, skill, agent 이름의 접두사도 `okf-`에서 `wiki-`로 바뀌었다 (`/okf-ask` → `/wiki-ask` 등). **노드 포맷과 OKF 규약 자체는 그대로**이므로 기존 `docs/knowledge/` 내용은 손댈 필요가 없다.

## 컴포넌트

| 종류 | 이름 | 역할 |
|------|------|------|
| skill | `wiki-authoring` | OKF 노드 작성과 편집 가이드. 양식 안내와 노드 초안 생성 |
| skill | `wiki-lint` | OKF 노드 정적 검사. frontmatter 필수 필드와 관계 링크 검증 |
| command | `/wiki-ingest` | 코드와 문서를 분석해 OKF 노드 초안을 생성하고 wiki에 추가 |
| command | `/wiki-validate` | 지정 경로의 OKF 노드를 검증하고 오류를 보고 |
| command | `/wiki-lint` | OKF 노드 lint 실행 (오래된 링크, 중복 노드, 모순 점검) |
| command | `/wiki-ask` | OKF wiki를 기반으로 근거가 있는 답변 생성 |
| hook | `PostToolUse (Write\|Edit 트리거)` | 노드 저장 시 자동으로 검증과 index 갱신 실행 |
| agent | `wiki-enrichment` | 코드베이스 분석 후 OKF 노드에 내용을 보강하는 전용 에이전트 |

## 사용 예

### 코드에서 노드 초안 생성

```
/wiki-ingest repositories/my-service/src
```

`src` 디렉토리를 분석해 OKF 노드 초안을 생성하고 wiki에 추가한다.

### 노드 작성 시 자동 검증

OKF 노드 파일(`.md`)을 편집하거나 저장하면 `PostToolUse (Write|Edit 트리거)` 훅이 자동으로 실행된다.

- frontmatter 필수 필드(`type` 등) 누락 검사
- 관계 링크 유효성 검증
- `docs/knowledge/_INDEX.md` 갱신(작업 이력은 목차를 만들지 않는다)

노드 디렉토리는 `docs/knowledge/` 또는 `docs/history/`만 인식한다. `docs/okf/`는
더 이상 인식되지 않으므로, 그 경로에 노드가 있다면 `docs/knowledge/`로 옮긴다.

`docs/knowledge/`는 노드 지도(`| 노드 | type | 요약 |`)를 생성한다. `_INDEX.md`는
생성물이므로 직접 편집하지 않는다.

`docs/history/`는 검증만 하고 목차는 만들지 않는다. 작업 이력은 그 시점의 기록이라
필요할 때 파일명과 본문을 검색하면 되고, 커밋되는 목차는 여러 브랜치가 동시에 이력을
쓸 때마다 충돌한다. 0.7.0 이하가 만든 `docs/history/_INDEX.md`는 더 이상 갱신되지
않으니 저장소에서 지운다. 훅은 이 파일을 지우거나 고치지 않는다.

이전 버전은 지식 노드 인덱스를 `index.md` 또는 `INDEX.md`로 만들었다. 훅이 처음 실행될 때
`_INDEX.md`로 자동 변경되므로 별도 조치는 필요 없다. `type`이 `Index`인 파일만
대상이라 같은 이름의 일반 노드는 그대로 남는다.

오류가 있으면 편집 직후 터미널에 보고된다.

### 위키 기반 질의

```
/wiki-ask my-service는 어떤 인프라에 배포되나요?
```

OKF wiki를 검색해 근거가 있는 답변을 생성한다.

### 수동 노드 검증

```
/wiki-validate docs/knowledge/my-node.md
```

지정 파일의 OKF 노드를 검증하고 오류 목록을 출력한다.

## 세션 핸드오프는 어디로 갔나

`handoff` 스킬과 `/handoff` 커맨드는 [claude-tidy](https://github.com/jeongph/claude-tidy) 플러그인으로 이관됐다 (v0.5.0). claude-tidy의 handoff는 범용 세션 인수인계를 담당하며, OKF 프로젝트(`docs/knowledge/`)를 감지하면 기존과 같은 절차(History 노드 마감, resume 스냅샷, 트래커 동기화)를 수행한다.

## 라이선스

MIT ([LICENSE](LICENSE) 참조)
