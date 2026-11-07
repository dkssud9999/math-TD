extends SceneTree
## Checks the in-game Python interpreter against what real Python prints.
## godot --headless --path . --script res://tests/test_py.gd

var checks := 0
var fails := 0


func run(src: String) -> PyVM:
	var vm := PyVM.new()
	vm.load_source(src)
	return vm


func out(src: String) -> String:
	var vm := run(src)
	if vm.err != "":
		return "ERR " + vm.error_text()
	return "\n".join(vm.output)


func expect(src: String, want: String, name: String) -> void:
	checks += 1
	var got := out(src)
	if got != want:
		fails += 1
		print("FAIL: %s\n  want: %s\n  got:  %s" % [name, want.replace("\n", " | "), got.replace("\n", " | ")])


func expect_err(src: String, needle: String, name: String) -> void:
	checks += 1
	var got := out(src)
	if not got.begins_with("ERR") or not got.contains(needle):
		fails += 1
		print("FAIL: %s\n  want error containing: %s\n  got: %s" % [name, needle, got])


## A VM whose `import name` reads mods[name] (stands in for the player's script folder).
func out_mods(src: String, mods: Dictionary) -> String:
	var vm := PyVM.new()
	vm.module_sources = mods
	vm.load_source(src)
	if vm.err != "":
		return "ERR " + vm.error_text()
	return "\n".join(vm.output)


func expect_mods(src: String, mods: Dictionary, want: String, name: String) -> void:
	checks += 1
	var got := out_mods(src, mods)
	var ok := got == want if not want.begins_with("ERR~") else (got.begins_with("ERR") and got.contains(want.substr(4)))
	if not ok:
		fails += 1
		print("FAIL: %s\n  want: %s\n  got:  %s" % [name, want.replace("\n", " | "), got.replace("\n", " | ")])


