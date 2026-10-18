---
name: wiki-authoring
description: 'Use when writing or updating OKF knowledge nodes (docs/knowledge/*.md) — defines frontmatter schema, body structure, and the authoring discipline. 사용자가 "OKF 노드 작성", "위키 노드 만들어", "지식 노드 기록", "docs/knowledge 정리", "이 코드 위키화"라고 하거나, AI가 코드나 도메인 지식을 OKF 노드로 기록하거나 갱신할 때 스스로 사용. 핵심 원칙: 코드를 복제하지 않고 코드에 없는 맥락(이유, 관계, 조망)만 담는다.'
---

# OKF Authoring

OKF 지식 노드를 작성하거나 갱신할 때 따르는 양식과 작성 원칙 가이드다.

비유: 코드는 *무엇*을 하는지 말한다. OKF 노드는 *왜*, *어떤 관계로* 그렇게 됐는지를 코드 위에 얹는다.

---

## 1. frontmatter 스키마

모든 OKF 노드는 YAML frontmatter로 시작한다. `type`이 유일한 필수 필드다.

```yaml
---
# ── OKF 표준 표면 ──
type: <노드 종류>                 # 필수. 아래 종류표 참고
title: <노드 이름>                # 권장
description: <한 줄 요약>          # 권장
resource: <원본 위치>             # 권장. 예: repositories/<repo> 또는 src/<파일>
tags: [<태그>]                    # 권장
timestamp: <ISO8601, KST +09:00>  # 권장. 노드 생성·갱신 시점을 실제 시각으로 기록
# ── producer 확장 ──
status: <배포·사용 상태>          # 선택. 예: 운영 중, 개발계, 미배포, 사용 중, 보관
stack: [<구성요소>]               # 선택
depends_on:                       # 선택. 기계가독 관계 그래프 (본문 링크와 병행)
  - "[<관련 노드>](./<관련 노드>.md)"
---
```

### type 종류표

| type | 의미 | 예 |
|---|---|---|
| `Product` | 사용자 대상 서비스·앱 | 웹·모바일 서비스 |
| `Infra` | 배포·인프라 구성 | GitOps·k8s 매니페스트 |
| `Tool` | 개발·운영 도구 | DB 클라이언트 설정 |
| `Index` | 노드를 묶는 목차·지도 | `_INDEX.md` |
| `History` | 작업 이력 문서 | `docs/history/` 문서 |

`type`은 **열린 집합**이다. `Guide`, `Reference`, `Concept` 등 코드베이스 맥락에 맞는 값을 새로 쓸 수 있다.

### 필드 구분 요약

| 필드 | 구분 | 비고 |
|---|---|---|
| `type` | 필수 | OKF 유일 필수 필드 |
| `title` `description` `resource` `tags` `timestamp` | 권장 | OKF 표준 queryable 필드 |
| `status` `stack` `depends_on` | 선택 | producer 확장 (표준 자유 영역) |

---

## 2. 본문 구조

frontmatter 아래에 문서 제목(`# 제목`)을 먼저 쓴다. 이후 아래 섹션을 기반으로 작성한다.

```markdown
# <노드 제목>

## 요약
무엇을 하는 프로젝트·모듈인가, 왜 존재하나 (1~3줄)

## 구성
- <구성요소>: <설명>

## 관계
- [<관련 노드>](./<관련 노드>.md): <관계 설명>

## 상세 지식
- 코드·문서: `<원본 경로>`
- (Phase 2+) 데이터·스키마 노드: `<repo>/docs/knowledge/`
```

`## 관계` 섹션의 마크다운 링크가 OKF 표준의 관계 그래프를 충족한다.
frontmatter `depends_on`은 같은 관계를 기계가독 형태로 중복 표기하는 확장이다.

---

## 3. 작성 원칙 (핵심)

OKF 노드는 코드의 복제가 아니라, 코드 위에 얹는 *맥락 레이어*다.

### 무엇을 담나

코드를 봐도 빨리 파악되지 않는 것만 담는다:

- 왜 이렇게 설계됐는지 (이유·결정 배경)
- 여러 곳에 흩어진 도메인 흐름 (관계·조합)
- 전체 구조의 지도 (조망·컨텍스트)

### 무엇을 담지 않나 (복제 금지)

- 컬럼명, 타입, 메서드 시그니처 등 코드를 보면 바로 아는 것
- 자주 바뀌는 구현 세부를 단순 나열한 것

**코드를 복제하면 변경마다 노드가 어긋나고(drift), 맥락만 담으면 갱신 부담이 최소가 된다.**

