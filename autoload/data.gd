extends Node
## Static game data: chapters, stages, maps, operator towers, research tree, enemy templates, UI theme.

const CELL := 40
const COLS := 26
const ROWS := 18
const PLAY_W := 1040
const TOP := 40
const START_RHO := 150
const START_INTEGRITY := 100
const WAVES_PER_STAGE := 15
const MAX_INTEGRATIONS := 3

var font: Font = preload("res://assets/math_font.tres")

# ---------------- maps (grid waypoints; first point is off-screen) ----------------
var MAPS: Array = [
	[Vector2i(-1, 3), Vector2i(4, 3), Vector2i(4, 14), Vector2i(10, 14), Vector2i(10, 4), Vector2i(16, 4), Vector2i(16, 15), Vector2i(21, 15), Vector2i(21, 9), Vector2i(24, 9)],
	[Vector2i(-1, 2), Vector2i(22, 2), Vector2i(22, 6), Vector2i(3, 6), Vector2i(3, 10), Vector2i(22, 10), Vector2i(22, 14), Vector2i(12, 14), Vector2i(12, 16), Vector2i(24, 16)],
	[Vector2i(-1, 9), Vector2i(6, 9), Vector2i(6, 3), Vector2i(20, 3), Vector2i(20, 15), Vector2i(9, 15), Vector2i(9, 7), Vector2i(16, 7), Vector2i(16, 11), Vector2i(13, 11)],
	[Vector2i(-1, 4), Vector2i(12, 4), Vector2i(12, 13), Vector2i(24, 13)],
	[Vector2i(-1, 15), Vector2i(2, 15), Vector2i(2, 2), Vector2i(7, 2), Vector2i(7, 15), Vector2i(12, 15), Vector2i(12, 2), Vector2i(17, 2), Vector2i(17, 15), Vector2i(22, 15), Vector2i(22, 8), Vector2i(24, 8)],
	[Vector2i(-1, 8), Vector2i(8, 8), Vector2i(8, 2), Vector2i(14, 2), Vector2i(14, 16), Vector2i(20, 16), Vector2i(20, 5), Vector2i(24, 5)],
]

# ---------------- chapters & stages ----------------
var CHAPTERS: Dictionary = {
	1: {"name": "1장 · 산술", "sub": "수 방어전", "rho": 150, "integrity": 100,
		"towers": ["zeno", "accel", "sub", "div", "sqrt", "log2"]},
	2: {"name": "2장 · 변화율", "sub": "f(x) = x", "rho": 200, "integrity": 40,
		"towers": ["zeno", "accel", "sub", "div", "divx", "sqrt", "log2", "diff", "int"]},
	3: {"name": "3장 · 로그", "sub": "log eˣ = x", "rho": 320, "integrity": 90,
		"towers": ["zeno", "accel", "sub", "div", "divx", "sqrt", "log2", "diff", "int", "merge"]},
	4: {"name": "4장 · 프로그래밍", "sub": "attack(enemies[0])", "rho": 400, "integrity": 120,
		"towers": ["zeno", "accel", "sub", "div", "divx", "log2", "diff", "int", "merge"]},
	5: {"name": "5장 · 시공간", "sub": "f(x, t)", "rho": 400, "integrity": 70,
		"towers": ["zeno", "accel", "sub", "div", "divx", "log2", "diff", "merge", "dtl", "wave"]},
	6: {"name": "6장 · 연산자 순서", "sub": "eˣ · D · e⁻ˣ = D − 1", "rho": 420, "integrity": 100,
		"towers": ["zeno", "accel", "sub", "div", "divx", "log2", "diff", "merge", "dtl", "damp"]},
	7: {"name": "7장 · 시공간", "sub": "□ = ∂ₜ² − ∂ₓ²", "rho": 380, "integrity": 100,
		"towers": ["zeno", "accel", "sub", "divx", "diff", "int", "dm1", "harm", "merge", "damp", "dtl", "wave"]},
	8: {"name": "8장 · 주파수 영역", "sub": "D ⟷ iω", "rho": 380, "integrity": 100,
		"towers": ["zeno", "accel", "sub", "divx", "diff", "int", "dm1", "harm", "merge", "damp", "lpf"]},
	9: {"name": "9장 · 근사", "sub": "εₙ₊₁ ≈ C · εₙ²", "rho": 340, "integrity": 90,
		"towers": ["zeno", "accel", "sub", "div", "divx", "diff", "dm1", "harm", "merge", "lpf", "newton", "bisect"]},
	10: {"name": "10장 · 공리", "sub": "LIMIT BREAK", "rho": 440, "integrity": 120,
		"towers": ["zeno", "accel", "sub", "diff", "dm1", "harm", "merge", "damp", "dtl", "lpf", "newton", "bisect"]},
}

var STAGE_ORDER: Array = [
	"1-1", "1-2", "1-3", "1-4", "1-5", "1-6",
	"2-1", "2-2", "2-3", "2-4", "2-5", "2-6",
	"3-1", "3-2", "3-3", "3-4", "3-5", "3-6",
	"4-1", "4-2", "4-3", "4-4", "4-5", "4-6",
	"5-1", "5-2", "5-3", "5-4", "5-5", "5-6",
	"6-1", "6-2", "6-3", "6-4", "6-5", "6-6",
	"7-1", "7-2", "7-3", "7-4", "7-5", "7-6",
	"8-1", "8-2", "8-3", "8-4", "8-5", "8-6",
	"9-1", "9-2", "9-3", "9-4", "9-5", "9-6",
	"10-1", "10-2", "10-3", "10-4", "10-5",
]

