class_name Guide
extends RefCounted
## The algorithm guide: short pages, one idea each, opened a few at a time as the player progresses.
## Chapter 4 is the coding tutorial: every stage adds one idea and one tower to program.
##
## Rule: the guide never contains a finished answer. Pages show the tool with code that only
## *looks* (print), and the assignments ("task") have blanks (____) and hints opened one at a time.
##
## Fields: "from" = the stage whose unlocking opens the page, "code" = code to look at (can be opened
## as a file), "task" = an assignment with blanks, "hints" = opened one by one, "try" = what to do next.

const SECTIONS := ["처음 시작", "미분과 D", "다른 타워들", "짝 맞추기 심화", "새 연산자", "도구", "사전"]

const PAGES := [
	# ---------------- 처음 시작 (4-1): Σ 하나만 ----------------
	{"id": "hello", "sec": "처음 시작", "from": "4-1", "title": "편집기 둘러보기",
	"body": "4장부터 타워는 [b]사거리 맨 앞의 적[/b]을 쓸모가 있든 없든 때립니다. 이걸 바꾸는 게 알고리즘입니다.\n\n화면은 세 부분입니다.\n[color=#80deea]왼쪽[/color]  내 파일 목록 (.py)\n[color=#80deea]가운데[/color]  코드\n[color=#80deea]오른쪽[/color]  이 파일을 쓸 타워, 테스트 실행, 콘솔\n\n코드는 고치는 즉시 저장됩니다. 저장 버튼은 없습니다.\n\n4-1에서 코딩할 타워는 [b]Σ 하나[/b]뿐입니다. 천천히 가요.",
	"try": "왼쪽에서 attack.py를 눌러 열어 보세요."},

	{"id": "first", "sec": "처음 시작", "from": "4-1", "title": "첫 줄: attack",
	"body": "타워는 쏠 준비가 될 때마다 파일을 [b]맨 위부터[/b] 실행합니다.\n\n[code]enemies[/code]  사거리 안의 적들. 코어에 가까운 적이 맨 앞([code]enemies[0][/code])입니다.\n[code]attack(e)[/code]  e를 칩니다. 부르는 순간 실행이 끝납니다.\n\n아래 한 줄이 지금 타워들이 하고 있는 일, 그대로입니다.",
	"code": "attack(enemies[0])\n",
	"try": "이 줄이 attack.py의 전부라는 걸 확인해 보세요."},

	{"id": "assign", "sec": "처음 시작", "from": "4-1", "title": "타워에 붙이고 시험하기",
	"body": "파일은 타워에 붙여야 쓰입니다.\n\n1. 게임에서 타워를 클릭하고 [b]E[/b]를 누르면 그 타워의 편집기가 열립니다.\n2. 오른쪽 위 목록에서 파일을 고릅니다.\n3. 「테스트 실행」은 지금 사거리 안의 적들로 한 번 돌려 봅니다. 결과는 콘솔에 나옵니다.\n\n[code]print(…)[/code]로 무엇이든 콘솔에 찍을 수 있습니다. 모르겠으면 일단 찍어 보세요.",
	"code": "for e in enemies:\n    print(e.f)          # 적의 식을 콘솔에 찍기\n",
	"try": "이 코드를 새 파일로 열고, 적이 사거리에 있을 때 「테스트 실행」을 눌러 보세요."},

	{"id": "choose", "sec": "처음 시작", "from": "4-1", "title": "고르기: for와 if",
	"body": "[code]for e in enemies:[/code]는 적을 앞에서부터 하나씩 봅니다.\n[code]if 조건:[/code] 아래 줄은 조건이 참일 때만 실행됩니다.\n\n조건에 맞는 적을 처음 찾는 순간 attack하고 끝납니다. 아무도 못 찾고 파일 끝에 닿으면, 이번엔 [b]쉽니다[/b] (잠시 뒤 다시 실행).\n\n아래는 \"보스만 노리는\" 예입니다.",
	"code": "for e in enemies:\n    if e.boss:\n        attack(e)       # 보스를 처음 찾으면 치고 끝\n",
	"try": "e.boss 대신 다른 조건을 넣으면 무엇을 노리게 될까요?"},

	{"id": "calc", "sec": "처음 시작", "from": "4-1", "title": "식끼리 계산하기",
	"body": "적의 식은 수학처럼 계산할 수 있습니다.\n\n[code]a.f + b.f[/code]  두 식의 합\n[code]a.f + b.f == 0[/code]  그 합이 0인가 (참/거짓)\n\n아래 코드는 사거리 안 적들을 두 명씩 짝지어 합을 콘솔에 찍기만 합니다. attack이 없으니 아무것도 치지 않습니다.",
	"code": "for a in enemies:\n    for b in enemies:\n        print(a.f, \"+\", b.f, \"=\", a.f + b.f)\n",
	"try": "테스트 실행으로 어떤 두 적의 합이 0이 되는지 찾아보세요."},

	{"id": "task_sum", "sec": "처음 시작", "from": "4-1", "title": "과제 ① Σ에게 짝 찾아 주기",
	"body": "Σ 타워는 [code]attack([a, b])[/code]처럼 적 두 명을 주면 [b]그 둘만[/b] 더합니다.\n\n목표: 더해서 0이 되는 두 적을 찾았을 때만 그 둘을 더하게 하기. 빈칸 ____ 하나만 채우면 됩니다.",
	"task": "for a in enemies:\n    for b in enemies:\n        if ____:\n            attack([a, b])\n",
	"hints": ["____ 자리에는 참이나 거짓이 되는 식이 들어갑니다. 앞 페이지에서 합이 0이 나온 쌍을 떠올려 보세요.",
		"합이 0인지 비교할 때는 == 를 씁니다.",
		"a와 b가 같은 적일 때도 반복문이 돕니다. 같은 적끼리는 짝이 아닙니다. 두 조건을 and로 이어 보세요."],
	"try": "완성한 파일을 Σ 타워에 붙이고 4-1을 깨 보세요."},

	# ---------------- 미분과 D (4-2) ----------------
	{"id": "deriv", "sec": "미분과 D", "from": "4-2", "title": "미분해 보기",
	"body": "[code]e.f.derivative()[/code]는 미분한 식입니다. D 타워 한 방을 맞으면 그 적이 이렇게 됩니다.\n\nsin x → cos x → −sin x → −cos x → sin x\n\n미분한 식도 식이라서 다시 미분하거나 더할 수 있습니다.",
	"code": "for e in enemies:\n    d1 = e.f.derivative()\n    print(e.f, \"→\", d1, \"→\", d1.derivative())\n",
	"try": "cos x를 한 번 미분하면 무엇이 되는지 콘솔에서 확인하세요."},

	{"id": "task_d", "sec": "미분과 D", "from": "4-2", "title": "과제 ② D가 짝을 만들게",
	"body": "cos x에게는 −cos x 짝이 오지 않습니다. 하지만 D를 한 번 맞으면 −sin x가 되고, 그러면 sin x의 짝입니다.\n\n목표: [b]D를 맞으면 누군가의 짝이 되는 적[/b]만 쏘게 하기. 이번엔 빈칸 없이 직접 써 봅니다. 과제 ①과 모양이 비슷합니다.",
	"task": "for e in enemies:\n    for o in enemies:\n        # e가 D를 맞은 뒤의 식이 o와 짝이 되면 e를 쏜다\n        ____\n",
	"hints": ["D를 맞은 뒤의 e는 e.f.derivative()입니다. 그것과 o.f를 더해 0인지 보세요.",
		"과제 ①처럼 자기 자신(o == e)은 짝에서 빼야 합니다.",
		"이미 짝이 있는 적을 쏘면 짝이 깨집니다. 쏘기 전에 \"지금 그대로 누군가와 더해 0인가\"도 확인하면 더 좋습니다.",
		"보스(b sin x + b cos x)는 한 번이 아니라 [b]두 번[/b] 미분해야 다른 보스의 짝이 됩니다."],
	"try": "D 타워에 붙이고, Σ 타워(과제 ①)와 함께 4-2를 해 보세요."},

	{"id": "errors", "sec": "미분과 D", "from": "4-2", "title": "버그가 나면",
	"body": "걱정하지 마세요. 버그가 있어도 게임은 멈추지 않고, 타워는 계속 싸웁니다.\n\n[color=#ef9a9a]⚠ 오류[/color]  문법이 틀리거나 실행 중 오류가 나면, 그 타워는 고칠 때까지 [b]기본 동작(맨 앞 적)[/b]으로 싸웁니다. 콘솔에 몇째 줄인지 나옵니다.\n[color=#ffb74d]⏸ 계속 쉬는 중[/color]  오류는 아닌데 적이 있는데도 attack까지 못 가는 경우. 조건이 틀렸을 가능성이 큽니다. [code]print[/code]로 조건 값을 찍어 보세요.\n[color=#80deea]무한 반복[/color]  한 번에 20,000단계를 넘으면 오류로 멈춥니다.\n\n고치고 저장하는 순간 다시 내 알고리즘으로 돌아옵니다.",
	"code": "for e in enemies:\n    print(e.f, e.boss)    # 조건이 왜 거짓인지 보기\n    if e.boss:\n        attack(e)\n"},

	# ---------------- 다른 타워들 (4-3) ----------------
	{"id": "def", "sec": "다른 타워들", "from": "4-3", "title": "내 함수 만들기",
	"body": "자주 묻는 질문은 [code]def[/code]로 이름을 붙이면 코드가 짧고 읽기 쉬워집니다. 이름은 마음대로 지으세요.\n\n[code]return[/code]은 답을 돌려주고 그 함수를 끝냅니다.",
	"code": "def is_trig(e):\n    return e.f.has(\"sin\") or e.f.has(\"cos\")\n\nfor e in enemies:\n    print(e.f, is_trig(e))\n",
	"try": "과제 ①·②에서 반복되는 부분을 함수로 만들어 보세요."},

	{"id": "after", "sec": "다른 타워들", "from": "4-3", "title": "쏘기 전에 미리 보기",
	"body": "4-3부터는 숫자와 x + eˣ도 옵니다. 빼기·로그 같은 다른 타워도 아무나 치면 곤란합니다.\n\n[code]e.after()[/code]는 [b]이 타워[/b]가 e를 한 번 쏜 뒤의 모습입니다. 어느 타워에 붙여도 그 타워의 연산으로 계산합니다.\n[code]a.zero[/code]  0이 되는가\n[code]a.damage[/code]  그 상태로 코어에 닿으면 받는 피해 ([code]e.damage[/code]와 비교)\n\n편하지만 비쌉니다: after() 한 번이 40단계.",
	"code": "for e in enemies:\n    a = e.after()\n    print(e.f, \"→\", a.f, \"0?\", a.zero, \"피해\", e.damage, \"→\", a.damage)\n",
	"task": "for e in enemies:\n    a = e.after()\n    if ____:\n        attack(e)\n",
	"hints": ["쏘고 나서 나아지는 적만 쏘면 됩니다. \"나아진다\"를 a로 어떻게 말할 수 있을까요?",
		"0이 되거나, 코어 피해가 줄어들면 나아진 겁니다. 둘을 or로."],
	"try": "완성하면 빼기·나누기·로그 타워에 「같은 종류 전부」로 붙여 보세요."},

	{"id": "cost", "sec": "다른 타워들", "from": "4-3", "title": "생각에도 시간이 든다",
	"body": "알고리즘이 계산한 만큼 타워가 늦게 쏩니다. 1,000단계 = 0.25초. 타워 정보에 지난번 단계 수가 나옵니다.\n\n적이 많을 때 [code]for[/code] 안의 [code]for[/code]는 금방 비싸집니다. 요령은 둘:\n· 찾자마자 attack (나머지는 안 봄)\n· 한 번 계산한 것은 변수에 담아 두기",
	"try": "내 D 타워의 단계 수를 타워 정보에서 확인해 보세요."},

	# ---------------- 짝 맞추기 심화 (4-4, 4-5) ----------------
	{"id": "terms", "sec": "짝 맞추기 심화", "from": "4-4", "title": "식을 항으로 쪼개기",
	"body": "[code]e.f.terms[/code]는 덧셈으로 나뉜 항들의 리스트입니다.\nsin x + eˣ → [sin x, eˣ]\n\n항 하나하나도 식이라서 똑같이 계산할 수 있습니다. [code]term.coef[/code]는 앞에 붙은 수, [code]term.degree[/code]는 x의 차수.",
	"code": "for e in enemies:\n    for term in e.f.terms:\n        print(term, \"계수\", term.coef)\n",
	"try": "테스트 실행으로 적들이 어떤 항으로 이뤄져 있는지 보세요."},

	{"id": "scale", "sec": "짝 맞추기 심화", "from": "4-4", "title": "크기 맞추기: ÷2",
	"body": "sin 2x를 두 번 미분하면 −4 sin 2x. sin 2x와 더해도 0이 아닙니다: 크기가 4배.\n\n식은 수로 나누거나 곱할 수 있습니다: [code]e.f / 2[/code], [code]3 * e.f[/code]. ÷2 타워를 맞으면 그 적은 [code]e.f / 2[/code]가 됩니다.",
	"code": "for e in enemies:\n    print(e.f, \"→ ÷2 →\", e.f / 2, \"→ ÷2 →\", e.f / 4)\n",
	"hints": ["÷2 타워: 반으로 줄인 식이(또는 두 번 줄인 식이) 누군가와 짝이 되는 적을 쏘게 해 보세요.",
		"D 타워도 손봐야 합니다: 계수가 커진 sin 2x를 계속 미분하면 더 커지기만 합니다. 언제 멈출지 정하세요."],
	"try": "÷2 타워를 코딩해 4-4를 해 보세요."},

	{"id": "mixed", "sec": "짝 맞추기 심화", "from": "4-5", "title": "섞인 적: 항 하나만 지우기",
	"body": "sin x + eˣ는 누구와 더해도 0이 안 됩니다. 하지만 −sin x를 더하면 sin이 사라지고 eˣ만 남습니다. eˣ는 로그가 맡으면 됩니다.\n\n그래서 짝의 뜻을 넓혀 봅니다: 통째로 0이 아니어도, [b]항 하나라도 서로 지워지면[/b] 짝.\n\n아래는 두 적의 항끼리 더한 결과를 보기만 하는 코드입니다.",
	"code": "for a in enemies:\n    for b in enemies:\n        if a != b:\n            for t in a.f.terms:\n                for u in b.f.terms:\n                    print(t, \"+\", u, \"=\", t + u)\n",
	"hints": ["\"항 하나라도 지워지는가\"를 def 함수 하나로 만들어 보세요 (참/거짓을 return).",
		"그 함수를 Σ의 조건에 쓰고, D 코드의 \"더해 0\" 검사 자리에도 바꿔 끼워 보세요."],
	"try": "Σ와 D를 고쳐 4-5를 해 보세요."},

	# ---------------- 새 연산자 (5장~) ----------------
	{"id": "time", "sec": "새 연산자", "from": "5-1", "title": "시간 t와 ∂ₜ − λ",
	"body": "5장부터 식에 시간 t가 들어갑니다. [code]e.f.has(\"t\")[/code]로 알 수 있습니다.\n\n시간 소멸 타워는 t가 없는 적에 쏘면 부호만 뒤집힙니다.",
	"code": "for e in enemies:\n    print(e.f, \"t 있음?\", e.f.has(\"t\"))\n",
	"hints": ["시간 소멸 타워가 누구를 쏴야 할지는 위 콘솔에 답이 있습니다."]},

	{"id": "param", "sec": "새 연산자", "from": "5-2", "title": "타워 설정 바꾸기: set_param",
	"body": "[code]me[/code]는 이 타워 자신입니다. [code]me.param[/code]은 지금 λ (또는 ω).\n[code]set_param(2)[/code]로 바꿉니다 (연구 필요). 바꾼 뒤의 [code]e.after()[/code]는 바뀐 λ로 계산됩니다.",
	"code": "print(\"지금 λ =\", me.param)\nfor e in enemies:\n    print(e.f, \"→\", e.after().f)\n",
	"hints": ["e²ᵗ에는 λ = 2가 맞습니다. 적마다 맞는 λ가 다를 수 있습니다.",
		"λ를 바꿔 가며 after()로 0이 되는지 확인할 수 있습니다."]},

	{"id": "damp", "sec": "새 연산자", "from": "6-1", "title": "감쇠장: 누구에게 걸까",
	"body": "감쇠장은 범위의 함수에 e⁻ˣ를 곱합니다. eˣ sin x에는 좋지만, 상수 1에 걸면 오히려 e⁻ˣ가 생깁니다.\n\n범위 타워도 [code]attack([…])[/code]로 고른 적에게만 겁니다. 리스트는 [code]targets = [][/code]로 만들고 [code]targets.append(e)[/code]로 채웁니다.",
	"code": "for e in enemies:\n    print(e.f, \"→ 감쇠장 →\", e.after().f)\n",
	"hints": ["걸고 나서 나아지는 적만 리스트에 모아, 리스트가 비어 있지 않으면 attack하세요."]},

	# ---------------- 도구 ----------------
	{"id": "external", "sec": "도구", "from": "4-3", "title": "VS Code 같은 외부 편집기",
	"body": "파일은 진짜 .py 파일입니다. 좋아하는 편집기로 고쳐도 됩니다.\n\n1. 「VS Code로 열기」 (또는 「폴더 열기」)를 누릅니다.\n2. [b]폴더째[/b] 여세요. 폴더의 __builtins__.pyi 덕분에 enemies, attack, e.f.derivative() 같은 이름이 자동완성됩니다.\n3. 저장하면 게임이 바로 알아채고 다시 읽습니다. 게임 안 편집기도 따라 바뀝니다.\n\n진행 상황은 게임이 따로 자동 저장합니다."},

	# ---------------- 사전 (언제든 찾아보기) ----------------
	{"id": "ref_enemy", "sec": "사전", "from": "4-1", "title": "적 e",
	"body": "[code]e.f[/code]  식\n[code]e.value[/code]  코어에서의 값\n[code]e.damage[/code]  코어에 닿으면 받는 피해\n[code]e.after()[/code]  이 타워가 한 번 쏜 뒤 (40단계)\n[code]e.zero[/code]  after() 결과가 0인가\n[code]e.progress[/code]  진행도 0–1\n[code]e.x  e.dist  e.speed[/code]  위치·타워와의 거리·속도\n[code]e.boss  e.members  e.name[/code]"},

	{"id": "ref_func", "sec": "사전", "from": "4-1", "title": "식 f",
	"body": "[code]f + g   f - g   -f[/code]  식의 덧셈·뺄셈\n[code]2 * f   f / 2[/code]  수배\n[code]f == g   f == 0[/code]  같은가 / 0인가\n[code]f.derivative()[/code]  미분 ([code]derivative(f)[/code]도 같음)\n[code]f.at(3)[/code]  x = 3에서의 값\n[code]f.terms[/code]  항들     [code]f.factors[/code]  곱의 인수들\n[code]f.coef[/code]  계수     [code]f.degree[/code]  x의 차수\n[code]f.inner[/code]  sin(2x) → 2x\n[code]f.has(\"sin\")[/code]  종류: \"sin\" \"cos\" \"exp\" \"x\" \"t\"\n[code]f.is_number   f.is_zero[/code]\n[code]print(f)[/code]  식 출력"},

	{"id": "ref_tower", "sec": "사전", "from": "4-1", "title": "타워 me와 전역",
	"body": "[code]me.op  me.name  me.level  me.param  me.range[/code]\n[code]set_param(v)[/code]  λ·ω 바꾸기 (연구 필요)\n[code]attack(e)   attack([a, b])[/code]  치고 끝\n[code]wave  rho  integrity[/code]  웨이브·자원·코어 체력"},

	{"id": "ref_python", "sec": "사전", "from": "4-1", "title": "쓸 수 있는 파이썬",
	"body": "[code]if / elif / else   for   while   def   return   break   continue   lambda[/code]\n리스트, 리스트 컴프리헨션 [code][e for e in enemies if e.boss][/code]\n[code]print len range min max abs sorted sum any all int float str round list enumerate zip reversed[/code]\nmin·max·sorted는 [code]key=[/code], min·max는 [code]default=[/code]"},
]


