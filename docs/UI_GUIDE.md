# UI 디자인 가이드

값은 기존 웹 프로토타입(`family-sns.html`)에서 추출했다. 앱으로 포팅할 때 이 토큰을 그대로 가져간다.

## 디자인 원칙

1. 아이가 혼자서도 이해할 수 있어야 한다 — 글보다 이모지/스티커/큰 버튼 우선.
2. 보호자용 화면과 아이용 화면의 권한 차이가 레이블/배지로 명확히 드러나야 한다 (예: 칭찬판은 아이에게 "보기만" 표시).
3. 광고·마케팅 랜딩 느낌을 피하고, 매일 쓰는 가족 대화 도구처럼 따뜻하지만 단순하게 보여야 한다.

## AI 슬롭 안티패턴 — 하지 마라

| 금지 사항 | 이유 |
|-----------|------|
| backdrop-filter: blur() | glass morphism은 AI 템플릿의 가장 흔한 징후 |
| gradient-text (배경 그라데이션 텍스트) | AI가 만든 SaaS 랜딩의 1번 특징 |
| "Powered by AI" 배지 | 기능이 아니라 장식. 사용자에게 가치 없음 |
| box-shadow 글로우 애니메이션 | 네온 글로우 = AI 슬롭 |
| 보라/인디고 브랜드 색상 | "AI = 보라색" 클리셰. 이 앱은 크림/옐로/그린 계열 사용 |
| 모든 카드에 동일한 rounded-2xl | 균일한 둥근 모서리는 템플릿 느낌 (카드 18px, 버튼 999px로 구분) |
| 배경 gradient orb (blur-3xl 원형) | 모든 AI 랜딩 페이지에 있는 장식 |

## 색상

### 배경

| 용도 | 값 |
|------|------|
| 페이지 | `#FFF8EE` |
| 카드 | `#FFFFFF` |
| 보조 배경(배너/칩) | `#F6EEDD` |

### 텍스트

| 용도 | 값 |
|------|------|
| 주 텍스트 | `#2B2A33` |
| 보조/비활성 | `#8A8494` |
| 안내 텍스트(배너) | `#6A5A44` |

### 데이터/시맨틱 색상

| 용도 | 값 |
|------|------|
| 아이 포인트(로고, 강조) | `#FFB547` |
| 긍정/전송 버튼 | `#6BCB77` |
| 경고/긴급(글자) | `#C2364A` |
| 경고/긴급(배경) | `#FFE5E8` |
| 테두리/구분선 | `#F0E6D6` |

## 컴포넌트

### 카드

```text
border-radius: 18px; background: #FFFFFF; box-shadow: 0 1px 0 #F0E6D6; padding: 16px;
```

### 버튼

```text
Primary(전송): border-radius: 999px; background: #6BCB77; color: #FFFFFF; font-weight: 700;
Nav(선택): border-radius: 14px; background: #2B2A33; color: #FFFFFF;
Pill(필터/방 선택): border-radius: 999px; border: 2px solid #F0E6D6; (선택 시 background: #2B2A33)
```

### 입력 필드

```text
border-radius: 999px; background: #FFFFFF; outline: 2px solid #F0E6D6; padding: 12px 16px;
```

## 레이아웃

- 전체 너비: 모바일 단일 컬럼 (웹 프로토타입 기준 `max-width: 440px` 폭의 느낌 유지)
- 정렬: 좌측 정렬 기본. 중앙 정렬 금지
- 간격: 메시지 간 10px, 카드 간 12px, 하단 입력창은 상단 테두리로 구분

## 타이포그래피

| 용도 | 스타일 |
|------|--------|
| 로고/페이지 제목 | 22px, font-weight 800, letter-spacing -0.5px |
| 카드 제목 | 16px, font-weight 700 |
| 본문/말풍선 | 15px, line-height 1.4 |
| 메타(이름/시간) | 10~11px, font-weight 700, color `#8A8494` |

## 애니메이션

- 메시지 등장 fade-in 정도만 허용. 네온 글로우, 과한 트랜지션 금지.

## 아이콘

- 이모지 기반(기분 5종, 스티커 등)을 기본으로 하고, 별도 SVG 아이콘이 필요하면 strokeWidth 1.5, 둥근 배경 박스로 감싸지 않는다.