## Counterexamples: the enemy that ends a chapter. Reaching the core (`need` times) reveals the next theory.
## `count`/`interval` say how many arrive in the final wave.
var COUNTERS: Dictionary = {
	"tsep_counter": {"flag": "met_time", "insight": 50, "sub": "(x³ + eˣ sin 3x + 9) · e²ᵗ",
		"body": "감쇠장을 지나면 eˣ sin 3x는 sin 3x가 됩니다. 그런데 D² + 9는 없습니다.
x에 대한 연산자로는 이 적의 공간 쪽을 끝낼 수 없습니다. 그 사이 e²ᵗ가 위협을 키웁니다.

이 함수는 곱입니다:  g(x) · h(t).
∂ₜ − 2 는 h(t) = e²ᵗ 만 보고, 한 번에 전체를 0으로 보냅니다:  (∂ₜ − 2)(g · e²ᵗ) = g · 0 = 0.

쉬운 인수를 찾으세요. 변수는 x 하나가 아닙니다.

통찰 +50
새 장이 열렸습니다:  7장 · 시공간
연구 「편미분」이 가능해졌습니다."},
	"signal_counter": {"flag": "met_signal", "insight": 55, "sub": "4 sin x + (4/3) sin 3x + (4/5) sin 5x + …",
		"body": "사각파의 푸리에 급수입니다. 진동수가 1, 3, 5, … 15 — 여덟 개.\n짝을 맞춰 하나씩 지우기에는 너무 많습니다. 그리고 진짜 사각파는 무한히 많습니다.\n\n관점을 바꾸면:  e^{iωx}에 D를 걸면 iω가 곱해집니다.  D ⟷ iω.\n미분은 주파수 위의 곱셈입니다. 그렇다면 높은 진동수에 0을 곱할 수도 있습니다.\n\n통찰 +55\n여기까지가 현재 빌드입니다. 7장 · 주파수는 준비 중입니다."},
	"quintic_counter": {"flag": "met_quintic", "insight": 60, "sub": "x⁵ − x − 1 = 0",
		"body": "이것은 함수가 아니라 방정식입니다. 소멸시킬 것이 아니라 '풀어야' 합니다.\n이차식에는 근의 공식이 있습니다. 삼차, 사차에도 있습니다.\n\n아벨–루피니 정리:  일반적인 오차방정식에는 사칙연산과 거듭제곱근으로 된 근의 공식이 없습니다.\nx⁵ − x − 1의 갈루아 군은 S₅, 풀 수 없는 군입니다.\n\n정확함을 포기할 때입니다.  xₙ₊₁ = xₙ − f(xₙ) / f′(xₙ)\n\n통찰 +60\n새 장이 열렸습니다:  9장 · 근사\n연구 「뉴턴 방법」이 가능해졌습니다."},
	"godel_counter": {"flag": "met_godel", "insight": 80, "sub": "G: 「이 적은 이 체계 안에서 처치할 수 없다」",
		"body": "모든 타워가 G를 맞혔습니다. 아무 일도 일어나지 않았습니다.\n\nG가 처치된다면, G의 말은 거짓입니다. 체계는 거짓을 증명한 셈이 됩니다.\nG가 처치되지 않는다면, G의 말은 참입니다. 그런데 체계는 그것을 증명하지 못합니다.\n\n괴델의 불완전성 정리:  충분히 강한 무모순 체계에는 참이지만 증명할 수 없는 문장이 있습니다.\n규칙 안에서는 이길 수 없습니다.\n\n그렇다면 규칙을 바꾸세요.\n\n통찰 +80\n새 장이 열렸습니다:  10장 · 공리\n연구실에서 공리를 고를 수 있습니다."},
	"swarm_counter": {"flag": "met_swarm", "insight": 40, "need": 10, "count": 120, "interval": 0.1, "sub": "L(f + g) = Lf + Lg",
		"body": "하나하나는 D와 D² + 1 한 방씩이면 사라집니다. 하지만 수가 너무 많습니다.\n타워는 한 번에 하나의 함수에만 연산을 겁니다.\n\n그런데 모든 연산자는 선형입니다:  L(f + g) = L f + L g.\n같은 소멸자를 가진 함수들은 더해도 소멸자가 늘지 않습니다.\n3 sin x + 3 백 개를 더하면 300 sin x + 300.  소멸자는 여전히 D(D² + 1)입니다.\n\n통찰 +40\n새 장이 열렸습니다:  5장 · 선형대수\n연구 「선형성 Σ」가 가능해졌습니다."},
	"exsin_counter": {"flag": "met_exp2", "insight": 45, "sub": "f = eˣ sin x",
		"body": "시간이 없는 적입니다. ∂ₜ는 아무것도 못 합니다.\n로그는 sin을 못 넘고, D와 Σ로는 f″ − 2f′ + 2f = 0을 만들 수 없습니다.\n\n하지만 eˣ를 벗겨 낼 수 있다면:  e⁻ˣ · eˣ sin x = sin x.\n그다음은 4장의 일입니다.\n\n단, 곱하기와 미분은 순서를 바꾸면 결과가 달라집니다:  [D, e⁻ˣ] = −e⁻ˣ.\n이제부터 타워를 놓는 순서가 곧 계산의 순서입니다.\n\n통찰 +45\n새 장이 열렸습니다:  6장 · 연산자 순서\n연구 「켤레 공식」(감쇠장)이 가능해졌습니다."},
	"exp2_counter": {"flag": "met_exp2", "insight": 45, "sub": "D e²ˣ = 2e²ˣ",
		"body": "D는 2배로 키우고, D − 1은 그대로 두고, D² + 1은 5배로 키웁니다.\n가진 연산자 중 고윳값 2를 빼는 것은 없습니다.\n\n그런데 연산자 사이에 다른 연산자를 끼우면 새 연산자가 생깁니다.\n켤레 공식:  eˣ · D · e⁻ˣ = D − 1.\ne⁻ˣ를 곱하면 모든 고윳값이 1씩 내려갑니다:  e²ˣ → eˣ → 1.\n\n하지만 e⁻ˣ와 D는 교환되지 않습니다:  [D, e⁻ˣ] = −e⁻ˣ.\n이제부터 타워를 놓는 순서가 곧 곱셈의 순서입니다.\n\n통찰 +45\n새 장이 열렸습니다:  6장 · 연산자 대수\n연구 「켤레 공식」이 가능해졌습니다."},
	"x_counter": {"flag": "met_x", "extra_flag": "fake_ending", "insight": 25, "sub": "f(x) = x",
		"body": "빼기는 상수항만 깎습니다. x에는 상수항이 없습니다.\n나누기는 나누어떨어질 때만 작동합니다. x의 계수는 1입니다.\n\n지금까지 당신은 '값'을 다뤘습니다.\n이것은 값이 아니라, 자리에 따라 '변하는 것'입니다.\n\n통찰 +25\n새 장이 열렸습니다:  2장 · 변화율\n연구 「x로 나누기」가 가능해졌습니다. 그 너머에는 「미분」이 있습니다."},
	"exp_counter": {"flag": "met_exp", "insight": 30, "sub": "D eˣ = eˣ",
		"body": "미분은 xⁿ의 차수를 하나씩 깎습니다. 그런데 eˣ는 미분해도 자기 자신입니다.\n적분해도 eˣ − 1. 다시 미분하면 eˣ.\n\n지수를 깎을 수 없다면, 지수를 끌어내리면 됩니다.\n1장의 log₂는 2ⁿ → n이었습니다. 같은 일을 e에 대해 하면:  log eˣ = x.\n\n통찰 +30\n새 장이 열렸습니다:  3장 · 로그\n연구 「자연로그」가 가능해졌습니다."},
	"sin_counter": {"flag": "met_sin", "insight": 35, "sub": "sin x → cos x → −sin x → −cos x → sin x",
		"body": "D를 쏘면 sin은 cos이 되고, 네 번 쏘면 제자리로 돌아옵니다. 로그는 듣지 않습니다.\n하나의 타워로는 끝이 없습니다.\n\n하지만 두 번 미분한 sin x는 −sin x입니다. 그리고 sin x + (−sin x) = 0.\n한 적을 미분하고, 다른 적과 더한다. 타워들이 손을 맞춰야 합니다.\n\n그리고 하나 더. 지금까지 타워는 '쓸모 있는 적'만 골라 쐈습니다.\n그건 연산자가 아니라 신탁(oracle)이었습니다. 이제부터 타워는 그냥 맨 앞의 함수를 칩니다.\n누구를 칠지는 당신이 코드로 정합니다: 타워를 선택하고 [E].\n\n통찰 +35\n새 장이 열렸습니다:  4장 · 프로그래밍"},
	"tx_counter": {"flag": "met_time", "insight": 40, "sub": "f(x, t) = eˣ sin x · eᵗ",
		"body": "이 적에는 x만 있는 게 아닙니다. 필드에 머문 시간 t가 들어 있고, 오래 둘수록 eᵗ배로 커집니다.\nD와 Σ로 eˣ sin x를 지우려면 f″ − 2f′ + 2f = 0: 두 배와 빼기가 섞인 결합이 필요합니다.\n가진 타워로는 그 결합을 만들 수 없습니다.\n\n그런데 이 함수는 시간 쪽으로 보면 단순합니다: g(x) · eᵗ.\n시간으로 미분하면 자기 자신. 2장의 eˣ와 같은 모양입니다.\n\n통찰 +40\n새 장이 열렸습니다:  5장 · 시공간\n연구 「편미분」(∂ₜ − 1)이 가능해졌습니다."},
}

# mix entries: [template, weight, first_wave]
var STAGES: Dictionary = {
	"1-1": {"chapter": 1, "name": "자연수", "map": 0, "x_end": 3.0, "base": 9, "growth": 1.3, "interval": [1.0, 0.55],
		"desc": "적의 체력은 그 숫자 자체입니다. 0으로 만들면 사라집니다. 코어에 닿으면 자릿수만큼 무결성을 깎습니다 (7은 1, 100은 3).",
		"mix": [["n1", 1, 1], ["n2", 1, 6]], "boss": [["n100", 2]]},
	"1-2": {"chapter": 1, "name": "짝수와 홀수", "map": 1, "x_end": 3.0, "base": 10, "growth": 1.3, "interval": [0.95, 0.5],
		"desc": "나누기는 나누어떨어지는 수만 절반으로 만듭니다. 짝수는 나누고, 홀수는 빼세요. 1000 = 2³ · 125.",
		"mix": [["n1", 1, 1], ["n2", 1, 1], ["even", 1, 4]], "boss": [["k1000", 2]]},
	"1-3": {"chapter": 1, "name": "완전제곱수", "map": 2, "x_end": 3.0, "base": 9, "growth": 1.1, "interval": [0.9, 0.5],
		"desc": "10000 = 100². 제곱근을 연구하면 완전제곱수를 단번에 줄일 수 있습니다. √7은 무리수라 정확히 다룰 수 없습니다.",
		"mix": [["n2", 1, 1], ["sq", 2, 1], ["even", 1, 6]], "boss": [["k10000", 2]]},
	"1-4": {"chapter": 1, "name": "2의 거듭제곱", "map": 3, "x_end": 3.0, "base": 8, "growth": 0.85, "interval": [0.9, 0.5],
		"desc": "65536 = 2¹⁶. 이진 로그는 2의 거듭제곱에만 정확합니다. 경로가 짧습니다.",
		"mix": [["p2", 2, 1], ["sq", 1, 3], ["n2", 1, 1]], "boss": [["k65536", 2]]},
	"1-5": {"chapter": 1, "name": "소수", "map": 4, "x_end": 3.0, "base": 9, "growth": 0.85, "interval": [0.85, 0.45],
		"desc": "소수는 제곱수도, 2의 거듭제곱도 아닙니다. 빠르고, 지름길이 없습니다.",
		"mix": [["prime", 2, 1], ["n2", 1, 1], ["sq", 1, 5], ["p2", 1, 8]], "boss": [["bigprime", 3]]},
	"1-6": {"chapter": 1, "name": "큰 수", "map": 5, "x_end": 3.0, "base": 9, "growth": 0.9, "interval": [0.85, 0.45],
		"desc": "지금까지 배운 모든 것. 마지막 스테이지입니다.",
		"mix": [["n2", 1, 1], ["sq", 1, 1], ["p2", 1, 1], ["prime", 1, 3], ["even", 1, 5], ["big", 1, 4]], "boss": [["k10_6", 1], ["k2_32", 1]]},
	"2-1": {"chapter": 2, "name": "변수", "map": 0, "x_end": 2.0, "flag": "fake_ending", "base": 8, "growth": 0.9, "interval": [1.0, 0.55],
		"desc": "f(x) = x. 경로가 곧 x축입니다. 코어는 x = 2(2장이니까)에 있습니다. 적이 닿으면 f(2)의 자릿수만큼 무결성이 깎입니다. x ÷ x = 1, 그리고 1 − 1 = 0.",
		"mix": [["x", 2, 1], ["n1", 1, 1], ["xc", 1, 3], ["lin", 1, 5], ["quad", 1, 9], ["cubic", 1, 12]], "boss": [["boss_x4", 2]]},
	"2-2": {"chapter": 2, "name": "공통인수", "map": 1, "x_end": 2.0, "base": 5, "growth": 0.8, "interval": [1.15, 0.65],
		"desc": "2x + 4 = 2(x + 2). 나누기 ÷2로 공통인수를 걷어내고, 빼기로 상수를, ÷x로 x를. 미분은 아직 없습니다.",
		"mix": [["kx", 2, 1], ["xc", 1, 1], ["xbx", 1, 3], ["n1", 1, 1], ["kxx", 1, 6]], "boss": [["boss_alg2", 2]]},
	"2-3": {"chapter": 2, "name": "물량", "map": 2, "x_end": 2.0, "base": 5, "growth": 0.6, "interval": [1.15, 0.65],
		"desc": "많고 다양합니다. 상수는 빼기로, 공통인수는 ÷2로, x는 ÷x로. 어떤 순서로 경로에 늘어놓을지가 전부입니다.",
		"mix": [["xc", 2, 1], ["n1", 1, 1], ["kx", 1, 2], ["xbx", 1, 5], ["sqp", 1, 9]], "boss": [["boss_alg2", 2]]},
	"2-4": {"chapter": 2, "name": "완전제곱", "map": 2, "x_end": 2.0, "base": 5, "growth": 0.85, "interval": [1.2, 0.65],
		"desc": "(x + 3)² = x² + 6x + 9. 「완전제곱식」을 연구하면 √가 다항식에도 정확히 작동합니다. 이 스테이지를 깨면 「미분」이 열립니다.",
		"mix": [["sqp", 2, 1], ["xbx", 1, 1], ["x4", 1, 3], ["sq2", 1, 6], ["kxx", 1, 4]], "boss": [["boss_sq", 2]]},
	"2-5": {"chapter": 2, "name": "변화율", "map": 4, "x_end": 2.0, "base": 7, "growth": 1.0, "interval": [0.95, 0.5],
		"desc": "미분: 상수는 한 방에 0, xⁿ은 n+1번. 인수도 완전제곱도 아닌 다항식(x³ + x + 5)은 대수로는 풀리지 않습니다. 그 대신 미분은 비쌉니다.",
		"mix": [["n1", 2, 1], ["xc", 1, 1], ["quad", 1, 2], ["cubic", 1, 5], ["sqp", 1, 3], ["quart", 1, 9]], "boss": [["boss_x6", 2]]},
	"2-6": {"chapter": 2, "name": "멈추지 않는 것", "map": 5, "x_end": 2.0, "base": 5, "growth": 0.65, "interval": [1.2, 0.7],
		"desc": "2장의 마지막 스테이지. 모든 다항식은 유한 번 미분하면 0이 됩니다. 모든 함수가 그럴까요?",
		"mix": [["quad", 1, 1], ["n1", 1, 1], ["cubic", 1, 2], ["quart", 1, 4], ["quint", 1, 6]], "boss": [["boss_x6", 1]], "counter": "exp_counter"},
	"3-1": {"chapter": 3, "name": "자연로그", "map": 0, "x_end": 3.0, "flag": "met_exp", "base": 6, "growth": 1.0, "interval": [1.1, 0.6],
		"desc": "로그 타워가 이제 함수에도 작동합니다: log eˣ = x, log e²ˣ = 2x. 그다음은 2장에서 하던 대로 ÷x와 빼기. 계수가 붙은 3eˣ도 되지만 세 배 오래 걸립니다. 먼저 ÷3을 할 수 있다면?",
		"mix": [["ex", 2, 1], ["exs", 1, 1], ["n1", 1, 1], ["e2x", 1, 5], ["exc", 1, 8]], "boss": [["boss_ex1", 2]]},
	"3-2": {"chapter": 3, "name": "순서", "map": 1, "x_end": 3.0, "base": 5, "growth": 0.9, "interval": [1.0, 0.55],
		"desc": "eˣ + 4에는 로그가 듣지 않습니다. 상수부터 떼야 합니다. xeˣ도 그대로는 안 됩니다: ÷x가 먼저. 어떤 타워를 앞에 둘지가 곧 풀이 순서입니다.",
		"mix": [["exc", 2, 1], ["xex", 1, 1], ["ex", 1, 1], ["lin", 1, 4], ["e2x", 1, 7]], "boss": [["boss_chain", 2]]},
	"3-3": {"chapter": 3, "name": "섞인 몸", "map": 2, "x_end": 3.0, "base": 6, "growth": 1.05, "interval": [1.0, 0.6],
		"desc": "x + eˣ는 로그도 ÷x도 안 됩니다. D를 두 번 쏘면 다항식 쪽이 먼저 사라집니다: x + eˣ → 1 + eˣ → eˣ.",
		"mix": [["xpe", 2, 1], ["pex", 1, 1], ["exc", 1, 3], ["quad", 1, 5], ["xex", 1, 9]], "boss": [["mix3b", 2]]},
	"3-4": {"chapter": 3, "name": "선형결합", "map": 4, "x_end": 3.0, "base": 7, "growth": 0.9, "interval": [0.7, 0.35],
		"desc": "Σ 타워는 범위 안의 함수들을 하나로 더합니다. eˣ 여섯이 6eˣ 하나가 되고, ÷2 ÷3이면 다시 eˣ. 3eˣ와 −3eˣ는 더하는 순간 0입니다.",
		"mix": [["ex", 3, 1], ["pm_ex", 1, 1], ["exs", 1, 3], ["n1", 1, 1], ["xex", 1, 8]], "boss": [["boss_ex1", 2]]},
	"3-5": {"chapter": 3, "name": "대군", "map": 3, "x_end": 3.0, "base": 5, "growth": 0.7, "interval": [0.85, 0.45],
		"desc": "많고 빠릅니다. 하나씩 풀면 늦습니다. 합칠 것인가, 나눠 풀 것인가.",
		"mix": [["ex", 3, 1], ["exc", 1, 1], ["pm_ex", 1, 3], ["xpe", 1, 5], ["e2x", 1, 9]], "boss": [["boss_chain", 2]]},
	"3-6": {"chapter": 3, "name": "순환", "map": 5, "x_end": 3.0, "base": 7, "growth": 1.0, "interval": [0.9, 0.45],
		"desc": "3장의 마지막 스테이지. 다항식은 미분으로, 지수는 로그로. 이제 못 푸는 함수가 있을까요?",
		"mix": [["xpe", 1, 1], ["exc", 1, 1], ["xex", 1, 3], ["exs", 1, 6], ["e2x", 1, 9]], "boss": [["boss_chain", 1]], "counter": "sin_counter"},
	"4-1": {"chapter": 4, "name": "코딩 입문", "map": 0, "x_end": 4.0, "flag": "met_sin", "integrity": 150, "base": 4, "growth": 0.6, "interval": [1.8, 1.0],
		"desc": "sin x는 D를 두 번 맞으면 −sin x가 됩니다. sin x와 −sin x를 Σ로 더하면 0. 혼자서는 못 하고, 타워 둘이 손을 맞춰야 합니다.\n\n따라 해 보세요 (적이 적고 느린 연습 스테이지입니다):\n1. D 타워 하나와 Σ 타워 하나를 짓고, D 타워를 선택한 뒤 E.\n2. 편집기 「가이드」를 1번부터 읽고, 5번 예시(D용)를 새 파일로 열어 D 타워에 붙이기.\n3. 6번 예시(Σ용)를 Σ 타워에 붙이기. 「테스트 실행」으로 확인.\n4. Esc로 돌아와 웨이브 시작. 타워 위 </> 표시가 알고리즘이 돌고 있다는 뜻입니다.",
		"mix": [["s1", 2, 1], ["n1", 1, 1], ["ex", 1, 3]], "boss": [["boss_sc", 2]]},
	"4-2": {"chapter": 4, "name": "위상", "map": 1, "x_end": 4.0, "base": 5, "growth": 0.95, "interval": [1.2, 0.65],
		"desc": "cos x에 D를 한 번 쏘면 −sin x. 옆에 sin x가 있다면 그걸로 충분합니다. 누가 누구의 짝인지 읽는 코드가 필요합니다.",
		"mix": [["s1", 2, 1], ["c1", 2, 1], ["s1c", 1, 4], ["exc", 1, 7]], "boss": [["boss_sc", 2]]},
	"4-3": {"chapter": 4, "name": "생성", "map": 2, "x_end": 4.0, "base": 5, "growth": 0.9, "interval": [1.2, 0.65],
		"desc": "생성하는 적은 몇 초마다 자기 도함수를 낳습니다: sin → cos → −sin → … 부모와 자손이 서로의 짝입니다.",
		"mix": [["gen_sin", 1, 1], ["s1", 2, 1], ["c1", 1, 3], ["xpe", 1, 6]], "boss": [["boss_sc", 2]]},
	"4-4": {"chapter": 4, "name": "진동수", "map": 3, "x_end": 4.0, "integrity": 220, "base": 4, "growth": 0.7, "interval": [1.4, 0.8],
		"desc": "sin 2x를 두 번 미분하면 −4 sin 2x. 짝이 되려면 크기를 맞춰야 합니다: ÷2를 두 번.",
		"mix": [["s2", 2, 1], ["s1", 1, 1], ["c2", 1, 4], ["exs", 1, 7]], "boss": [["boss_s2", 2]]},
	"4-5": {"chapter": 4, "name": "혼성", "map": 4, "x_end": 4.0, "base": 5, "growth": 0.85, "interval": [1.1, 0.6],
		"desc": "sin x + eˣ. 로그는 덧셈을 못 넘고, D는 sin을 돌릴 뿐입니다. 다른 적의 −sin x를 더해 sin을 떼어 내면 eˣ만 남습니다.",
		"mix": [["tse", 2, 1], ["s1", 2, 1], ["c1", 1, 3], ["xpe", 1, 6]], "boss": [["boss_sc", 2]]},
	"4-6": {"chapter": 4, "name": "시간", "map": 5, "x_end": 4.0, "base": 6, "growth": 0.9, "interval": [1.0, 0.5],
		"desc": "4장의 마지막 스테이지. 경로의 변수는 x입니다. 다른 변수는 없을까요?",
		"mix": [["s1", 2, 1], ["c1", 1, 1], ["tse", 1, 4], ["xpe", 1, 8]], "boss": [["boss_sc", 2]], "counter": "tx_counter"},
	"5-1": {"chapter": 5, "name": "곱 분리", "map": 0, "x_end": 5.0, "flag": "met_time", "base": 8, "growth": 1.0, "interval": [1.2, 0.65],
		"desc": "이제 적에는 시간 t가 있습니다: 필드에 오래 머물수록 eᵗ배로 커집니다. 시간 소멸 ∂ₜ − 1은 g(x)·eᵗ를 x 쪽이 무엇이든 통째로 0으로 보냅니다. 대신 t가 없는 적에 쏘면 부호만 뒤집힙니다 (저주 주의).",
		"mix": [["sep1", 2, 1], ["tsin", 1, 1], ["sepx", 1, 3], ["ex", 1, 6]], "boss": [["boss_sep", 2]]},
	"5-2": {"chapter": 5, "name": "성장률", "map": 1, "x_end": 5.0, "base": 8, "growth": 1.1, "interval": [1.2, 0.65],
		"desc": "e²ᵗ는 ∂ₜ − 1로는 안 죽고 −1배만 됩니다. λ를 2로 맞춰야 합니다 [W] 또는 코드의 set_param(2). 적마다 다른 λ를 고르는 코드를 짜 보세요.",
		"mix": [["sep2", 2, 1], ["sep1", 1, 1], ["tsin", 1, 4], ["sepx", 1, 6]], "boss": [["boss_sep2", 2]]},
	"5-3": {"chapter": 5, "name": "변수 분리", "map": 2, "x_end": 5.0, "base": 5, "growth": 0.85, "interval": [1.35, 0.8],
		"desc": "x² + x·eᵗ: 시간 쪽 항과 공간 쪽 항이 더해져 있습니다. ∂ₜ − 1과 D를 어떤 순서로 쏘느냐에 따라 남는 것이 다릅니다.",
		"mix": [["tsum", 2, 1], ["sep1", 1, 1], ["tsum2", 1, 4], ["sep2", 1, 8]], "boss": [["boss_sep", 2]]},
	"5-4": {"chapter": 5, "name": "진행파", "map": 3, "x_end": 5.0, "base": 7, "growth": 1.05, "interval": [1.3, 0.7],
		"desc": "(x − t)²는 시간이 흐르면 모양 그대로 움직이는 파동입니다. ∂ₜ로도 D로도 끝이 안 납니다. 연구 「달랑베르 해」: □ = ∂ₜ² − ∂ₓ²는 모든 진행파를 한 방에.",
		"mix": [["wave2", 2, 1], ["wave3", 1, 3], ["wave_e", 1, 5], ["sep1", 1, 1]], "boss": [["boss_wave", 2]]},
	"5-5": {"chapter": 5, "name": "반대 방향", "map": 4, "x_end": 5.0, "base": 7, "growth": 1.0, "interval": [1.2, 0.65],
		"desc": "(x + t)²는 반대로 가는 파동. □는 양쪽 다 지웁니다. 하지만 □는 비싸고 느립니다: 정말 파동인 적에게만 쓰도록.",
		"mix": [["wave_l", 2, 1], ["wave2", 1, 1], ["wave_mix", 1, 4], ["sep2", 1, 7]], "boss": [["boss_wave", 2]]},
	"5-6": {"chapter": 5, "name": "얽힘", "map": 5, "x_end": 5.0, "base": 8, "growth": 1.0, "interval": [1.2, 0.65],
		"desc": "5장의 마지막 스테이지. 시간을 떼어 내면 남는 건 x의 함수입니다. 그 x의 함수를 늘 지울 수 있을까요?",
		"mix": [["sep1", 1, 1], ["tsin", 1, 1], ["wave2", 1, 4], ["sep2", 1, 7]], "boss": [["boss_sep", 1]], "counter": "exsin_counter"},
	"6-1": {"chapter": 6, "name": "켤레", "map": 4, "x_end": 6.0, "flag": "met_exp2", "base": 6, "growth": 0.8, "interval": [1.4, 0.75],
		"desc": "감쇠장 e⁻ˣ·는 모든 함수에 e⁻ˣ를 곱합니다: eˣ sin x → sin x. 그러면 4장의 D + Σ로 끝낼 수 있습니다. 하지만 저주 아래의 감쇠장은 상수 1도 e⁻ˣ로 바꿉니다. 누구에게 걸지 코드로 정하세요.",
		"mix": [["exsin", 2, 1], ["ex", 1, 1], ["s1", 2, 3], ["e2x", 1, 6]], "boss": [["boss_e2", 2]]},
	"6-2": {"chapter": 6, "name": "교환자", "map": 1, "x_end": 6.0, "base": 5, "growth": 0.7, "interval": [1.3, 0.7],
		"desc": "감쇠장 다음에 D를 쏘는 것과 D 다음에 감쇠장을 쏘는 것은 다릅니다: [D, e⁻ˣ] = −e⁻ˣ. eˣ sin x에 D를 먼저 쏘면 eˣ(sin x + cos x) — 짝 맞추기가 어려워집니다.",
		"mix": [["exsin", 2, 1], ["ex", 1, 1], ["e2x", 1, 3], ["s1", 2, 5]], "boss": [["boss_e2", 2]]},
	"6-3": {"chapter": 6, "name": "이중 감쇠", "map": 2, "x_end": 6.0, "base": 8, "growth": 1.05, "interval": [1.3, 0.7],
		"desc": "e³ˣ와 xe²ˣ. 로그로 끌어내릴 수도, 감쇠장으로 눌러 내릴 수도 있습니다. 로그는 계수만큼 느리고, 감쇠장은 범위 전체에 걸립니다.",
		"mix": [["e2x", 2, 1], ["e3x", 1, 3], ["ex", 1, 1], ["xe2x", 1, 7]], "boss": [["boss_e3", 2]]},
	"6-4": {"chapter": 6, "name": "순서", "map": 5, "x_end": 6.0, "base": 5, "growth": 0.75, "interval": [1.2, 0.65],
		"desc": "e²ˣ + eˣ + c. 덧셈 때문에 로그가 안 됩니다. 감쇠장을 두 번 지나면 1 + e⁻ˣ + ce⁻²ˣ: 코어(x = 6)에서는 e⁻ˣ 쪽이 거의 0입니다.",
		"mix": [["e2c", 2, 1], ["exsin", 1, 1], ["xe2x", 1, 4], ["e2x", 1, 1], ["e3x", 1, 9]], "boss": [["boss_e3", 2]]},
	"6-5": {"chapter": 6, "name": "감쇠 전략", "map": 4, "x_end": 6.0, "base": 8, "growth": 1.0, "interval": [0.9, 0.45],
		"desc": "죽이지 않아도 됩니다. 감쇠장을 거듭 지난 함수는 c·e⁻ᵏˣ — 코어에서 0.5보다 작으면 무해합니다. 대신 처치 보상은 없습니다.",
		"mix": [["e2x", 2, 1], ["ex", 1, 1], ["e2c", 1, 3], ["e3x", 1, 7]], "boss": [["boss_e2", 2]]},
	"6-6": {"chapter": 6, "name": "신호", "map": 5, "x_end": 6.0, "base": 6, "growth": 0.8, "interval": [1.2, 0.7],
		"desc": "6장의 마지막 스테이지.",
		"mix": [["e2c", 1, 1], ["exsin", 1, 1], ["xe2x", 1, 4], ["s1", 2, 6]], "boss": [["boss_e3", 1]], "counter": "signal_counter"},
	"7-1": {"chapter": 7, "name": "곱 분리", "map": 0, "x_end": 7.0, "flag": "met_old_ch7", "base": 7, "growth": 0.9, "interval": [1.1, 0.6],
		"desc": "t는 적이 전장에 머문 시간입니다. g(x)·eᵗ는 오래 살수록 커집니다. (∂ₜ − 1)은 eᵗ 인수 하나로 전체를 지웁니다. 시간과 무관한 함수에는 −1배.",
		"mix": [["sep1", 2, 1], ["quad", 1, 1], ["sepx", 1, 3], ["ex", 1, 6]], "boss": [["boss_sep", 2]]},
	"7-2": {"chapter": 7, "name": "성장률", "map": 1, "x_end": 7.0, "base": 7, "growth": 0.9, "interval": [1.1, 0.6],
		"desc": "e²ᵗ 인수에는 ∂ₜ − 2. 연구 「성장률」로 λ를 1 ↔ 2로 바꿀 수 있습니다 [W]. λ가 틀리면 (γ − λ)배.",
		"mix": [["sep2", 2, 1], ["sep1", 1, 1], ["sepx", 1, 4], ["cubic", 1, 6]], "boss": [["boss_sep2", 2]]},
	"7-3": {"chapter": 7, "name": "변수 분리", "map": 2, "x_end": 7.0, "base": 4, "growth": 0.7, "interval": [1.35, 0.8],
		"desc": "x² + x·eᵗ는 곱이 아니라 합입니다. ∂ₓ는 시간만의 항을 지우고, ∂ₜ − λ는 공간만의 항에 −λ를 곱합니다. 쉬운 쪽부터.",
		"mix": [["tsum", 2, 1], ["sep1", 1, 1], ["tsum2", 1, 4], ["sep2", 1, 8]], "boss": [["boss_sep", 2]]},
	"7-4": {"chapter": 7, "name": "진행파", "map": 3, "x_end": 7.0, "base": 6, "growth": 0.85, "interval": [1.3, 0.7],
		"desc": "(x − t)³는 모양을 유지하며 움직이는 파동입니다. 달랑베르: □ = ∂ₜ² − ∂ₓ²은 모든 g(x − t) + h(x + t)를 0으로 보냅니다.",
		"mix": [["wave2", 2, 1], ["wave3", 1, 3], ["wave_e", 1, 5], ["sep1", 1, 1]], "boss": [["boss_wave", 2]]},
	"7-5": {"chapter": 7, "name": "반대 방향", "map": 4, "x_end": 7.0, "base": 7, "growth": 0.9, "interval": [1.1, 0.6],
		"desc": "(x + t)²와 e^{x−t}는 서로 반대로 달립니다. □는 둘 다 지웁니다. □가 지우지 못하는 나머지는 다른 연산자로.",
		"mix": [["wave_l", 2, 1], ["wave2", 1, 1], ["wave_mix", 1, 4], ["sep2", 1, 7]], "boss": [["boss_wave", 2]]},
	"7-6": {"chapter": 7, "name": "신호", "map": 5, "x_end": 7.0, "base": 5, "growth": 0.75, "interval": [1.2, 0.7],
		"desc": "7장의 마지막 스테이지. 모든 연산자는 한 번에 한 가지 모드를 다룹니다. 모드가 무한히 많다면?",
		"mix": [["sep1", 1, 1], ["wave2", 1, 1], ["sig2", 1, 4], ["wave_mix", 1, 7]], "boss": [["boss_wave", 1]], "counter": "signal_counter"},
	"8-1": {"chapter": 8, "name": "스펙트럼", "map": 0, "x_end": 8.0, "flag": "met_signal", "base": 5, "growth": 0.8, "interval": [1.25, 0.7],
		"desc": "전장이 주파수 영역으로 바뀌었습니다. 적은 이제 스펙트럼입니다: 막대 하나가 진동수 하나. 저역 통과 필터는 컷오프보다 높은 막대를 전부 0으로 곱합니다.",
		"mix": [["sig2", 2, 1], ["sin", 1, 1], ["sig3", 1, 4], ["acs", 1, 6]], "boss": [["boss_sig", 2]]},
	"8-2": {"chapter": 8, "name": "저역 통과", "map": 1, "x_end": 8.0, "base": 7, "growth": 0.9, "interval": [1.1, 0.6],
		"desc": "LPF는 낮은 진동수와 다항식, 지수를 그대로 둡니다. 필터 뒤에 남는 것은 지금까지의 연산자로.",
		"mix": [["sigp", 2, 1], ["sig2", 1, 1], ["sige", 1, 4], ["sig3", 1, 7]], "boss": [["boss_sig", 2]]},
	"8-3": {"chapter": 8, "name": "사각파", "map": 2, "x_end": 8.0, "base": 5, "growth": 0.75, "interval": [1.3, 0.75],
		"desc": "4/π · Σ sin(nx)/n, n 홀수. 기본파 4 sin x 하나만 남기고 나머지를 필터로 지우세요.",
		"mix": [["square", 2, 1], ["sig2", 1, 1], ["sig3", 1, 5]], "boss": [["boss_square", 2]]},
	"8-4": {"chapter": 8, "name": "톱니파", "map": 3, "x_end": 8.0, "base": 4, "growth": 0.7, "interval": [1.35, 0.8],
		"desc": "2 Σ (−1)ⁿ⁺¹ sin(nx)/n. 짝수 진동수도 섞여 있습니다. 컷오프를 1까지 내리려면 필터를 강화하세요.",
		"mix": [["saw", 2, 1], ["square", 1, 3], ["sigp", 1, 1]], "boss": [["boss_square", 2]]},
	"8-5": {"chapter": 8, "name": "변조", "map": 4, "x_end": 8.0, "base": 7, "growth": 0.9, "interval": [1.1, 0.6],
		"desc": "eˣ sin 5x는 진동수 5로 떨리는 지수입니다. 필터는 진동수만 봅니다: 성장률과 상관없이 통째로 지웁니다.",
		"mix": [["mod5", 2, 1], ["sige", 1, 1], ["saw", 1, 4], ["exsin", 1, 7]], "boss": [["boss_sig", 2]]},
	"8-6": {"chapter": 8, "name": "방정식", "map": 5, "x_end": 8.0, "base": 4, "growth": 0.65, "interval": [1.3, 0.8],
		"desc": "8장의 마지막 스테이지. 지금까지 적은 모두 함수였습니다.",
		"mix": [["square", 1, 1], ["sigp", 1, 1], ["mod5", 1, 4], ["saw", 1, 7]], "boss": [["boss_square", 1]], "counter": "quintic_counter"},
	"9-1": {"chapter": 9, "name": "뉴턴", "map": 0, "x_end": 9.0, "flag": "met_quintic", "base": 6, "growth": 0.85, "interval": [1.2, 0.7],
		"desc": "방정식 적은 p(x) = 0과 추정값 x₀를 가집니다. |p(xₙ)| < 10⁻⁶이 되면 풀립니다. 뉴턴 방법은 맞을 때마다 맞는 자릿수가 대략 두 배가 됩니다.",
		"mix": [["root_q", 2, 1], ["root_c", 1, 3], ["n1", 1, 1], ["quad", 1, 5]], "boss": [["root_5", 2]]},
	"9-2": {"chapter": 9, "name": "이분법", "map": 1, "x_end": 9.0, "base": 6, "growth": 0.85, "interval": [1.2, 0.7],
		"desc": "x³ − 2x + 2에 x₀ = 0에서 뉴턴을 쓰면 0 → 1 → 0 → 1 … 영원히 순환합니다. 이분법은 느리지만(한 번에 오차 절반) 절대 실패하지 않습니다.",
		"mix": [["root_cyc", 2, 1], ["root_q", 1, 1], ["root_c", 1, 4]], "boss": [["root_5", 2]]},
	"9-3": {"chapter": 9, "name": "초월방정식", "map": 2, "x_end": 9.0, "base": 6, "growth": 0.85, "interval": [1.2, 0.7],
		"desc": "cos x = x에는 대수적인 해가 없습니다. 근은 0.739085… (도티 수). 뉴턴은 상관하지 않습니다.",
		"mix": [["root_cos", 2, 1], ["root_ex", 1, 3], ["root_q", 1, 1], ["sin", 1, 6]], "boss": [["root_5", 2]]},
	"9-4": {"chapter": 9, "name": "혼합", "map": 2, "x_end": 9.0, "base": 6, "growth": 0.85, "interval": [1.3, 0.7],
		"desc": "방정식과 함수가 함께. 방정식에는 근사를, 함수에는 소멸자를.",
		"mix": [["root_c", 1, 1], ["root_cyc", 1, 1], ["mix3", 1, 3], ["acs", 1, 3], ["root_cos", 1, 7]], "boss": [["root_5", 2]]},
	"9-5": {"chapter": 9, "name": "수렴 속도", "map": 4, "x_end": 9.0, "base": 9, "growth": 1.0, "interval": [0.9, 0.5],
		"desc": "이분법은 선형 수렴(εₙ₊₁ = εₙ/2), 뉴턴은 이차 수렴(εₙ₊₁ ≈ C·εₙ²). 물량이 많을수록 차이가 커집니다.",
		"mix": [["root_q", 2, 1], ["root_c", 1, 1], ["root_ex", 1, 4], ["root_cyc", 1, 6]], "boss": [["root_5", 3]]},
	"9-6": {"chapter": 9, "name": "자기 언급", "map": 5, "x_end": 9.0, "base": 4, "growth": 0.65, "interval": [1.3, 0.8],
		"desc": "9장의 마지막 스테이지. 정확한 방법이든 근사든, 결국 모든 것은 계산할 수 있지 않을까요?",
		"mix": [["root_c", 1, 1], ["root_cos", 1, 1], ["mix3", 1, 3], ["root_5", 1, 8]], "boss": [["root_5", 1]], "counter": "godel_counter"},
	"10-1": {"chapter": 10, "name": "새 공리", "map": 0, "x_end": 10.0, "flag": "met_godel", "base": 7, "growth": 0.9, "interval": [1.1, 0.6],
		"desc": "G는 이 체계 안에서 증명할 수 없습니다. 그러니 G를 공리로 받아들이세요. 연구실에서 공리를 최대 3개까지 켤 수 있습니다.",
		"mix": [["godel", 1, 1], ["quad", 1, 1], ["ex", 1, 1], ["godel", 1, 6]], "boss": [["godel", 3]]},
	"10-2": {"chapter": 10, "name": "선택", "map": 1, "x_end": 10.0, "base": 11, "growth": 1.2, "interval": [0.55, 0.25],
		"desc": "무한히 많은 집합에서 하나씩 고를 수 있는가? 선택공리를 받아들이면 Σ는 범위 안의 모든 것을 한 번에 합칩니다.",
		"mix": [["ex", 2, 1], ["sin", 1, 1], ["n1", 1, 1], ["godel", 1, 8]], "boss": [["boss_hy", 2]]},
	"10-3": {"chapter": 10, "name": "무한소", "map": 2, "x_end": 10.0, "base": 6, "growth": 0.8, "interval": [1.15, 0.65],
		"desc": "비표준 해석: 0이 아니지만 어떤 양수보다도 작은 수. 무한소 공리를 켜면 코어에서 1보다 작은 함수는 맞는 순간 0과 같습니다.",
		"mix": [["e2x", 1, 1], ["sep1", 1, 1], ["root_q", 1, 3], ["square", 1, 5], ["godel", 1, 9]], "boss": [["boss_e3", 2]]},
	"10-4": {"chapter": 10, "name": "귀납", "map": 2, "x_end": 10.0, "base": 8, "growth": 0.9, "interval": [1.0, 0.55],
		"desc": "P(1)이고, P(n)이면 P(n+1). 수학적 귀납법 공리를 켜면 한 함수가 0이 될 때 똑같은 함수가 전부 함께 0이 됩니다.",
		"mix": [["exs", 2, 1], ["sin", 1, 1], ["xex", 1, 3], ["wave2", 1, 6], ["godel", 1, 10]], "boss": [["boss_ex", 2]]},
	"10-5": {"chapter": 10, "name": "LIMIT BREAK", "map": 5, "x_end": 10.0, "base": 5, "growth": 0.75, "interval": [1.2, 0.7],
		"desc": "마지막 스테이지. 수, 함수, 시간, 신호, 방정식, 그리고 증명할 수 없는 것. 당신이 고른 공리 위에서.",
		"mix": [["ex", 1, 1], ["sin", 1, 1], ["mix3", 1, 3], ["sep2", 1, 4], ["square", 1, 5], ["root_c", 1, 6], ["wave3", 1, 8], ["godel", 1, 9]],
		"boss": [["boss_sep2", 1], ["boss_wave", 1], ["boss_square", 1], ["root_5", 1], ["godel", 2]], "final": true},
}

# ---------------- towers ----------------
var TOWER_ORDER: Array = ["sub", "div", "zeno", "accel", "sqrt", "log2", "divx", "diff", "int", "dm1", "harm", "merge", "damp", "dtl", "wave", "lpf", "newton", "bisect"]

var TOWERS: Dictionary = {
	"sub": {
		"name": "빼기", "glyph": ["−1", "−2", "−3"], "color": Color("eceff1"), "cost": 50, "upgrade": [45, 90],
		"range": [120, 130, 145], "rate": [1.5, 1.8, 2.2], "power": [1, 2, 3], "research": "",
		"desc": "f → f − k. 상수항을 0 쪽으로 k만큼 깎습니다. 0을 지나치지는 않습니다.",
	},
	"div": {
		"name": "나누기", "glyph": ["÷2", "÷2", "÷2"], "color": Color("80deea"), "cost": 70, "upgrade": [60, 110],
		"range": [125, 135, 150], "rate": [0.8, 1.0, 1.25], "power": [2, 2, 2], "research": "",
		"desc": "n → n / 2. 나누어떨어질 때만 작동합니다 (정수 나눗셈). 홀수는 빼기로 먼저 짝수를 만드세요: 7 → 6 → 3 → 2 → 1 → 0.",
	},
	"sqrt": {
		"name": "제곱근", "glyph": ["√", "√", "√"], "color": Color("ffd166"), "cost": 90, "upgrade": [80, 130],
		"range": [150, 165, 185], "rate": [1.1, 1.4, 1.8], "power": [1, 1, 1], "research": "sqrt",
		"desc": "n² → n. 완전제곱수에만 작동합니다 (√7은 무리수라 쏘지 않습니다). 10000 → 100 → 10.",
	},
	"accel": {
		"name": "가속도", "glyph": ["a", "a", "a"], "color": Color("ffcc80"), "cost": 90, "upgrade": [90, 140],
		"range": [95, 110, 125], "rate": [1.0, 1.0, 1.0], "power": [1.3, 1.5, 1.7], "research": "accel",
		"desc": "a = d²x/dt². 범위 안의 다른 타워가 빨리 쏩니다 (×1.3, 강화하면 ×1.5, ×1.7). 여러 개가 겹치면 가장 강한 하나만 적용됩니다. 스스로는 공격하지 않습니다.",
	},
	"zeno": {
		"name": "제논", "glyph": ["½v", "⅖v", "⅓v"], "color": Color("90caf9"), "cost": 70, "upgrade": [70, 110],
		"range": [105, 120, 135], "rate": [1.0, 1.0, 1.0], "power": [0.5, 0.4, 0.33], "research": "zeno",
		"desc": "아킬레스와 거북이: 범위 안의 적은 속도가 절반으로 떨어집니다 (강화하면 ⅖, ⅓). 식은 건드리지 않습니다. 여러 개가 겹치면 가장 강한 하나만 적용됩니다.",
	},
	"log2": {
		"name": "이진 로그", "glyph": ["log₂", "log₂", "log₂"], "color": Color("ba68c8"), "cost": 100, "upgrade": [90, 140],
		"range": [150, 165, 185], "rate": [1.0, 1.3, 1.7], "power": [1, 1, 1], "research": "log2",
		"desc": "2ⁿ → n. 2의 거듭제곱에만 작동합니다. 65536 → 16 → 4 → 2 → 1 → 0  (log₂ 1 = 0).",
	},
	"divx": {
		"name": "x로 나누기", "glyph": ["÷x", "÷x", "÷x"], "color": Color("80cbc4"), "cost": 75, "upgrade": [65, 110],
		"range": [125, 135, 150], "rate": [0.8, 1.0, 1.25], "power": [1, 1, 1], "research": "divx",
		"desc": "f → f / x. 모든 항에 x가 있을 때만 나누어떨어집니다 (상수항이 0이어야 함). 빼기로 상수항을 지우고 나누세요: x² + 2x + 5 → x² + 2x → x + 2 → x → 1 → 0.",
	},
	"diff": {
		"name": "미분", "glyph": ["d/dx", "d/dx", "d/dx"], "color": Color("4fc3f7"), "cost": 90, "upgrade": [80, 160],
		"range": [130, 140, 155], "rate": [1.0, 1.3, 1.6], "power": [1, 1, 1], "research": "diff",
		"desc": "f → f′. 상수는 한 방에 0, xⁿ은 n+1번이면 소멸합니다. 미분할수록 계수가 커져 코어에서의 값이 오히려 늘 수 있습니다.",
	},
	"int": {
		"name": "적분", "glyph": ["∫", "∫", "∫"], "color": Color("81c784"), "cost": 120, "upgrade": [100, 170],
		"range": [130, 140, 155], "rate": [0.45, 0.55, 0.7], "power": [1.0, 1.6, 2.5], "research": "int",
		"desc": "f → ∫₀ˣ f dt. 적은 한 차수 강해지지만 ∫₀¹ f dx만큼 ρ를 수확합니다. 미적분학의 기본 정리: d/dx 한 방이면 원래 함수로 돌아옵니다. 적 하나당 3회.",
	},
	"dm1": {
		"name": "지수 소멸", "glyph": ["D−1", "D−1", "D−1"], "color": Color("aed581"), "cost": 100, "upgrade": [90, 150],
		"range": [130, 140, 155], "rate": [1.0, 1.3, 1.6], "power": [1, 1, 1], "research": "dm1",
		"desc": "f → f′ − f. 핵은 c·eˣ: eˣ는 한 방, xeˣ는 두 방. 다른 모드 e^{μx}에는 (μ − 1)배가 곱해집니다: 상수 5 → −5, e²ˣ → e²ˣ.",
	},
	"harm": {
		"name": "조화 소멸", "glyph": ["D²+1", "D²+1", "D²+1"], "color": Color("b39ddb"), "cost": 120, "upgrade": [100, 170],
		"range": [130, 140, 155], "rate": [0.9, 1.15, 1.4], "power": [1, 1, 1], "research": "harm",
		"desc": "f → f″ + ω²f. 핵은 sin ωx와 cos ωx. 다른 진동수에는 (ω² − ν²)배: D² + 1은 sin 2x를 −3배로 만듭니다.",
	},
	"merge": {
		"name": "선형결합", "glyph": ["Σ", "Σ", "Σ"], "color": Color("ffb74d"), "cost": 110, "upgrade": [100, 160],
		"range": [110, 125, 140], "rate": [0.4, 0.5, 0.6], "power": [3, 5, 8], "research": "merge",
		"desc": "범위 안의 함수 최대 k개를 하나로 더합니다 (k = 3, 5, 8). L(f+g) = Lf + Lg: 같은 소멸자끼리 합치면 한 방에. 부호가 반대면 상쇄됩니다.",
	},
	"damp": {
		"name": "감쇠장", "glyph": ["e⁻ˣ·", "e⁻ˣ·", "e⁻ˣ·"], "color": Color("90a4ae"), "cost": 120, "upgrade": [100, 170],
		"range": [125, 140, 155], "rate": [0.5, 0.62, 0.75], "power": [1, 1, 1], "research": "damp",
		"desc": "범위 안의 자라는 함수에 e⁻ˣ를 곱합니다: 모든 고윳값 μ → μ − 1. e²ˣ → eˣ, eˣ sin x → sin x. 상수는 c·e⁻ˣ가 되어 코어에서 거의 무해해집니다. D와 교환되지 않습니다.",
	},
	"dtl": {
		"name": "시간 소멸", "glyph": ["∂ₜ−1", "∂ₜ−1", "∂ₜ−1"], "color": Color("4dd0e1"), "cost": 120, "upgrade": [100, 160],
		"range": [130, 140, 155], "rate": [0.9, 1.15, 1.4], "power": [1, 1, 1], "research": "dtl",
		"desc": "f → ∂ₜf − λf. 핵은 g(x)·e^{λt}: 시간 인수 하나로 곱 전체를 지웁니다. 시간과 무관한 함수에는 −λ배.",
	},
	"wave": {
		"name": "파동 연산자", "glyph": ["□", "□", "□"], "color": Color("ff8a65"), "cost": 200, "upgrade": [160, 240],
		"range": [150, 165, 180], "rate": [0.4, 0.5, 0.62], "power": [1, 1, 1], "research": "wave",
		"desc": "□ = ∂ₜ² − ∂ₓ². 달랑베르: 모든 진행파 g(x − t) + h(x + t)가 핵에 있습니다. 다른 함수에는 ∂ₜ²f − f″.",
	},
	"lpf": {
		"name": "저역 통과", "glyph": ["LPF₃", "LPF₂", "LPF₁"], "color": Color("f48fb1"), "cost": 140, "upgrade": [110, 170],
		"range": [130, 145, 160], "rate": [0.6, 0.75, 0.9], "power": [2, 1, 1], "research": "lpf",
		"desc": "주파수 위의 곱셈 H(ω) = [|ω| ≤ ω꜀]. 범위 안 모든 함수에서 컷오프보다 높은 진동수를 통째로 지웁니다. 컷오프는 2, 강화하면 1.",
	},
	"newton": {
		"name": "뉴턴법", "glyph": ["N", "N", "N"], "color": Color("ffe082"), "cost": 120, "upgrade": [100, 150],
		"range": [140, 155, 170], "rate": [0.8, 1.0, 1.25], "power": [1, 1, 1], "research": "newton",
		"desc": "방정식 적에게: xₙ₊₁ = xₙ − p(xₙ)/p′(xₙ). 근 근처에서 맞는 자릿수가 두 배씩 늘어납니다. 시작점이 나쁘면 순환하거나 튕겨 나갑니다.",
	},
	"bisect": {
		"name": "이분법", "glyph": ["[a,b]", "[a,b]", "[a,b]"], "color": Color("c5e1a5"), "cost": 80, "upgrade": [70, 110],
		"range": [130, 140, 155], "rate": [1.2, 1.5, 1.8], "power": [1, 1, 1], "research": "bisect",
		"desc": "방정식 적에게: 부호가 바뀌는 구간 [a, b]를 절반으로. 한 번에 오차가 정확히 절반 — 1장의 ÷2입니다. 느리지만 절대 실패하지 않습니다.",
	},
}

# ---------------- research tree ----------------
var RESEARCH: Array = [
	{"id": "zeno", "chapter": 1, "name": "제논의 역설", "cost": 8, "req": [],
		"desc": "제논 타워 해금. 범위 안의 적이 반만큼만 나아갑니다. 아킬레스는 거북이를 영영 따라잡지 못한다고 했던가요?"},
	{"id": "accel", "chapter": 1, "name": "가속도", "cost": 12, "req": ["zeno"],
		"desc": "가속도 타워 해금. 주변 타워의 공격 속도를 올립니다. 그 칸에 연산 타워를 하나 더 놓을지, 있는 타워를 빠르게 할지."},
	{"id": "sqrt", "essential": true, "chapter": 1, "name": "제곱근", "cost": 10, "req": [],
		"desc": "√ 타워 해금. n² → n. 완전제곱수에만 정확합니다."},
	{"id": "psqrt", "chapter": 2, "name": "완전제곱식", "cost": 12, "req": ["divx", "sqrt"], "stage": "2-2",
		"desc": "√가 다항식에도 작동합니다: √(x² + 6x + 9) = x + 3. 완전제곱식일 때만 정확합니다."},
	{"id": "mult", "chapter": 1, "name": "곱셈 원리", "cost": 12, "req": [],
		"desc": "수입 공식의 c₂ 해금: dρ/dt = c₁ · c₂"},
	{"id": "drill", "chapter": 1, "name": "반복 빼기", "cost": 14, "req": [],
		"desc": "빼기 타워 공격 속도 +30%."},
	{"id": "log2", "essential": true, "chapter": 1, "name": "이진 로그", "cost": 18, "req": ["sqrt"],
		"desc": "log₂ 타워 해금. 2ⁿ → n, 그리고 log₂ 1 = 0."},
	{"id": "div3", "chapter": 1, "name": "약수의 감각", "cost": 22, "req": ["mult"],
		"desc": "나누기 타워 3레벨이 ÷3이 됩니다. 3의 배수를 단번에 3분의 1로."},
	{"id": "divx", "essential": true, "chapter": 2, "name": "x로 나누기", "cost": 8, "req": [], "flag": "met_x",
		"desc": "÷x 타워 해금. x를 x로 나누면 1, 1은 빼기로 0. 상수항을 먼저 지워야 나누어떨어집니다."},
	{"id": "diff", "essential": true, "chapter": 2, "name": "미분", "cost": 45, "req": ["divx"], "stage": "2-4",
		"desc": "d/dx 타워 해금. (c)′ = 0 — 상수를 빼기 없이 한 방에. (xⁿ)′ = nxⁿ⁻¹. 값이 아니라 변화를 다루는 도구."},
	{"id": "int", "chapter": 2, "name": "적분", "cost": 30, "req": ["diff"],
		"desc": "∫ 타워 해금. 적을 키우는 대신 ∫₀¹ f dx만큼 ρ를 수확합니다. 미적분학의 기본 정리: 미분 한 방이면 원래대로."},
	{"id": "d2", "chapter": 2, "name": "고계도함수", "cost": 38, "req": ["diff"], "stage": "2-5",
		"desc": "미분 타워 3레벨이 d²/dx²가 됩니다."},
	{"id": "d3", "chapter": 2, "name": "삼계도함수", "cost": 52, "req": ["d2"], "stage": "2-6",
		"desc": "미분 타워 3레벨이 d³/dx³가 됩니다."},
	{"id": "int2", "chapter": 2, "name": "정적분", "cost": 45, "req": ["int"], "stage": "2-5",
		"desc": "적분 수확 ×1.5. 넓이를 더 정확하게 셉니다."},
	{"id": "ln", "essential": true, "chapter": 3, "name": "자연로그", "cost": 15, "req": [], "flag": "met_exp",
		"desc": "로그 타워가 함수에도 작동합니다: log(c·eᵃˣ) = ax + ln c. 지수함수 하나짜리에만, 그리고 계수 c가 클수록 c배 오래 걸립니다. 상수항이 붙어 있거나(eˣ + 3) 다른 항과 더해져 있으면(x + eˣ) 먼저 떼어 내야 합니다."},
	{"id": "sub_range", "chapter": 1, "name": "넓은 빼기", "cost": 15, "req": [], "mod": {"kind": "range", "tower": "sub", "mult": 1.2},
		"desc": "빼기 타워 사거리 +20%."},
	{"id": "start_rho", "chapter": 1, "name": "종잣돈", "cost": 18, "req": [],
		"desc": "모든 스테이지의 시작 ρ +30."},
	{"id": "divx_fast", "chapter": 2, "name": "인수분해 감각", "cost": 25, "req": [], "mod": {"kind": "rate", "tower": "divx", "mult": 1.3},
		"desc": "÷x 타워 공격 속도 +30%."},
	{"id": "diff_range", "chapter": 2, "name": "접선의 시야", "cost": 30, "req": [], "mod": {"kind": "range", "tower": "diff", "mult": 1.15},
		"desc": "미분 타워 사거리 +15%."},
	{"id": "log_fast", "chapter": 3, "name": "로그 법칙", "cost": 30, "req": [],
		"desc": "log(c·eᵃˣ)의 계수 지연이 절반으로: c배 대신 (1 + c)/2배."},
	{"id": "merge_range", "chapter": 3, "name": "넓은 결합", "cost": 30, "req": [], "mod": {"kind": "range", "tower": "merge", "mult": 1.2},
		"desc": "Σ 타워 사거리 +20%."},
	{"id": "think_cheap", "chapter": 4, "name": "컴파일러", "cost": 30, "req": [],
		"desc": "알고리즘의 계산 비용이 절반으로 (1,000단계 = 0.125초)."},
	{"id": "diff_fast", "chapter": 4, "name": "빠른 미분", "cost": 35, "req": [], "mod": {"kind": "rate", "tower": "diff", "mult": 1.25},
		"desc": "미분 타워 공격 속도 +25%."},
	{"id": "merge_fast", "chapter": 4, "name": "빠른 결합", "cost": 35, "req": [], "mod": {"kind": "rate", "tower": "merge", "mult": 1.3},
		"desc": "Σ 타워 공격 속도 +30%."},
	{"id": "dtl_fast", "chapter": 5, "name": "빠른 시간", "cost": 35, "req": [], "mod": {"kind": "rate", "tower": "dtl", "mult": 1.3},
		"desc": "시간 소멸 타워 공격 속도 +30%."},
	{"id": "wave_fast", "chapter": 5, "name": "빠른 파동", "cost": 35, "req": [], "mod": {"kind": "rate", "tower": "wave", "mult": 1.3},
		"desc": "□ 타워 공격 속도 +30%."},
	{"id": "damp_range", "chapter": 6, "name": "넓은 감쇠", "cost": 35, "req": [], "mod": {"kind": "range", "tower": "damp", "mult": 1.2},
		"desc": "감쇠장 사거리 +20%."},
	{"id": "core_up", "chapter": 6, "name": "견고한 코어", "cost": 40, "req": [],
		"desc": "모든 스테이지의 무결성 +20%."},
	{"id": "dm1", "chapter": 8, "name": "지수 소멸 D−1", "cost": 15, "req": [], "flag": "met_signal",
		"desc": "D − 1 타워 해금. (D − 1)eˣ = 0. 고윳값을 빼면 고유함수가 사라집니다."},
	{"id": "ann", "chapter": 8, "name": "소멸자 이론", "cost": 18, "req": ["dm1"], "stage": "8-1",
		"desc": "적 위에 소멸자 Ann(f)를 표시합니다. 그 차수가 곧 필요한 타격 수입니다."},
	{"id": "dbl", "chapter": 8, "name": "중근", "cost": 42, "req": ["dm1"], "stage": "8-2",
		"desc": "D − 1 타워 3레벨이 (D − 1)²가 됩니다. xeˣ를 한 방에."},
	{"id": "harm", "chapter": 8, "name": "오일러 공식", "cost": 20, "req": [], "flag": "met_signal",
		"desc": "D² + 1 타워 해금. e^{ix} = cos x + i sin x 이므로 sin의 고윳값은 ±i, (D − i)(D + i) = D² + 1."},
	{"id": "harm2", "chapter": 8, "name": "공명", "cost": 42, "req": ["harm"], "stage": "8-2",
		"desc": "조화 소멸 3레벨이 (D² + ω²)²가 됩니다. x sin x를 한 방에."},
	{"id": "omega2", "chapter": 8, "name": "진동수", "cost": 33, "req": ["harm"], "stage": "8-3",
		"desc": "조화 소멸 타워의 ω를 1 ↔ 2로 바꿀 수 있습니다 [W]. D² + 4는 sin 2x의 소멸자."},
	{"id": "merge", "essential": true, "chapter": 3, "name": "선형성 Σ", "cost": 25, "req": ["ln"], "stage": "3-3",
		"desc": "Σ 타워 해금. 범위 안의 함수들을 하나로 더합니다. 모든 타워는 선형이므로 합친 뒤 한 번에 처리할 수 있습니다."},
	{"id": "merge2", "chapter": 8, "name": "기저 정리", "cost": 45, "req": ["merge"], "stage": "8-2",
		"desc": "Σ가 계수를 고릅니다. 범위 안의 함수들이 선형 종속이면 (예: 3eˣ와 5eˣ, 또는 sin x, cos x, 2sin x + cos x 셋) 합이 0이 되는 결합을 찾아 모두 소거합니다."},
	{"id": "damp", "essential": true, "chapter": 6, "name": "켤레 공식", "cost": 25, "req": [], "flag": "met_exp2",
		"desc": "감쇠장 타워 해금. eˣ · D · e⁻ˣ = D − 1: e⁻ˣ를 곱하면 고윳값이 1씩 내려갑니다."},
	{"id": "damp2", "chapter": 6, "name": "이중 감쇠", "cost": 45, "req": ["damp"], "stage": "6-2",
		"desc": "감쇠장 3레벨이 e⁻²ˣ·가 됩니다. e³ˣ → eˣ를 한 번에."},
	{"id": "dtl", "essential": true, "chapter": 5, "name": "편미분", "cost": 25, "req": [], "flag": "met_time",
		"desc": "시간 소멸 ∂ₜ − 1 타워 해금. 곱 g(x)·eᵗ를 시간 인수 하나로 지웁니다."},
	{"id": "dtl2", "chapter": 5, "name": "성장률", "cost": 38, "req": ["dtl"], "stage": "5-1",
		"desc": "시간 소멸의 λ를 1 ↔ 2로 바꿀 수 있습니다 [W]."},
	{"id": "wave", "essential": true, "chapter": 5, "name": "달랑베르 해", "cost": 60, "req": ["dtl"], "stage": "5-3",
		"desc": "파동 연산자 □ = ∂ₜ² − ∂ₓ² 해금. 모든 진행파 g(x ∓ t)를 한 방에."},
	{"id": "lpf", "chapter": 8, "name": "푸리에 변환", "cost": 30, "req": [], "flag": "met_signal",
		"desc": "저역 통과 필터 해금. D ⟷ iω: 미분은 주파수 위의 곱셈입니다. 그렇다면 높은 진동수에 0을 곱할 수도 있습니다."},
	{"id": "newton", "chapter": 9, "name": "뉴턴 방법", "cost": 30, "req": [], "flag": "met_quintic",
		"desc": "뉴턴법 타워 해금. 방정식 p(x) = 0을 반복으로 풉니다: 이차 수렴."},
	{"id": "bisect", "chapter": 9, "name": "중간값 정리", "cost": 30, "req": ["newton"], "stage": "9-1",
		"desc": "이분법 타워 해금. p(a)와 p(b)의 부호가 다르면 그 사이에 근이 있습니다. 구간을 절반씩."},
	{"id": "ax_g", "chapter": 10, "name": "공리: G", "cost": 45, "req": [], "flag": "met_godel", "axiom": true,
		"desc": "G를 공리로 받아들입니다. G는 이제 증명된 문장이므로, 어떤 타워든 한 번 맞히면 사라집니다."},
	{"id": "ax_choice", "chapter": 10, "name": "공리: 선택", "cost": 45, "req": [], "flag": "met_godel", "axiom": true,
		"desc": "선택공리. Σ가 범위 안의 모든 함수를 한 번에 합칩니다."},
	{"id": "ax_inf", "chapter": 10, "name": "공리: 무한소", "cost": 45, "req": [], "flag": "met_godel", "axiom": true,
		"desc": "비표준 해석. 코어에서의 크기가 1보다 작은 함수는 어떤 타워에 맞든 0과 같아집니다."},
	{"id": "ax_ind", "chapter": 10, "name": "공리: 귀납", "cost": 45, "req": [], "flag": "met_godel", "axiom": true,
		"desc": "수학적 귀납법. 한 함수가 0이 되면 전장의 똑같은 함수가 모두 함께 0이 됩니다."},
]

# ---------------- attack algorithms (in-game Python) ----------------
const EXAMPLE_ATTACK := """# 기본 알고리즘 — 4장부터 모든 타워가 쓰는 것과 같습니다.
# 이 파일은 타워가 쏠 준비가 될 때마다 맨 위부터 실행됩니다.
#   enemies : 사거리 안의 적들 (코어에 가까운 적부터)
#   attack(e) : e를 칩니다. 그 순간 실행이 끝납니다 (파일 끝으로).
#   attack을 안 부르고 끝나면 이번엔 쉽니다.

attack(enemies[0])
"""

const EXAMPLE_DAMP := """# Σ 타워 예시: 더해서 0이 되는 짝을 찾아 더하기
# 범위 타워는 attack([a, b])처럼 리스트를 주면 그 적들에게만 작용합니다.

for a in enemies:
    for b in enemies:
        if a != b and a.f.shape == b.f.shape and a.f.coef == -b.f.coef:
            attack([a, b])
"""

const ALGO_LESSONS := [
	["1. 첫 알고리즘", "이 파일은 타워가 쏠 때마다 맨 위부터 실행됩니다. enemies는 사거리 안의 적들이고, 코어에 가까운 적이 앞에 옵니다. attack(e)를 부르면 e를 치고 실행이 끝납니다. 아래가 기본 타워와 똑같은 알고리즘입니다.",
"""attack(enemies[0])
"""],
	["2. 고르기", "for로 적을 하나씩 봅니다. e.f는 적의 식이고, kind가 \"num\"이면 그냥 숫자입니다. attack을 부르는 순간 끝나니, 처음 찾은 적만 칩니다. 아무도 못 찾고 파일 끝에 닿으면 이번엔 쉽니다.",
"""for e in enemies:
    if e.f.kind != "num":    # 숫자는 건너뛴다
        attack(e)
"""],
	["3. 식을 항으로 쪼개기", "e.f.terms는 덧셈으로 나뉜 항들입니다. 항마다 차수(degree), 계수(coef), 계수를 뺀 모양(shape)을 볼 수 있습니다. print는 아래 콘솔에 찍힙니다. 「테스트 실행」으로 확인해 보세요.",
"""for e in enemies:
    for term in e.f.terms:
        print(term, "모양", term.shape, "계수", term.coef, "차수", term.degree)
attack(enemies[0])
"""],
	["4. 곱과 합성", "항은 곱으로 다시 나뉩니다: term.factors. sin(2x), exp(2x) 같은 합성함수는 .inner로 안쪽을 꺼냅니다. sin(2x)의 inner는 2x이고, 그 계수가 진동수 2입니다.",
"""for e in enemies:
    for term in e.f.terms:
        for fac in term.factors:
            if fac.kind == "sin" and fac.inner.coef == 2:
                attack(e)            # sin 2x가 들어 있는 첫 적
"""],
	["5. 협업 ① — D 타워", "sin x 둘이 오면, 하나를 두 번 미분해 −sin x로 만듭니다. 짝이 이미 있는 적(더하면 0이 되는 상대가 있는 적)은 건드리지 않습니다. 이 파일을 D 타워에 붙이세요.",
"""def has_partner(a):
    for b in enemies:
        if a != b and a.f.shape == b.f.shape and a.f.coef == -b.f.coef:
            return True
    return False

for e in enemies:
    if e.f.has("sin") or e.f.has("cos"):
        if not has_partner(e):
            attack(e)
"""],
	["6. 협업 ② — Σ 타워", "Σ는 attack([a, b])로 두 적을 더합니다. 모양이 같고 계수가 반대인 짝(sin x와 −sin x)을 찾으면 더해서 0. 이 파일을 Σ 타워에 붙이세요.",
"""for a in enemies:
    for b in enemies:
        if a != b and a.f.shape == b.f.shape and a.f.coef == -b.f.coef:
            attack([a, b])
"""],
	["7. 쏴 보기 전에 미리 보기", "e.after()는 이 타워가 한 번 쏜 뒤의 모습입니다. 쏘면 피해가 줄거나 0이 되는 적만 고를 수 있습니다. 대신 비쌉니다: after() 한 번이 40단계입니다.",
"""for e in enemies:
    a = e.after()
    if a.zero or a.damage < e.damage:
        attack(e)
"""],
	["8. 계산은 공짜가 아니다", "알고리즘이 쓴 단계만큼 타워가 늦게 쏩니다 (1,000단계 = 0.25초). 타워 정보에 지난번 단계 수가 나옵니다. 위 5번처럼 이중 반복문은 적이 많을 때 비쌉니다. 앞에서 찾자마자 attack하고, 비싼 after()는 꼭 필요할 때만.",
"""for e in enemies:              # 앞에서부터: 찾자마자 끝
    if e.f.has("sin"):
        attack(e)
"""],
]

const ALGO_HELP := """[b]실행[/b]  파일이 맨 위부터 실행됩니다. [code]attack(e)[/code] 또는 [code]attack([a, b])[/code]를 부르면 치고 끝. 안 부르고 끝나면 쉼.

[b]적 e[/b]  (enemies는 앞선 적부터)
[code]e.f[/code]  식 (아래 '식' 참고)
[code]e.value[/code]  코어에서의 값    [code]e.damage[/code]  코어에 닿으면 받는 피해
[code]e.after()[/code]  이 타워가 한 번 쏜 뒤의 모습 (40단계, 비쌈)
[code]e.zero[/code]  0이 되었는가 (after()에서)
[code]e.progress[/code]  진행도 0–1   [code]e.x  e.dist  e.speed[/code]
[code]e.boss  e.members  e.name  e.special[/code]

[b]식 f[/b]
[code]f.kind[/code]  "add" 합 · "mul" 곱 · "pow" 거듭제곱 · "exp" "sin" "cos" · "num" 수 · "x" · "t"
[code]f.terms[/code]  덧셈으로 나눈 항들      [code]f.factors[/code]  곱으로 나눈 인수들
[code]f.inner[/code]  exp·sin·cos의 안쪽 (sin(2x) → 2x)
[code]f.base  f.exponent[/code]  거듭제곱 x^3 → x, 3
[code]f.coef[/code]  수 계수 (3·x^2 → 3)    [code]f.shape[/code]  계수를 뺀 모양 ("sin(x)")
[code]f.degree[/code]  x의 차수
[code]f.value[/code]  수일 때 그 값    [code]f.args[/code]  자식들
[code]f.has("sin")[/code]  그 종류가 어딘가에 있는가    [code]print(f)[/code]  식 출력

[b]타워[/b]  [code]me.op  me.name  me.level  me.param  me.range[/code]
[code]set_param(v)[/code]  ω 또는 λ 바꾸기 (연구 필요)
[b]전역[/b]  [code]wave  rho  integrity[/code]

[b]내장 함수[/b]  print len range min max abs sorted sum any all int float str round list enumerate zip reversed
min·max·sorted는 [code]key=[/code], min·max는 [code]default=[/code]

[b]비용[/b]  1단계 = 0.00025초 지연. 한 번 실행에 20,000단계까지.
오류가 나면 그 타워는 기본(맨 앞 적)으로 돌아갑니다. 예전 방식 def attack(enemies): return … 도 그대로 작동합니다.
"""


# ---------------- enemy templates ----------------
# kind: num | sq | p2 | poly | exp | trig   (used for previews and the test bot)
var TEMPLATES: Dictionary = {
	"n1": {"speed": 70, "name": "한 자리 수", "kind": "num"}, "n2": {"speed": 64, "name": "두 자리 수", "kind": "num"},
	"even": {"speed": 58, "name": "짝수", "kind": "num"}, "n100": {"speed": 44, "boss": true, "name": "100", "kind": "num"},
	"sq": {"speed": 56, "name": "완전제곱수", "kind": "sq"}, "p2": {"speed": 56, "name": "2의 거듭제곱", "kind": "p2"},
	"prime": {"speed": 74, "name": "소수", "kind": "num"}, "big": {"speed": 42, "name": "큰 수", "kind": "sq"},
	"bigprime": {"speed": 38, "boss": true, "name": "큰 소수", "kind": "num"},
	"k1000": {"speed": 36, "boss": true, "name": "1000", "kind": "num"},
	"k10000": {"speed": 34, "boss": true, "name": "10000", "kind": "sq"},
	"k65536": {"speed": 40, "boss": true, "name": "2¹⁶", "kind": "p2"},
	"k10_6": {"speed": 28, "boss": true, "name": "10⁶", "kind": "sq"},
	"k2_32": {"speed": 28, "boss": true, "name": "2³²", "kind": "p2"},
	"x_counter": {"speed": 170, "boss": true, "name": "x", "kind": "poly"},
	"x": {"speed": 60, "name": "x", "kind": "poly"}, "xc": {"speed": 60, "name": "x + c", "kind": "poly"},
	"lin": {"speed": 58, "name": "ax + b", "kind": "poly"}, "quad": {"speed": 52, "name": "이차식", "kind": "poly"},
	"cubic": {"speed": 46, "name": "삼차식", "kind": "poly"}, "quart": {"speed": 42, "name": "사차식", "kind": "poly"},
	"quint": {"speed": 38, "name": "오차식", "kind": "poly"},
	"kx": {"speed": 58, "name": "k(x + c)", "kind": "poly"}, "xbx": {"speed": 54, "name": "x² + bx", "kind": "poly"},
	"kxx": {"speed": 50, "name": "k·x(x + c)", "kind": "poly"}, "sqp": {"speed": 50, "name": "(x + c)²", "kind": "poly"},
	"x4": {"speed": 44, "name": "x⁴", "kind": "poly"}, "sq2": {"speed": 42, "name": "(x² + c)²", "kind": "poly"},
	"boss_alg2": {"speed": 30, "boss": true, "name": "6x² + 12x", "kind": "poly"},
	"boss_sq": {"speed": 28, "boss": true, "name": "(x² + 2x + 3)²", "kind": "poly"},
	"boss_x4": {"speed": 30, "boss": true, "name": "x⁴ + 7", "kind": "poly"},
	"boss_x5": {"speed": 28, "boss": true, "name": "x⁵ + x² + 6", "kind": "poly"},
	"boss_x6": {"speed": 26, "boss": true, "name": "x⁶ + 3x² + 9", "kind": "poly"},
	"exp_counter": {"speed": 26, "boss": true, "name": "eˣ", "kind": "exp"},
	"ex": {"speed": 46, "name": "eˣ", "kind": "exp"}, "exs": {"speed": 44, "name": "c·eˣ", "kind": "exp"},
	"exc": {"speed": 44, "name": "eˣ + c", "kind": "exp"}, "pex": {"speed": 42, "name": "x² + eˣ", "kind": "exp"},
	"xex": {"speed": 40, "name": "xeˣ", "kind": "exp"}, "x2ex": {"speed": 36, "name": "x²eˣ", "kind": "exp"},
	"mix3": {"speed": 40, "name": "x³ + xeˣ + c", "kind": "exp"},
	"mix3b": {"speed": 28, "boss": true, "name": "2x³ + 3eˣ + 9", "kind": "exp"},
	"boss_ex1": {"speed": 30, "boss": true, "name": "6eˣ + 4", "kind": "exp"},
	"boss_x3ex": {"speed": 26, "boss": true, "name": "x³eˣ + 1", "kind": "exp"},
	"boss_ex": {"speed": 26, "boss": true, "name": "x²eˣ + x³ + 5", "kind": "exp"},
	"sin_counter": {"speed": 26, "boss": true, "name": "8 sin x", "kind": "trig"},
	"xpe": {"speed": 46, "name": "x + eˣ", "kind": "exp"},
	"boss_chain": {"speed": 28, "boss": true, "name": "4x²e²ˣ", "kind": "exp", "noarmor": true},
	"s1": {"speed": 50, "name": "a sin x", "kind": "trig", "noarmor": true},
	"c1": {"speed": 50, "name": "a cos x", "kind": "trig", "noarmor": true},
	"s1c": {"speed": 48, "name": "a sin x + c", "kind": "trig", "noarmor": true},
	"s2": {"speed": 50, "name": "a sin 2x", "kind": "trig", "noarmor": true},
	"c2": {"speed": 50, "name": "a cos 2x", "kind": "trig", "noarmor": true},
	"tse": {"speed": 44, "name": "a sin x + eˣ", "kind": "trig", "noarmor": true},
	"boss_sc": {"speed": 28, "boss": true, "name": "b sin x + b cos x", "kind": "trig", "noarmor": true},
	"boss_s2": {"speed": 28, "boss": true, "name": "b sin 2x + 5", "kind": "trig", "noarmor": true},
	"tx_counter": {"speed": 26, "boss": true, "name": "eˣ sin x · eᵗ", "kind": "time"},
	"tsin": {"speed": 46, "name": "a sin x · eᵗ", "kind": "time"},
	"exsin_counter": {"speed": 26, "boss": true, "name": "eˣ sin x", "kind": "exp2"},
	"sin": {"speed": 54, "name": "a sin x", "kind": "trig"}, "cos": {"speed": 54, "name": "a cos x", "kind": "trig"},
	"asin": {"speed": 50, "name": "a sin x + c", "kind": "trig"}, "xsin": {"speed": 40, "name": "x sin x", "kind": "trig"},
	"boss_trig": {"speed": 28, "boss": true, "name": "4cos x + 4sin x + x² + 3", "kind": "trig"},
	"acs": {"speed": 52, "name": "A cos x + B sin x", "kind": "trig"}, "xcos": {"speed": 40, "name": "x cos x", "kind": "trig"},
	"boss_res": {"speed": 28, "boss": true, "name": "3x sin x + 2x cos x + 4", "kind": "trig"},
	"sin2": {"speed": 54, "name": "a sin 2x", "kind": "trig"}, "cos2": {"speed": 54, "name": "a cos 2x", "kind": "trig"},
	"boss_w2": {"speed": 28, "boss": true, "name": "5 sin 2x + 5 sin x + 3", "kind": "trig"},
	"tex": {"speed": 46, "name": "sin x + eˣ", "kind": "trig"}, "tpx": {"speed": 46, "name": "x + cos x", "kind": "trig"},
	"boss_hy": {"speed": 26, "boss": true, "name": "x² + 2eˣ + 3sin x + 5", "kind": "trig"},
	"swarm_counter": {"speed": 95, "name": "3 sin x + 3", "kind": "trig"},
	"gen_x3": {"speed": 34, "name": "x³ (생성)", "kind": "poly", "gen": true},
	"gen_x4": {"speed": 32, "name": "x⁴ (생성)", "kind": "poly", "gen": true},
	"gen_x5": {"speed": 26, "boss": true, "name": "x⁵ + 9 (생성)", "kind": "poly", "gen": true},
	"gen_ex": {"speed": 30, "name": "2eˣ (생성)", "kind": "exp", "gen": true},
	"gen_sin": {"speed": 32, "name": "4 sin x (생성)", "kind": "trig", "gen": true},
	"gen_boss": {"speed": 24, "boss": true, "name": "3eˣ + 4 sin x (생성)", "kind": "trig", "gen": true},
	"child": {"speed": 52, "name": "자손", "kind": "poly"},
	"pm_ex": {"speed": 50, "name": "±c·eˣ", "kind": "exp"}, "pm_n": {"speed": 60, "name": "±c", "kind": "num"},
	"pm_sin": {"speed": 50, "name": "±c sin x", "kind": "trig"},
	"exp2_counter": {"speed": 26, "boss": true, "name": "e²ˣ", "kind": "exp2"},
	"e2x": {"speed": 30, "name": "e²ˣ", "kind": "exp2"}, "e2c": {"speed": 28, "name": "e²ˣ + eˣ + c", "kind": "exp2"},
	"exsin": {"speed": 32, "name": "eˣ sin x", "kind": "exp2"},
	"boss_e2": {"speed": 26, "boss": true, "name": "2e²ˣ + eˣ sin x + 3", "kind": "exp2"},
	"e3x": {"speed": 28, "name": "e³ˣ", "kind": "exp2"}, "xe2x": {"speed": 28, "name": "xe²ˣ", "kind": "exp2"},
	"boss_e3": {"speed": 24, "boss": true, "name": "e³ˣ + xe²ˣ + 4", "kind": "exp2"},
	"tsep_counter": {"speed": 26, "boss": true, "name": "(x³ + eˣ sin 3x + 9)e²ᵗ", "kind": "time"},
	"sep1": {"speed": 46, "name": "(x + c)·eᵗ", "kind": "time"}, "sepx": {"speed": 42, "name": "x²eᵗ", "kind": "time"},
	"sep2": {"speed": 42, "name": "(x + c)·e²ᵗ", "kind": "time"},
	"boss_sep": {"speed": 26, "boss": true, "name": "(x³ + 2x + 5)eᵗ", "kind": "time"},
	"boss_sep2": {"speed": 24, "boss": true, "name": "(x⁴ + eˣ + 3)e²ᵗ", "kind": "time"},
	"tsum": {"speed": 44, "name": "x² + x·eᵗ", "kind": "time"}, "tsum2": {"speed": 40, "name": "eˣ + 3eᵗ + x", "kind": "time"},
	"wave2": {"speed": 44, "name": "(x − t)²", "kind": "wave"}, "wave3": {"speed": 40, "name": "(x − t)³", "kind": "wave"},
	"wave_e": {"speed": 42, "name": "e^{x+t}", "kind": "wave"}, "wave_l": {"speed": 44, "name": "(x + t)²", "kind": "wave"},
	"wave_mix": {"speed": 38, "name": "(x − t)² + e^{x−t} + 3", "kind": "wave"},
	"boss_wave": {"speed": 24, "boss": true, "name": "(x − t)³ + (x + t)² + 2eˣ", "kind": "wave"},
	"signal_counter": {"speed": 30, "boss": true, "name": "사각파 (8항)", "kind": "signal"},
	"sig2": {"speed": 44, "name": "a sin x + b sin 3x", "kind": "signal"}, "sig3": {"speed": 40, "name": "3항 신호", "kind": "signal"},
	"sigp": {"speed": 42, "name": "x² + sin 4x", "kind": "signal"}, "sige": {"speed": 40, "name": "eˣ + sin 3x + sin 5x", "kind": "signal"},
	"square": {"speed": 36, "name": "사각파 (4항)", "kind": "signal"}, "saw": {"speed": 36, "name": "톱니파 (5항)", "kind": "signal"},
	"mod5": {"speed": 40, "name": "eˣ sin 5x", "kind": "signal"},
	"boss_sig": {"speed": 26, "boss": true, "name": "5 sin x + 5 sin 3x + 5 sin 7x + x²", "kind": "signal"},
	"boss_square": {"speed": 24, "boss": true, "name": "사각파 (7항) + 2eˣ", "kind": "signal"},
	"quintic_counter": {"speed": 28, "boss": true, "name": "x⁵ − x − 1 = 0", "kind": "root", "special": "root"},
	"root_q": {"speed": 44, "name": "x² − 2 = 0", "kind": "root", "special": "root"},
	"root_c": {"speed": 40, "name": "x³ − 2x − 5 = 0", "kind": "root", "special": "root"},
	"root_cyc": {"speed": 40, "name": "x³ − 2x + 2 = 0", "kind": "root", "special": "root"},
	"root_cos": {"speed": 40, "name": "cos x − x = 0", "kind": "root", "special": "root"},
	"root_ex": {"speed": 40, "name": "eˣ − 3 = 0", "kind": "root", "special": "root"},
	"root_5": {"speed": 26, "boss": true, "name": "x⁵ − x − 1 = 0", "kind": "root", "special": "root"},
	"godel_counter": {"speed": 26, "boss": true, "name": "G", "kind": "godel", "special": "godel"},
	"godel": {"speed": 34, "name": "G", "kind": "godel", "special": "godel"},
}

## Equation enemies: polynomial / function p, starting guess x0, sign-changing bracket [lo, hi].
var ROOTS: Dictionary = {
	"quintic_counter": {"x0": 1.0, "lo": 1.0, "hi": 2.0}, "root_5": {"x0": 1.0, "lo": 1.0, "hi": 2.0},
	"root_q": {"x0": 1.0, "lo": 1.0, "hi": 2.0}, "root_c": {"x0": 2.0, "lo": 2.0, "hi": 3.0},
	"root_cyc": {"x0": 0.0, "lo": -2.0, "hi": -1.0}, "root_cos": {"x0": 1.0, "lo": 0.0, "hi": 1.0},
	"root_ex": {"x0": 0.0, "lo": 1.0, "hi": 2.0},
}

var SQUARES: Array = [16, 25, 36, 49, 64, 81, 100, 121, 144, 169, 196, 225, 256, 400, 625, 900]
var PRIMES: Array = [11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97]
var BIGS: Array = [1000, 1024, 1296, 2048, 3600, 4096, 9801, 10000]


## Total Insight cost of a chapter's research (essential + optional, axioms excluded): "the most you could need".
func chapter_budget(ch: int) -> int:
	var t := 0
	for n in RESEARCH:
		if int(n["chapter"]) == ch and not n.get("axiom", false):
			t += int(n["cost"])
	return t


func chapter_stage_count(ch: int) -> int:
	var c := 0
	for sid in STAGE_ORDER:
		if chapter_of(sid) == ch:
			c += 1
	return maxi(1, c)


## First clear of a stage: normal pays ¾ of the chapter budget over its stages, hard pays 3/2.
func stage_insight(sid: String, hard: bool) -> int:
	var ch := chapter_of(sid)
	return int(ceil((1.5 if hard else 0.75) * chapter_budget(ch) / float(chapter_stage_count(ch))))


func essentials_of(ch: int) -> Array:
	var out: Array = []
	for n in RESEARCH:
		if int(n["chapter"]) == ch and n.get("essential", false):
			out.append(n["id"])
	return out


## Product of every owned research modifier of this kind for this tower ("range" or "rate").
func research_mult(kind: String, tower: String) -> float:
	var m := 1.0
	for n in RESEARCH:
		var md: Dictionary = n.get("mod", {})
		if not md.is_empty() and md["kind"] == kind and md["tower"] == tower and Progress.has(n["id"]):
			m *= float(md["mult"])
	return m


func stage(sid: String) -> Dictionary:
	return STAGES[sid]


func chapter_of(sid: String) -> int:
	return int(STAGES[sid]["chapter"])


const SHORT_PICK := [1, 5, 9, 12, 15]


## Which original wave numbers this run plays (all 15, or 5 in the developer's short mode).
func wave_levels() -> Array:
	if Progress.dev_short:
		return SHORT_PICK.duplicate()
	var out: Array = []
	for w in range(1, WAVES_PER_STAGE + 1):
		out.append(w)
	return out


## Deterministic 15-wave script for a stage. Each group: [template, count, interval].
func stage_waves(sid: String) -> Array:
	var st: Dictionary = STAGES[sid]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sid) + 17
	var waves: Array = []
	for w in range(1, WAVES_PER_STAGE + 1):
		var avail: Array = []
		for m in st["mix"]:
			if int(m[2]) <= w:
				for k in int(m[1]):
					if not avail.has(m[0]) or k > 0:
						avail.append(m[0])
		var picks: Array = []
		var guard := 0
		while picks.size() < mini(3, _unique(avail).size()) and guard < 50:
			guard += 1
			var tpl: String = avail[rng.randi_range(0, avail.size() - 1)]
			if not picks.has(tpl):
				picks.append(tpl)
		# a tower-defence curve: a gentle start, then the count keeps accelerating to the boss wave
		var total := int(float(st["base"]) * 0.5 + float(st["growth"]) * 1.6 * (w - 1) * (0.8 + 0.09 * (w - 1)))
		if Game.hard:   # measured per chapter: hard should need most of the optional upgrades
			total = int(total * float({1: 1.0, 2: 1.4, 3: 2.0, 4: 2.0, 5: 1.35}.get(int(st["chapter"]), 1.4)))
		var iv: Array = st["interval"]
		var interval := lerpf(float(iv[0]), float(iv[1]), (w - 1) / float(WAVES_PER_STAGE - 1)) * (0.9 if Game.hard else 1.0)
		var groups: Array = []
		for tpl in picks:
			var cnt := maxi(2, int(total / float(picks.size())))
			if TEMPLATES[tpl].get("gen", false):
				cnt = clampi(1 + int(w / 4.0), 1, 4)   # generators are elites
			groups.append([tpl, cnt, interval * (2.5 if TEMPLATES[tpl].get("gen", false) else 1.0)])
		if w == 8 and int(st["chapter"]) == 1:
			groups.append([st["boss"][0][0], 1, 2.0])   # a preview of the boss mid-stage
		if w == WAVES_PER_STAGE:
			for b in st["boss"]:
				groups.append([b[0], int(b[1]) + (1 if Game.hard else 0), 6.0])
			if st.has("counter"):
				var ci: Dictionary = COUNTERS[st["counter"]]
				groups.append([st["counter"], int(ci.get("count", 1)), float(ci.get("interval", 3.0))])
		waves.append(groups)
	return waves


