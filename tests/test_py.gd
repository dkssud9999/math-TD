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
	var vm := run("def attack(es):\n    return [e * 2 for e in es]")
	checks += 1
	var r = vm.run_fn("attack", [[1, 2]])
	if not (r is Array and r == [2, 4]):
		fails += 1
		print("FAIL: run_fn returned %s" % str(r))
	print("python checks: %d, failures: %d" % [checks, fails])
	quit(1 if fails > 0 else 0)
