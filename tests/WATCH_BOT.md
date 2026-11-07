# 봇 플레이를 창으로 띄워 보기

"N장 M 띄워 줘"라는 요청을 받으면, 테스트 봇이 그 스테이지를 **창을 띄워** 플레이하게 합니다. 사람은 화면을 보고 봇이 정말 못하는지, 스테이지가 정말 어려운지 판단합니다.

## 띄우는 법

저장소 루트에서 (Windows는 Git Bash):

```bash
bash tests/watch.sh <스테이지> [모드] [배속]
```

| 요청 예 | 명령 |
|---|---|
| "1장 6 띄워 줘" | `bash tests/watch.sh 1-6` |
| "6-2 하드 띄워 줘" | `bash tests/watch.sh 6-2 HF` |
| "5-3 하드, 일반 연구로 2배속" | `bash tests/watch.sh 5-3 HN 2` |

- 모드를 말하지 않으면 `N`, 배속을 말하지 않으면 `8`입니다.
  - `N`: 일반 모드
  - `HF`: 하드 모드, 하드까지 깨 온 플레이어의 연구
  - `HN`: 하드 모드, 일반만 깬 플레이어의 연구
- 연구는 자동입니다. 그 스테이지를 시작할 때 실제 플레이어가 가졌을 연구를 `tests/sim_insight.gd`가 계산합니다 (`tests/modes.sh`와 같음).
- 창이 닫히면(스테이지 끝) 터미널에 결과가 한 줄 나옵니다: `won=true wave=15 integrity=85`.
- **Claude Code에서 띄울 때는 백그라운드로** (`run_in_background`) 실행하세요. 한 판은 8배속으로 1~2분, 2배속으로 4~6분 걸립니다. 끝나면 알림이 옵니다.
- 여러 개를 동시에 띄워도 됩니다. 단, 로그 파일이 `<스테이지>-<모드>`별이라 같은 스테이지·모드를 동시에 두 번 띄우면 로그가 섞입니다.
- 다른 컴퓨터라면 Godot 경로를 지정하세요: `export GODOT=".../Godot_v4.7.2-stable_win64_console.exe"` (자세한 준비는 [BALANCE_TEST.md](BALANCE_TEST.md)).

## 로그 읽기

`build/watch_logs/<스테이지>-<모드>.log`에 봇의 생각이 남습니다. 판이 끝난 뒤 요약해서 보고하면 좋습니다.

| 줄 | 뜻 |
|---|---|
| `[bot] wave 7: expected damage 15.6 (integrity 94), eff 0.88, short of [...], rho 249 …` | 웨이브 시작 시 봇의 판단. 예상 코어 피해, 모델 효율(실제 누수로 보정), 부족한 연산자, 돈 |
| `[buy] w3 build log2 @0.68 (v=0.11)` | 건설. `@` 뒤는 경로상 위치(0 = 입구, 1 = 코어), `v`는 ρ당 줄어드는 예상 피해 |
| `[buy] w3 up sub→3`, `c1`, `c2` | 강화, 수입 강화 |
| `[save] w4 for build zeno (500ρ, have 230)` | 더 좋은 것을 사려고 돈을 모으는 중 |
| `[buy] w15 x=0 (field damage 18, saves 14)` | 궁극기 x = 0 대입 사용 |
| `[leak] w5 −eˣ (tsum2)` | 코어에 닿은 적: 그때의 식 (원래 적 종류) |
| `[autotest] towers: {...}` | 끝났을 때 지은 타워 |
| `[autotest] algo error: …` | 4장부터 봇이 붙인 공격 알고리즘(`tests/algos/*.py`)의 오류나 쉬는 경고 |

보고 예: 결과, 누수가 몰린 웨이브와 적 종류, 봇이 사거나 모은 것 중 이상한 점.

```bash
grep "leak\]" build/watch_logs/6-2-N.log | awk '{print $NF}' | sort | uniq -c   # 무엇이 샜나
grep "buy\]\|save\]" build/watch_logs/6-2-N.log | head -40                      # 무엇을 샀나
```

## 주의

- **측정 중에는 코드를 고치지 마세요.** 각 판은 시작할 때의 코드를 읽습니다. 다른 곳에서 `tests/modes.sh`가 돌고 있다면 끝날 때까지 기다리세요.
- 봇은 저장 파일을 건드리지 않습니다 (`--autotest`).
- 멈추려면 창을 닫으면 됩니다. 프로세스를 정리할 때는 **`--tag=lbtwatch`가 붙은 Godot만** 끄세요. 에디터로 켜 둔 Godot까지 끄면 안 됩니다.

  ```powershell
  Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'lbtwatch' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
  ```
- 봇 구조는 `scripts/bot.gd` 머리말에 있습니다. 4장부터 타워에 붙는 알고리즘은 `tests/algos/`, 연결은 `scripts/main.gd`의 `_autotest_start()`에 있습니다.