static func page(id: String) -> Dictionary:
	for p in PAGES:
		if p["id"] == id:
			return p
	return {}


static func is_open(p: Dictionary) -> bool:
	return Progress.dev_mode or Progress.stage_unlocked(p["from"]) or Game.stage_id == p["from"]


## Pages the player can read now, in order.
static func open_pages() -> Array:
	var out: Array = []
	for p in PAGES:
		if is_open(p):
			out.append(p)
	return out


## The first page that is still closed (shown as a teaser), or {}.
static func next_locked() -> Dictionary:
	for p in PAGES:
		if not is_open(p):
			return p
	return {}


## Unread lesson (the 사전 is for looking things up: never "new", never pushed at the player).
static func is_new(p: Dictionary) -> bool:
	return p["sec"] != "사전" and not Progress.guide_read.has(p["id"])


static func unread_count() -> int:
	var n := 0
	for p in open_pages():
		if is_new(p):
			n += 1
	return n


static func matches(p: Dictionary, q: String) -> bool:
	if q == "":
		return true
	q = q.to_lower()
	for k in ["title", "body", "code", "task", "sec"]:
		if String(p.get(k, "")).to_lower().contains(q):
			return true
	for h in p.get("hints", []):
		if String(h).to_lower().contains(q):
			return true
	return false