func _unique(a: Array) -> Array:
	var out: Array = []
	for v in a:
		if not out.has(v):
			out.append(v)
	return out


const ARMOR_KINDS := ["poly", "exp", "trig", "exp2"]


const CURSE_CHAPTER := 4
const CURSE_TEXT := "⚠ 4장의 저주 — 연산자는 상대를 고르지 않습니다.
타워는 사거리 맨 앞의 함수를, 쓸모가 있든 없든 그냥 때립니다 (범위 타워는 전부). 상수 1에 감쇠장을 걸면 e⁻ˣ가 되고, e²ˣ에 D를 쏘면 2배가 됩니다.
누구를 쏠지는 직접 정하세요: 타워를 선택하고 [E]. 편집기의 「가이드」가 처음부터 알려 줍니다."


## Chapter 6 on: towers lose their built-in oracle and hit every function in range.
func cursed() -> bool:
	return STAGES.has(Game.stage_id) and chapter_of(Game.stage_id) >= CURSE_CHAPTER


## Multiplicity armour: from chapter 2 on, later waves and later chapters multiply enemies by xᵐ.
## xᵐ·eˣ needs (D − 1)ᵐ⁺¹ — the annihilator's degree is the enemy's real health. ÷x strips one layer per
## hit and works on every mode at once, but each D first costs a layer: D(xᵐg) = mxᵐ⁻¹g + xᵐg′  ([D, x] = 1).
func armor_power(tpl: String, wave: int) -> int:
	var info: Dictionary = TEMPLATES.get(tpl, {})
	if not ARMOR_KINDS.has(info.get("kind", "")) or COUNTERS.has(tpl) or tpl == "child" or info.get("gen", false) or info.get("noarmor", false):
		return 0
	if not STAGES.has(Game.stage_id):
		return 0
	var ch := chapter_of(Game.stage_id)
	if ch < 2 or ch == 3 or ch == 4:   # chapters 3–4 teach chains and teamwork; no armour on top of that
		return 0
	var m := int((clampi(wave, 1, WAVES_PER_STAGE) - 1) / 5.0) + (1 if ch >= 5 else 0)   # w1–5: 0, w6–10: 1, w11–15: 2
	if info.get("boss", false):
		m += 1
	if Game.stage_id.ends_with("-1"):
		m -= 1   # a chapter's first stage introduces its new operator before the armour arrives
	return maxi(0, m)


