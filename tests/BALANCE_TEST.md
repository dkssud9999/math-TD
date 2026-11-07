# 밸런스 테스트 하는 법 (다른 컴퓨터에서)

봇이 스테이지를 실제로 플레이해서 난이도를 잽니다. 그래픽 없이(headless) 여러 판을 동시에 돌립니다.
봇은 **저장 파일을 건드리지 않습니다** (`Progress.persist = false`). 내 진행 기록이 있는 컴퓨터에서 돌려도 안전합니다.

## 1. 준비

| 필요한 것 | 비고 |
|---|---|
| 이 저장소 | `git clone https://github.com/dkssud9999/math-TD.git` 후 원하는 브랜치로 (`git checkout beta`) |
| Godot **4.7.2** | 콘솔 버전 실행 파일이 필요합니다 (Windows: `Godot_v4.7.2-stable_win64_console.exe`). 버전이 다르면 결과가 달라질 수 있습니다. |
| bash | Windows는 **Git Bash**. macOS/Linux는 기본 터미널. `timeout`, `xargs`가 있어야 합니다 (Git Bash에 포함). |
| PowerShell (Windows만) | 측정을 중간에 멈출 때 남은 Godot를 정리하는 데 씁니다. |

Windows에서 Godot 설치 (한 번만):

```
winget install GodotEngine.GodotEngine --version 4.7.2
```

### Godot 경로 알려 주기

스크립트에 적힌 기본 경로는 원래 개발 컴퓨터의 경로입니다. **다른 컴퓨터에서는 반드시 `GODOT`를 지정하세요.**

```bash
# Git Bash (Windows) 예시 — 실제 위치로 바꾸세요
export GODOT="/c/Users/나/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"

# macOS 예시
export GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
```

경로를 모르겠으면 Git Bash에서: `find /c/Users/$USERNAME/AppData/Local/Microsoft/WinGet -name "Godot_v4.7.2*console.exe"`

### 처음 한 번: 리소스 가져오기

새로 받은 저장소는 Godot가 리소스를 한 번 읽어 들여야 합니다 (1~2분).

```bash
cd math-TD
"$GODOT" --headless --path . --import
```

## 2. 먼저 빠른 검사 (1분)

밸런스 측정 전에 코드가 멀쩡한지 확인합니다. 전부 `failures: 0`이어야 합니다.

```bash
"$GODOT" --headless --path . -s res://tests/test_expr.gd      # 수학 항등식 약 2,880개
"$GODOT" --headless --path . -s res://tests/test_py.gd        # 게임 속 파이썬 (실제 파이썬 출력과 비교)
"$GODOT" --headless --path . -s res://tests/test_mathapi.gd   # 알고리즘의 식 계산 (a.f + b.f == 0 …)
"$GODOT" --headless --path . -s res://tests/test_bounds.gd    # 64비트 한계(2⁶²) 처리
```

## 3. 전체 밸런스 측정

```bash
bash tests/modes.sh 12            # 숫자 = 동시에 돌릴 판 수
```

- **동시 판 수**는 CPU 코어 수보다 조금 적게 잡으세요 (14코어 → 12, 8코어 → 6). 너무 많으면 컴퓨터가 버벅이고 시간 초과가 늘어납니다.
- 1~6장 36스테이지 × 3조건 = 108판. 12개 동시 기준 수십 분 걸립니다.
- 한 판은 최대 900초에서 끊깁니다 (`NO RESULT`로 표시).
- 결과는 모두 끝난 뒤 한꺼번에 출력됩니다. 파일로 남기려면:

```bash
bash tests/modes.sh 12 > 결과.txt 2>&1
```

### 일부 스테이지만

```bash
STAGES="4-1 4-2 6-2" bash tests/modes.sh 6
```

### 결과 읽는 법

```
2-5   N   won=true wave=15 integrity=33
2-5   HF  won=false wave=8 integrity=0
2-5   HN  won=true wave=15 integrity=16
```

| 조건 | 뜻 | 목표 |
|---|---|---|
| `N` | 일반 모드 + 일반으로 살 수 있는 연구 | **이겨야 함** |
| `HF` | 하드 모드 + 그 장의 연구 거의 전부 | 이기되 빠듯하게 |
| `HN` | 하드 모드 + 일반 연구만 | 대체로 져야 함 |

- `integrity` = 끝났을 때 남은 코어 체력. `wave` = 진 웨이브 (이겼으면 15).
- 각 조건의 연구 목록은 `tests/modes.sh` 위쪽 `N1…N6`, `F1…F6`에 있습니다. 새 연구를 추가했다면 여기에도 넣어야 측정에 반영됩니다.
- **반례 스테이지(2-6, 3-6, 4-6, 5-6, 6-6)** 의 하드 패배는 정상일 수 있습니다. 반례를 만나는 것이 진행이기 때문입니다.
- 봇은 한 판의 운에 따라 결과가 흔들립니다. 결과가 이상하면 같은 스테이지를 두세 번 더 돌려 보세요.
- 측정은 2배속(`--ts=2`)으로 합니다. 1배속 결과와 거의 같고 훨씬 빠릅니다.

## 4. 한 판만 자세히 보기

```bash
# 일반 모드, 연구 없음
"$GODOT" --headless --fixed-fps 60 --path . res://scenes/main.tscn -- --autotest --stage=1-3 --budget --research=none --ts=2

# 하드 모드, 연구 지정, 코어에 닿은 적을 전부 출력
"$GODOT" --headless --fixed-fps 60 --path . res://scenes/main.tscn -- --autotest --stage=2-5 --budget --research=sqrt,log2,divx,diff --hard --ts=2 --leaks
```

마지막 줄의 `[autotest] done: … won=… wave=… integrity=… towers=… wall=…초`가 결과입니다.

자주 쓰는 옵션:

| 옵션 | 효과 |
|---|---|
| `--hard` | 하드 모드 |
| `--research=a,b,c` / `all` / `none` | 그 연구를 가진 상태로 시작 |
| `--leaks` | 코어에 닿은 적의 식을 웨이브와 함께 출력 (무엇이 새는지 찾을 때) |
| `--ts=2` | 배속 |
| `--algo=merge:res://tests/algos/tutorial/sum.py` | 그 종류의 타워에 이 알고리즘을 붙임 (4장부터). 이때 `--research`에 `code`를 꼭 넣으세요. 없으면 스크립트가 실행되지 않습니다. |
| `--no-algo` | 4장부터도 봇이 알고리즘을 붙이지 않음 (저주 그대로) |
| `--shot-field=경로.png --shot-wave=6` | 6웨이브 전투 화면 캡처 (**`--headless` 없이** 실행해야 그려짐) |

## 5. 중간에 멈추기

- 측정 창에서 **Ctrl+C**. Windows에서는 스크립트가 자기가 띄운 Godot를 전부 정리합니다.
- macOS/Linux에서 남은 것이 있으면: `pkill -f -- "--autotest"`
- **주의:** 정리할 때 에디터로 켜 둔 Godot까지 끄지 않도록, 테스트용 Godot에는 모두 `--tag=…`가 붙어 있고 그것만 정리합니다. 수동으로 정리할 때도 `--autotest`가 붙은 프로세스만 끄세요.

## 6. 측정하면서 코드를 바꾸지 마세요

각 판은 시작할 때 그 순간의 코드를 읽습니다. 측정 도중에 파일을 고치면 앞쪽 판과 뒤쪽 판이 다른 코드로 돌아 결과가 섞입니다. 고쳤다면 측정을 멈추고 다시 시작하세요.
