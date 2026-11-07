# LIMIT BREAK — 수 방어전

숫자를 0으로 만들어 코어를 지키는 타워 디펜스. (Godot 4.7, 한국어)

## 설치 (Windows)

PowerShell에서 한 줄:

```
irm https://raw.githubusercontent.com/dkssud9999/math-TD/main/install.ps1 | iex
```

최신 릴리스를 `%LOCALAPPDATA%\LimitBreak`에 설치하고 바탕화면에 바로가기를 만듭니다. 또는 [릴리스 페이지](https://github.com/dkssud9999/math-TD/releases)에서 LimitBreak.zip을 받아 풀고 LimitBreak.exe를 실행하세요.

## 실행 (소스에서)

Godot 4.7에서 이 폴더를 열고 **F5**. 또는:

```
Godot_v4.7.2-stable_win64.exe --path .
```

## 규칙

- 적의 체력은 그 숫자 자체입니다. 0이 되면 사라집니다.
- 코어에 닿으면 자릿수만큼 코어 체력이 깎입니다 (7은 1, 100은 3).
- 스테이지를 깨거나, **져도** 통찰이 쌓입니다. 메뉴의 연구실에서 통찰로 새 연산을 여세요.
- 별 3개: 클리어 · 코어 체력 절반 이상 · 누출 0.
- 진행은 자동 저장됩니다. 메뉴에서 「기록 초기화」로 지울 수 있습니다.

## 조작

| 키 | 동작 |
| --- | --- |
| 1–9, 0 | 타워 선택 (빈 칸 클릭으로 건설, Shift+클릭 연속 건설) |
| Space | 다음 웨이브 시작 |
| U / Del | 선택한 타워 강화 / 판매 |
| T | 조준 방식 (선두 · 최대 위협 · 최근접) |
| W | 일부 타워의 매개변수 전환 |
| A | 자동 진행 (웨이브를 깨면 1.5초 뒤 다음 웨이브 자동 시작) |
| Space (웨이브 중) | 조기 호출: 스폰이 끝났으면 다음 웨이브를 바로 불러 보너스 ρ |
| X | 궁극기: 화면의 모든 함수에 x = 0 대입 (2장부터, 스테이지당 2회) |
| E | 알고리즘 편집기: 선택한 타워의 공격 알고리즘(.py)을 직접 짭니다 (6장부터) |
| 적에 마우스 | 식 · 소멸자 · 피해 · 지금 배치로 통과할 때의 예측 |
| P | 일시정지 |
| 우클릭 / Esc | 취소 |

상단 바에서 배속(1× · 2× · 3×)과 소리(켬 · 음악 끔 · 끔)를 바꿀 수 있습니다.

---

> **아래는 개발자용입니다. 게임 내용 스포일러가 있습니다.**

## 개발자용

- 인수인계 문서: [HANDOFF.md](HANDOFF.md) (구조, 설계 원칙, 도구, 남은 일)
- 플레이테스트 체크리스트: https://claude.ai/artifact/1d1PAwK5sLK4KgkNRdC5r5

### 테스트

```
# 수학 계산 검증 (실제 항등식 약 2,880개)
godot --headless --path . --script res://tests/test_expr.gd

# 게임 속 파이썬 인터프리터 검증 (실제 파이썬과 같은 출력인지)
godot --headless --path . --script res://tests/test_py.gd

# 전 스테이지 봇 밸런스 측정 (병렬, 약 10분)
bash tests/balance.sh            # 각 경우 2회
bash tests/balance.sh 1 12       # 각 경우 1회, 12개 병렬
STAGES="7-1 7-2" bash tests/balance.sh

# 스테이지 하나를 봇으로
godot --headless --fixed-fps 60 --path . res://scenes/main.tscn -- --autotest --stage=1-3 --budget --research=none --ts=1
```

`godot`은 `Godot_v4.7.2-stable_win64_console.exe`를 말합니다. 봇은 실제 저장 파일을 건드리지 않습니다.

### 플레이테스트용 실행 옵션

| 옵션 | 효과 |
| --- | --- |
| `-- --dev-unlock` | 1-1~1-5 클리어 상태, 통찰 60 |
| `-- --dev-unlock=all` | 모든 장과 스테이지 열림, 통찰 600 |

두 옵션 모두 저장 파일에 쓰지 않습니다.