## The actual function an enemy is made of (base shape × multiplicity armour).
func make_expr(tpl: String, rng: RandomNumberGenerator, wave: int = 15) -> Expr:
	var f := _make_base(tpl, rng, wave)
	var m := armor_power(tpl, wave)
	if m > 0:
		var boss: bool = TEMPLATES[tpl].get("boss", false)
		f.times_x(m if boss else rng.randi_range(0, m))   # a mix of light and heavy; bosses always carry full armour
	return f


func _make_base(tpl: String, rng: RandomNumberGenerator, wave: int = 15) -> Expr:
	var w := clampi(wave, 1, WAVES_PER_STAGE)
	match tpl:
		"n1":
			return Expr.poly([rng.randi_range(1, 9)])
		"n2":
			return Expr.poly([rng.randi_range(10, mini(99, 25 + 6 * w))])
		"even":
			return Expr.poly([2 * rng.randi_range(5, 10 + 8 * w)])
		"n100":
			return Expr.poly([100])
		"sq":
			return Expr.poly([SQUARES[rng.randi_range(0, mini(SQUARES.size() - 1, 3 + w))]])
		"p2":
			return Expr.poly([1 << rng.randi_range(3, mini(10, 4 + int(w / 2.0)))])
		"prime":
			return Expr.poly([PRIMES[rng.randi_range(0, PRIMES.size() - 1)]])
		"big":
			return Expr.poly([BIGS[rng.randi_range(0, mini(BIGS.size() - 1, 1 + int(w / 2.0)))]])
		"bigprime":
			return Expr.poly([[997, 991, 983][rng.randi_range(0, 2)]])
		"k1000":
			return Expr.poly([1000])
		"k10000":
			return Expr.poly([10000])
		"k65536":
			return Expr.poly([65536])
		"k10_6":
			return Expr.poly([1000000])
		"k2_32":
			return Expr.poly([4294967296])
		"x", "x_counter":
			return Expr.poly([0, 1])
		"quart":
			return Expr.poly([rng.randi_range(1, 9), rng.randi_range(0, 2), 0, 0, 1])
		"kx":
			var k: int = [2, 2, 3][rng.randi_range(0, 2)]
			var c := rng.randi_range(1, 4)
			return Expr.poly([k * c, k])
		"xbx":
			return Expr.poly([0, rng.randi_range(1, 6), 1])
		"kxx":
			var k2: int = [2, 2, 3][rng.randi_range(0, 2)]
			return Expr.poly([0, k2 * rng.randi_range(1, 3), k2])
		"sqp":
			var c2 := rng.randi_range(1, 4)
			return Expr.poly([c2 * c2, 2 * c2, 1])
		"x4":
			return Expr.poly([0, 0, 0, 0, 1])
		"sq2":
			var c3 := rng.randi_range(1, 3)
			return Expr.poly([c3 * c3, 0, 2 * c3, 0, 1])
		"boss_alg2":
			return Expr.poly([0, 12, 6])
		"boss_sq":
			return Expr.poly([9, 12, 10, 4, 1])
		"quint":
			return Expr.poly([rng.randi_range(1, 9), 0, rng.randi_range(0, 2), 0, 0, 1])
		"boss_x5":
			return Expr.poly([6, 0, 1, 0, 0, 1])
		"boss_x6":
			return Expr.poly([9, 0, 3, 0, 0, 0, 1])
		"exp_counter":
			return Expr.new().add_exp(1)
		"ex":
			return Expr.new().add_exp(1)
		"xpe":
			return Expr.poly([0, 1]).add_exp(1)
		"boss_chain":
			return Expr.new().add_exp(4, 2, 2)
		"s1", "c1", "s1c", "s2", "c2", "tse", "boss_sc", "boss_s2":
			var amp := 1 + int((w - 1) / 5.0)   # one amplitude per wave, so pairs can cancel
			match tpl:
				"s1":
					return Expr.new().add_trig(0, amp)
				"c1":
					return Expr.new().add_trig(amp, 0)
				"s1c":
					return Expr.poly([rng.randi_range(1, 6)]).add_trig(0, amp)
				"s2":
					return Expr.new().add_trig(0, amp, 0, 0, 2)
				"c2":
					return Expr.new().add_trig(amp, 0, 0, 0, 2)
				"tse":
					return Expr.new().add_trig(0, amp).add_exp(1)
				"boss_sc":
					return Expr.new().add_trig(amp + 2, amp + 2)
			return Expr.poly([5]).add_trig(0, amp + 1, 0, 0, 2)
		"tx_counter":
			return Expr.new().add_trig(0, 1, 0, 1).times_t(0, 1)
		"tsin":
			return Expr.new().add_trig(0, rng.randi_range(1, 4)).times_t(0, 1)
		"exsin_counter":
			return Expr.new().add_trig(0, 1, 0, 1)
		"exs":
			return Expr.new().add_exp(rng.randi_range(2, 4))
		"exc":
			return Expr.poly([rng.randi_range(1, 9)]).add_exp(1)
		"pex":
			return Expr.poly([0, 0, 1]).add_exp(1)
		"xex":
			return Expr.new().add_exp(1, 1)
		"x2ex":
			return Expr.new().add_exp(1, 2)
		"mix3":
			return Expr.poly([rng.randi_range(1, 9), 0, 0, 1]).add_exp(1, 1)
		"mix3b":
			return Expr.poly([9, 0, 0, 2]).add_exp(3)
		"boss_ex1":
			return Expr.poly([4]).add_exp(6)
		"boss_x3ex":
			return Expr.poly([1]).add_exp(1, 3)
		"boss_ex":
			return Expr.poly([5, 0, 0, 1]).add_exp(1, 2)
		"sin_counter":
			return Expr.new().add_trig(0, 8)
		"sin":
			return Expr.new().add_trig(0, rng.randi_range(2, 6))
		"cos":
			return Expr.new().add_trig(rng.randi_range(2, 6), 0)
		"asin":
			return Expr.poly([rng.randi_range(1, 5)]).add_trig(0, rng.randi_range(2, 5))
		"xsin":
			return Expr.new().add_trig(0, rng.randi_range(2, 4), 1)
		"boss_trig":
			return Expr.poly([3, 0, 1]).add_trig(4, 4)
		"acs":
			return Expr.new().add_trig(rng.randi_range(1, 4), rng.randi_range(1, 4))
		"xcos":
			return Expr.new().add_trig(rng.randi_range(2, 4), 0, 1)
		"boss_res":
			return Expr.poly([4]).add_trig(0, 3, 1).add_trig(2, 0, 1)
		"sin2":
			return Expr.new().add_trig(0, rng.randi_range(2, 5), 0, 0, 2)
		"cos2":
			return Expr.new().add_trig(rng.randi_range(2, 5), 0, 0, 0, 2)
		"boss_w2":
			return Expr.poly([3]).add_trig(0, 5, 0, 0, 2).add_trig(0, 5)
		"tex":
			return Expr.new().add_trig(0, rng.randi_range(1, 3)).add_exp(1)
		"tpx":
			return Expr.poly([0, 1]).add_trig(rng.randi_range(1, 3), 0)
		"boss_hy":
			return Expr.poly([5, 0, 1]).add_exp(2).add_trig(0, 3)
		"swarm_counter":
			return Expr.poly([3]).add_trig(0, 3)
		"gen_x3":
			return Expr.poly([0, 0, 0, 1])
		"gen_x4":
			return Expr.poly([0, 0, 0, 0, 1])
		"gen_x5":
			return Expr.poly([9, 0, 0, 0, 0, 1])
		"gen_ex":
			return Expr.new().add_exp(2)
		"gen_sin":
			return Expr.new().add_trig(0, 4)
		"gen_boss":
			return Expr.new().add_exp(3).add_trig(0, 4)
		"pm_ex":
			return Expr.new().add_exp(rng.randi_range(2, 4) * (1 if rng.randf() < 0.5 else -1))
		"pm_n":
			return Expr.poly([rng.randi_range(2, 9) * (1 if rng.randf() < 0.5 else -1)])
		"pm_sin":
			return Expr.new().add_trig(0, rng.randi_range(2, 4) * (1 if rng.randf() < 0.5 else -1))
		"exp2_counter", "e2x":
			return Expr.new().add_exp(1, 0, 2)
		"e2c":
			return Expr.poly([rng.randi_range(1, 6)]).add_exp(1, 0, 2).add_exp(1)
		"exsin":
			return Expr.new().add_trig(0, 1 + int((w - 1) / 5.0), 0, 1)
		"boss_e2":
			return Expr.poly([3]).add_exp(2, 0, 2).add_trig(0, 1, 0, 1)
		"e3x":
			return Expr.new().add_exp(1, 0, 3)
		"xe2x":
			return Expr.new().add_exp(1, 1, 2)
		"boss_e3":
			return Expr.poly([4]).add_exp(1, 0, 3).add_exp(1, 1, 2)
		"tsep_counter":
			return Expr.poly([9, 0, 0, 1]).add_trig(0, 1, 0, 1, 3).times_t(0, 2)
		"sep1":
			return Expr.poly([rng.randi_range(1, 3), 1]).times_t(0, 1)
		"sepx":
			return Expr.poly([0, 0, 1]).times_t(0, 1)
		"sep2":
			return Expr.poly([rng.randi_range(1, 3), 1]).times_t(0, 2)
		"boss_sep":
			return Expr.poly([5, 2, 0, 1]).times_t(0, 1)
		"boss_sep2":
			return Expr.poly([3, 0, 0, 0, 1]).add_exp(1).times_t(0, 2)
		"tsum":
			return Expr.poly([0, 0, 1]).add_term(1, 1, 0, 0, 1)
		"tsum2":
			return Expr.poly([0, 1]).add_exp(1).add_term(3, 0, 0, 0, 1)
		"wave2":
			return Expr.new().add_term(1, 2, 0, 0, 0).add_term(-2, 1, 0, 1, 0).add_term(1, 0, 0, 2, 0)
		"wave3":
			return Expr.new().add_term(1, 3, 0, 0, 0).add_term(-3, 2, 0, 1, 0).add_term(3, 1, 0, 2, 0).add_term(-1, 0, 0, 3, 0)
		"wave_e":
			return Expr.new().add_term(1, 0, 1, 0, 1)
		"wave_l":
			return Expr.new().add_term(1, 2, 0, 0, 0).add_term(2, 1, 0, 1, 0).add_term(1, 0, 0, 2, 0)
		"wave_mix":
			return _make_base("wave2", rng).add_term(1, 0, 1, 0, -1).add_expr(Expr.poly([3]))
		"boss_wave":
			return _make_base("wave3", rng).add_expr(_make_base("wave_l", rng)).add_exp(2)
		"signal_counter":
			return _series([1, 3, 5, 7, 9, 11, 13, 15], 4, false)
		"sig2":
			return Expr.new().add_trig(0, rng.randi_range(2, 4)).add_trig(0, rng.randi_range(1, 3), 0, 0, 3)
		"sig3":
			return Expr.new().add_trig(0, 3).add_trig(0, 2, 0, 0, 2).add_trig(0, 2, 0, 0, 4)
		"sigp":
			return Expr.poly([0, 0, 1]).add_trig(0, rng.randi_range(2, 4), 0, 0, 4)
		"sige":
			return Expr.new().add_exp(1).add_trig(0, 2, 0, 0, 3).add_trig(0, 2, 0, 0, 5)
		"square":
			return _series([1, 3, 5, 7], 4, false)
		"saw":
			return _series([1, 2, 3, 4, 5], 2, true)
		"mod5":
			return Expr.new().add_trig(0, rng.randi_range(1, 3), 0, 1, 5)
		"boss_sig":
			return Expr.poly([0, 0, 1]).add_trig(0, 5).add_trig(0, 5, 0, 0, 3).add_trig(0, 5, 0, 0, 7)
		"boss_square":
			return _series([1, 3, 5, 7, 9, 11, 13], 4, false).add_exp(2)
		"quintic_counter", "root_5":
			return Expr.poly([-1, -1, 0, 0, 0, 1])
		"root_q":
			return Expr.poly([-2, 0, 1])
		"root_c":
			return Expr.poly([-5, -2, 0, 1])
		"root_cyc":
			return Expr.poly([2, -2, 0, 1])
		"root_cos":
			return Expr.poly([0, -1]).add_trig(1, 0)
		"root_ex":
			return Expr.poly([-3]).add_exp(1)
		"godel", "godel_counter":
			return Expr.poly([1])
		"xc":
			return Expr.poly([rng.randi_range(1, 9), 1])
		"lin":
			return Expr.poly([rng.randi_range(1, 9), rng.randi_range(2, 3)])
		"quad":
			return Expr.poly([rng.randi_range(1, 9), rng.randi_range(0, 4), rng.randi_range(1, 2)])
		"cubic":
			return Expr.poly([rng.randi_range(1, 9), rng.randi_range(0, 3), 0, 1])
		_:
			return Expr.poly([7, 0, 0, 0, 1])