func _init() -> void:
	expect("print(1 + 2 * 3, 7 // 2, -7 // 2, 7 % 3, -7 % 3, 2 ** 10)", "7 3 -4 1 2 1024", "arithmetic")
	expect("print(7 / 2, 6 / 3)", "3.5 2.0", "true division")
	expect("x = 5\nx += 3\nx *= 2\nprint(x)", "16", "augmented assignment")
	expect("print(1 < 2 < 3, 3 < 2 < 4, 2 == 2.0, 'a' in 'cat', 3 not in [1, 2])", "True False True True True", "comparisons")
	expect("print(not 0, 0 or 5, 3 and 4, None or 'x')", "True 5 4 x", "boolean ops")
	expect("print([x * x for x in range(5) if x % 2 == 0])", "[0, 4, 16]", "list comprehension")
	expect("print([(i, j) for i in range(2) for j in range(2)])", "[[0, 0], [0, 1], [1, 0], [1, 1]]", "nested comprehension (tuples are lists)")
	expect("print(sum(x for x in range(4)), any(x > 2 for x in [1, 3]), all([]))", "6 True True", "generator args")
	expect("print(max([3, 9, 2]), min(4, 1, 8), max(['aa', 'b'], key=len))", "9 1 aa", "min/max")
	expect("print(sorted([3, 1, 2]), sorted([3, 1, 2], reverse=True), sorted(['bb', 'a', 'ccc'], key=lambda s: len(s)))", "[1, 2, 3] [3, 2, 1] ['a', 'bb', 'ccc']", "sorted")
	expect("print(max([], default=None))", "None", "max default")
	expect("def f(n):\n    if n < 2:\n        return n\n    return f(n - 1) + f(n - 2)\nprint(f(10))", "55", "recursion")
	expect("def add(a, b=10):\n    return a + b\nprint(add(1), add(1, 2), add(a=3))", "11 3 13", "defaults and keywords")
	expect("def mk(k):\n    return lambda x: x + k\ng = mk(5)\nprint(g(1))", "6", "closure")
	expect("n = 0\ndef bump():\n    global n\n    n += 1\nbump()\nbump()\nprint(n)", "2", "global")
	expect("i = 0\nwhile True:\n    i += 1\n    if i == 3:\n        continue\n    if i > 5:\n        break\nprint(i)", "6", "while/break/continue")
	expect("for i, v in enumerate(['a', 'b']):\n    print(i, v)", "0 a\n1 b", "enumerate unpack")
	expect("a, b = 1, 2\na, b = b, a\nprint(a, b)", "2 1", "tuple swap")
	expect("xs = [1, 2, 3]\nxs.append(4)\nprint(xs[-1], xs[1:3], len(xs), xs.pop(), xs)", "4 [2, 3] 4 4 [1, 2, 3]", "list methods")
	expect("s = 'Hello'\nprint(s.lower(), s[1], s[-2:], s.startswith('He'), ','.join(['a', 'b']))", "hello e lo True a,b", "strings")
	expect("print(1 if 2 > 1 else 0, abs(-3), round(2.567, 2), int(3.9), str(5) + '!')", "1 3 2.57 3 5!", "misc builtins")
	expect("if 1: print('inline')", "inline", "inline block")
	expect("x = [\n    1,\n    2,\n]\nprint(x)", "[1, 2]", "multi-line brackets")
	expect("print(list(zip([1, 2], ['a', 'b'])), list(reversed([1, 2, 3])))", "[[1, 'a'], [2, 'b']] [3, 2, 1]", "zip/reversed")
	expect("# comment only\n\nprint('ok')  # trailing", "ok", "comments")
	expect_err("print(1 / 0)", "0으로 나눌 수 없습니다", "zero division")
	expect_err("while True:\n    pass", "무한 루프", "step limit")
	expect_err("print(y)", "'y'", "undefined name")
	expect_err("def f(:\n    pass", "줄 1", "syntax error line")
	expect_err("if True:\nprint(1)", "들여쓴 블록", "missing indent")
	expect_err("x = 1\n  y = 2", "줄 2", "bad indent")
	expect_err("print([1][5])", "범위", "index error")
	expect_err("print(1 < 'a')", "비교", "type compare")
	# ---- issue #13: class / dict / import (expected values are what CPython prints) ----
	expect("class P:\n    def __init__(self, x, y=2):\n        self.x = x\n        self.y = y\n    def total(self):\n        return self.x + self.y\n    def double(self):\n        return self.total() * 2\np = P(3)\np.y += 4\nprint(p.x, p.y, p.total(), p.double())", "3 6 9 18", "class: init, attrs, methods calling methods")
	expect("class C:\n    n = 0\n    def inc(self):\n        C.n += 1\n        return C.n\na = C()\nb = C()\na.inc()\nprint(b.inc(), C.n, a.n)", "2 2 2", "class attribute shared")
	expect("class A:\n    def hi(self):\n        return 'A' + self.name()\n    def name(self):\n        return 'a'\nclass B(A):\n    def name(self):\n        return 'b'\nx = B()\nprint(x.hi(), isinstance(x, A), isinstance(x, B), isinstance(A(), B))", "Ab True True False", "inheritance + isinstance")
	expect("class V:\n    def __init__(self, k):\n        self.k = k\n    def __str__(self):\n        return 'V' + str(self.k)\nprint(V(4), [V(1)] == [V(1)])", "V4 False", "__str__ and identity equality")
	expect("class Q:\n    def __init__(self):\n        self.items = []\n    def add(self, v):\n        self.items.append(v)\nq = Q()\nf = q.add\nf(1)\nf(2)\nprint(q.items, len(q.items))", "[1, 2] 2", "bound method stored and called")
	expect_err("class Z:\n    pass\nz = Z()\nprint(z.nope)", "nope", "missing attribute")
	expect_err("class Z:\n    pass\nZ(1)", "인자", "no __init__ but args")
	expect("d = {'a': 1, 'b': [1, 2]}\nd['c'] = 3\nd['a'] += 10\nprint(d, len(d), 'b' in d, 'z' in d, d.get('z'), d.get('z', 0))", "{'a': 11, 'b': [1, 2], 'c': 3} 3 True False None 0", "dict basics")
	expect("d = {}\nfor w in ['x', 'y', 'x']:\n    d[w] = d.get(w, 0) + 1\nprint(d, list(d.keys()), list(d.values()), sorted(d))", "{'x': 2, 'y': 1} ['x', 'y'] [2, 1] ['x', 'y']", "dict counting")
	expect("d = {1: 'a', 2: 'b'}\nfor k, v in d.items():\n    print(k, v)\nprint(d.pop(1), d, d.pop(9, 'none'))", "1 a\n2 b\na {2: 'b'} none", "dict items/pop")
	expect("d = dict(a=1)\nd.update({'b': 2})\ne = d.copy()\ne['a'] = 5\nprint(d, e, d == {'b': 2, 'a': 1}, {} or 'empty')", "{'a': 1, 'b': 2} {'a': 5, 'b': 2} True empty", "dict update/copy/eq/truthiness")
	expect_err("d = {}\nprint(d['x'])", "키", "missing key")
	expect_err("d = {[1]: 2}\nd[{}] = 1", "키", "unhashable key")
	expect_mods("import helpers\nprint(helpers.twice(4), helpers.K)", {"helpers": "K = 7\ndef twice(x):\n    return 2 * x\n"}, "8 7", "import module")
	expect_mods("import helpers as h\nfrom helpers import twice as t, K\nprint(h.twice(1), t(5), K)", {"helpers": "K = 7\ndef twice(x):\n    return 2 * x\n"}, "2 10 7", "import as / from import")
	expect_mods("from shapes import Box\nb = Box(3)\nprint(b.area())", {"shapes": "class Box:\n    def __init__(self, s):\n        self.s = s\n    def area(self):\n        return sq(self.s)\ndef sq(v):\n    return v * v\n"}, "9", "class from a module uses its module's names")
	expect_mods("import counter\ncounter.bump()\ncounter.bump()\nprint(counter.n)", {"counter": "n = 0\ndef bump():\n    global n\n    n += 1\n"}, "2", "global inside a module writes the module")
	expect_mods("import a", {"a": "import b\n", "b": "import a\n"}, "ERR~순환", "circular import")
	expect_mods("import nothere", {}, "ERR~없습니다", "missing module")
	expect_mods("import os", {}, "ERR~os", "refused module")
	expect_mods("import bad", {"bad": "def f(:\n"}, "ERR~bad.py", "syntax error inside module")
	expect_mods("import boom\n", {"boom": "x = 1\ny = [][3]\n"}, "ERR~boom.py 줄 2", "runtime error inside module names file and line")
	expect_mods("import math\nfrom math import sqrt\nprint(sqrt(16), math.floor(2.7), round(math.pi, 3))", {}, "4.0 2 3.142", "math module")
	expect_err("import a.b", "점", "dotted module name")
	expect_err("from a import *", "import *", "star import")
	var vm := run("def attack(es):\n    return [e * 2 for e in es]")
	checks += 1
	var r = vm.run_fn("attack", [[1, 2]])
	if not (r is Array and r == [2, 4]):
		fails += 1
		print("FAIL: run_fn returned %s" % str(r))
	print("python checks: %d, failures: %d" % [checks, fails])
	quit(1 if fails > 0 else 0)