### 싱크 회피

구현 내용은 원본 코드를 기준으로 확인한다. 자세한 구현은 `resource`로 원본을 연결하고, 노드에는 코드만으로 알기 어려운 맥락을 적는다.

```yaml
resource: repositories/my-service/src/domain/order
```

이렇게 하면 코드가 바뀌어도 노드가 틀리지 않는다. 노드엔 *코드를 읽을 때* 필요한 배경만 남긴다.

### 갱신 시점

원본(코드·스키마)이 바뀌면 *같은 PR에서* 관련 노드를 함께 갱신한다. 나중에 따로 하면 drift가 쌓인다.

### 한계 (사람이 점검할 것)

AI 혼자서는 이 원칙을 100% 지킨다고 보장할 수 없다. PR 리뷰에서 "코드를 복제하지 않았는지", "변경에 맞춰 갱신했는지"를 함께 점검한다.

### 좋은 노드 ↔ 나쁜 노드

같은 대상이라도 무엇을 담느냐로 갈린다.

**나쁜 예 (코드 복제)**: 코드를 보면 바로 아는 것을 옮겨 적었다. 코드가 바뀌면 곧 어긋난다.

> `User` 엔티티는 id, email, passwordHash, createdAt 필드를 가진다. `findByEmail`, `save` 메서드를 제공한다.

**좋은 예 (맥락)**: 코드를 봐도 빨리 보이지 않는 이유, 관계, 조망을 담았다.

> 인증은 email을 자연키로 쓴다(가입 시 중복 검사로 보장). 비밀번호는 해시만 저장하고 평문은 남기지 않는다. 이 엔티티의 유일한 쓰기 경로는 인증 서비스이며 다른 도메인은 읽기만 한다. 필드·시그니처 상세는 `resource` 참조.

### 작성 후 자기 점검

저장 전 다음을 확인한다.

- 코드만 보면 아는 것(컬럼, 타입, 시그니처)을 복제하지 않았는가
- 왜(이유), 관계, 조망 중 적어도 하나를 담았는가
- 상세는 `resource`로 원본을 가리키는가
- 자주 바뀌는 구현 세부를 단순 나열하지 않았는가

---

## 4. 날짜 표기

기계가 읽는 메타데이터는 표준을, 사람이 읽고 정렬하는 이름은 관습을 따른다.

| 대상 | 형식 | 예 |
|---|---|---|
| 파일명·폴더명 | `yyyy-MM-dd-<name>.md` | `2026-06-20-api-service.md` |
| frontmatter `timestamp` | ISO8601, KST `+09:00` | `2026-06-22T10:00:00+09:00` |

`timestamp` 값은 노드를 생성하거나 갱신하는 시점에 실제 시각을 조회해 기록한다. 과거 날짜를 추측해 넣지 않는다.

```bash
# 실제 시각 조회 예시
date '+%Y-%m-%dT%H:%M:%S+09:00'
```

---

## 5. 링크 규칙

OKF 표준은 마크다운 링크를 관계 그래프의 기반으로 삼는다.

```markdown
[infra-gitops](./infra-gitops.md)
```

- 같은 디렉토리 노드는 상대 경로 `./name.md`
- `[[wikilink]]`(Obsidian) 형식은 쓰지 않고 OKF 표준 링크만 사용

### 예약 파일명

| 파일명 | 역할 |
|---|---|
| `_INDEX.md` | 해당 디렉토리 노드의 목차·지도 (`type: Index`) |
| `log.md` | 노드 변경 이력 (`## [yyyy-MM-dd]` 시간순, Phase 2+ 옵션) |

---

## 전체 템플릿 (복붙용)

```markdown
---
type: Product
title: my-service
description: 사용자 주문·결제를 처리하는 백엔드 서비스
resource: repositories/my-service
tags: [backend, orders]
timestamp: 2026-06-22T10:00:00+09:00
status: 운영 중
stack: [NestJS, PostgreSQL]
depends_on:
  - "[infra-gitops](./infra-gitops.md)"
---

# my-service

## 요약
주문·결제 도메인을 담당하는 NestJS 백엔드 서비스. 모든 결제 흐름의 단일 진입점이다.

## 구성
- order: 주문 생성·상태 전이 처리
- payment: PG 연동 및 결제 검증

## 관계
- [infra-gitops](./infra-gitops.md): k8s에 배포됨

## 상세 지식
- 코드·문서: `repositories/my-service`
- 데이터·스키마 노드: `repositories/my-service/docs/knowledge/` (Phase 2+)
```