## Σ coef/n · sin(nx) over the given n (alternating signs for the sawtooth).
func _series(ns: Array, coef: int, alternating: bool) -> Expr:
	var f := Expr.new()
	for i in ns.size():
		var n: int = ns[i]
		var sgn := -1 if (alternating and i % 2 == 1) else 1
		f.add_trig_q([0, 1], Expr.rn(coef * sgn, n), 0, 0, n)
	return f


func chapter_towers(ch: int) -> Array:
	return CHAPTERS[ch].get("towers", TOWER_ORDER)


func is_numeric_stage(sid: String) -> bool:
	return chapter_of(sid) == 1


func tpl_name(tpl: String) -> String:
	return TEMPLATES.get(tpl, {}).get("name", tpl)


## Pretty label for an x position on the axis (π/2 shows as π/2).
func x_label(x: float) -> String:
	if absf(x - PI / 2.0) < 1e-4:
		return "π/2"
	if absf(x - PI) < 1e-4:
		return "π"
	if absf(x - roundf(x)) < 1e-6:
		return str(int(roundf(x)))
	return "%.2f" % x


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL / 2.0, c.y * CELL + CELL / 2.0)


func draw_text_centered(ci: CanvasItem, text: String, center: Vector2, size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := font.get_ascent(size)
	var desc := font.get_descent(size)
	ci.draw_string(font, Vector2(center.x - w / 2.0, center.y + (asc - desc) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func box(bg: Color, border: Color, margin: float = 6.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.6
	sb.content_margin_bottom = margin * 0.6
	return sb


func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 15
	th.set_stylebox("normal", "Button", box(Color("1c2541"), Color("3a506b")))
	th.set_stylebox("hover", "Button", box(Color("273469"), Color("5bc0be")))
	th.set_stylebox("pressed", "Button", box(Color("2f3e6e"), Color("ffd166")))
	th.set_stylebox("hover_pressed", "Button", box(Color("2f3e6e"), Color("ffd166")))
	th.set_stylebox("disabled", "Button", box(Color("111827"), Color("1f2937")))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color("e0e1dd"))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color("ffd166"))
	th.set_color("font_hover_pressed_color", "Button", Color("ffd166"))
	th.set_color("font_disabled_color", "Button", Color("4b5563"))
	th.set_color("font_color", "Label", Color("e0e1dd"))
	th.set_stylebox("panel", "Panel", box(Color(0.043, 0.075, 0.169, 0.96), Color("1c2541")))
	return th
