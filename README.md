# LIMIT BREAK — 수 방어전

숫자를 0으로 만들어 코어를 지키는 타워 디펜스. (Godot 4.7, 한국어)

## 설치 (Windows)

PowerShell에서 한 줄:

```
irm https://raw.githubusercontent.com/dkssud9999/math-TD/main/install.ps1 | iex
```

최신 릴리스를 `%LOCALAPPDATA%\LimitBreak`에 설치하고 바탕화면에 바로가기를 만듭니다. 또는 [릴리스 페이지](https://github.com/dkssud9999/math-TD/releases)에서 LimitBreak.zip을 받아 풀고 LimitBreak.exe를 실행하세요.

## 업데이트

1. 게임을 닫습니다. 켜져 있으면 설치 프로그램이 아무것도 바꾸지 않고 멈춥니다.
2. 설치할 때와 **같은 명령**을 PowerShell에서 다시 실행합니다.

```
irm https://raw.githubusercontent.com/dkssud9999/math-TD/main/install.ps1 | iex
```

3. 바탕화면의 「LIMIT BREAK」로 실행합니다.

업데이트가 저장 기록을 지키는 방식:

- 진행 기록과 직접 짠 알고리즘(.py)은 게임 파일과 다른 곳에 있습니다: `%APPDATA%\Godot\app_userdata\Limit Break`. 업데이트는 이 폴더를 건드리지 않습니다.
- 그래도 업데이트 직전에 이 폴더 전체를 `%APPDATA%\Godot\app_userdata\Limit Break Backups\날짜-시각\`에 자동으로 백업합니다 (최근 5개 보관). 백업을 못 만들면 업데이트하지 않습니다.
- 새 파일을 끝까지 받고 확인한 뒤에만 기존 설치를 바꿉니다. 중간에 실패하면 기존 설치가 그대로 남습니다.
- 게임도 저장할 때마다 직전 저장을 `.bak`으로 남기고, 저장 파일이 깨져 있으면 그것을 대신 불러옵니다.

**백업에서 되돌리기:** 게임을 닫고, `Limit Break Backups\날짜-시각\` 안의 파일들을 `Limit Break\` 폴더에 덮어쓰면 됩니다.

ZIP으로 직접 설치했다면: 새 ZIP의 파일로 기존 폴더의 LimitBreak.exe / LimitBreak.pck를 바꾸면 됩니다. 저장 기록은 그대로입니다.

## 실행 (소스에서)

Godot 4.7에서 이 폴더를 열고 **F5**. 또는:

```
Godot_v4.7.2-stable_win64.exe --path .
```

## 규칙

- 적의 체력은 그 숫자 자체입니다. 0이 되면 사라집니다.
- 코어에 닿으면 자릿수만큼 코어 체력이 깎입니다 (7은 1, 100은 3).
- 스테이지를 **처음 깨면** 통찰을 얻습니다 (일반·하드 각각 한 번, 하드가 더 많이). 진 판에는 통찰이 없습니다. 메뉴의 연구실에서 통찰로 새 연산을 여세요.
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
| E | 알고리즘 편집기: 선택한 타워의 공격 알고리즘(.py)을 직접 짭니다 (게임 후반, 열리면 안내가 나옵니다) |
| F1 (편집기 안) | 가이드: 진행에 맞춰 한 장씩 열리는 튜토리얼과 찾기 |
| 적에 마우스 | 식 · 소멸자 · 피해 · 지금 배치로 통과할 때의 예측 |
| P | 일시정지 |
| 우클릭 / Esc | 취소 |

상단 바에서 배속(1× · 2× · 3×)과 소리(켬 · 음악 끔 · 끔)를 바꿀 수 있습니다.

## 알고리즘을 외부 편집기로 짜기 (VS Code 등)

알고리즘 파일은 진짜 `.py` 파일이라 좋아하는 편집기로 고칠 수 있습니다.

1. 게임 안 편집기에서 「VS Code로 열기」를 누릅니다. VS Code가 없으면 폴더가 열립니다.
2. 편집기에서 **폴더째** 엽니다 (`%APPDATA%\Godot\app_userdata\Limit Break\scripts`). 폴더의 `__builtins__.pyi` 덕분에 `enemies`, `attack`, `e.f.derivative()` 같은 이름이 자동완성됩니다 (VS Code는 Python 확장 필요).
3. 저장하면 게임이 0.5초 안에 알아채고 다시 읽습니다. 타워는 다음 공격부터 새 코드를 씁니다.

코드에 버그가 있어도 게임은 멈추지 않습니다. 오류가 난 타워는 고칠 때까지 기본 동작(맨 앞 적)으로 싸우고, 적이 있는데 계속 쉬기만 하면 ⏸ 표시로 알려 줍니다.

---

> **아래는 개발자용입니다. 게임 내용 스포일러가 있습니다.**

## 개발자용

- 인수인계 문서: [HANDOFF.md](HANDOFF.md) (구조, 설계 원칙, 도구, 남은 일)
- 플레이테스트 체크리스트: https://claude.ai/artifact/1d1PAwK5sLK4KgkNRdC5r5

### 테스트

다른 컴퓨터에서 밸런스 테스트를 돌리는 방법(준비, Godot 경로, 결과 읽는 법): [tests/BALANCE_TEST.md](tests/BALANCE_TEST.md)

```
# 수학 계산 검증 (실제 항등식 약 2,880개)
godot --headless --path . --script res://tests/test_expr.gd

# 게임 속 파이썬 인터프리터 검증 (실제 파이썬과 같은 출력인지)
godot --headless --path . --script res://tests/test_py.gd

# 알고리즘의 식 계산 (a.f + b.f == 0, derivative(), at() …)
godot --headless --path . --script res://tests/test_mathapi.gd

# 모드별 난이도 (일반 / 하드+연구 다 함 / 하드+일반 연구)
bash tests/modes.sh 12
STAGES="4-1 4-2" bash tests/modes.sh

# 4장 튜토리얼: 과제를 완성한 플레이어처럼 Σ만 코딩해서 4-1 (답 파일은 tests/algos/tutorial, 배포에서 제외)
godot --headless --fixed-fps 60 --path . res://scenes/main.tscn -- --autotest --stage=4-1 --budget --research=code --algo=merge:res://tests/algos/tutorial/sum.py --ts=1

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

### 새 버전 배포

```
bash build.sh                                   # build/LimitBreak.zip (아이콘 포함)
gh release create v0.7.0 build/LimitBreak.zip   # prerelease로 올리면 설치 프로그램이 못 찾습니다
```

`project.godot`의 `config/name`("Limit Break")은 절대 바꾸지 마세요. 저장 폴더 이름이 바뀌어 모든 플레이어의 기록이 사라진 것처럼 보입니다.
