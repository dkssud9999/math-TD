class_name PyVM
extends RefCounted
## A small Python interpreter for the towers' attack algorithms (attack.py).
## Supports: def / lambda / return, if-elif-else, for, while, break, continue, pass, global,
## list comprehensions (also inside calls: any(e.boss for e in es)), ternary, chained comparisons,
## int / float / str / bool / None / list (tuples are lists), slicing, and common builtins.
## Every run has a step budget, so an infinite loop is an error instead of a frozen game.
##
## Values: Python objects are plain Variants. Host objects (enemies, the tower) are Dictionaries
## {"__obj": kind, ...}; the host resolves their attributes and methods:
##     host.py_attr(obj, name, vm) -> Variant          (set vm.fail(...) on error)
##     host.py_call(obj, name, args, kwargs, vm) -> Variant

const KEYWORDS := ["def", "return", "if", "elif", "else", "for", "while", "in", "not", "and", "or", "is",
	"break", "continue", "pass", "lambda", "True", "False", "None", "global"]
const MAX_DEPTH := 60
const MAX_OUTPUT := 200

var err: String = ""
var err_line: int = 0
var steps: int = 0
var step_limit: int = 20000
var host = null
var globals_env: Dictionary = {"vars": {}, "parent": null, "globals": {}}
var output: PackedStringArray = []

var _toks: Array = []
var _pos: int = 0
var _line: int = 0
var _ret = null
var _depth: int = 0

const C_NORMAL := 0
const C_BREAK := 1
const C_CONTINUE := 2
const C_RETURN := 3
const C_ERROR := 4


# ======================= public =======================

## Parse and run the top level (defines functions and globals). Returns false on a syntax or runtime error.
func load_source(src: String) -> bool:
	err = ""
	_toks = _tokenize(src)
	if err != "":
		return false
	_pos = 0
	var prog: Array = []
	while _peek()["t"] != "EOF":
		if _peek()["t"] == "NEWLINE":
			_pos += 1
			continue
		var st = _statement()
		if err != "":
			return false
		prog.append(st)
	steps = 0
	_exec_block(prog, globals_env)
	return err == ""


## Break the reference cycles (functions hold their defining scope; the host holds this VM).
func dispose() -> void:
	globals_env["vars"].clear()
	host = null


func has_function(name: String) -> bool:
	var v = globals_env["vars"].get(name, null)
	return v is Dictionary and v.has("__fn")


## Call a global function with a fresh step budget.
func run_fn(name: String, args: Array):
	err = ""
	steps = 0
	_depth = 0
	if not has_function(name):
		fail("함수 %s()가 없습니다. def %s(enemies): 를 만들어 주세요." % [name, name])
		return null
	return _call_value(globals_env["vars"][name], args, {})


func set_global(name: String, v) -> void:
	globals_env["vars"][name] = v


func fail(msg: String) -> void:
	if err == "":
		err = msg
		err_line = _line


func error_text() -> String:
	return ("줄 %d: %s" % [err_line, err]) if err_line > 0 else err


func emit(s: String) -> void:
	if output.size() < MAX_OUTPUT:
		output.append(s)


# ======================= tokenizer =======================

func _tok(t: String, v, l: int) -> Dictionary:
	return {"t": t, "v": v, "l": l}


static func _is_ident_start(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_" or c.unicode_at(0) > 127


static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


func _tokenize(src: String) -> Array:
	var out: Array = []
	var stack: Array = [0]
	var depth := 0
	var lines := src.replace("\r", "").split("\n")
	for li in lines.size():
		var ln: int = li + 1
		var s: String = lines[li]
		var i := 0
		if depth == 0:
			var ind := 0
			while i < s.length() and (s[i] == " " or s[i] == "\t"):
				ind += 4 if s[i] == "\t" else 1
				i += 1
			if i >= s.length() or s[i] == "#":
				continue
			if ind > stack[-1]:
				stack.append(ind)
				out.append(_tok("INDENT", null, ln))
			else:
				while ind < stack[-1]:
					stack.pop_back()
					out.append(_tok("DEDENT", null, ln))
				if ind != stack[-1]:
					err = "줄 %d: 들여쓰기가 위 줄들과 맞지 않습니다" % ln
					return []
		while i < s.length():
			var c: String = s[i]
			if c == " " or c == "\t":
				i += 1
			elif c == "#":
				break
			elif _is_digit(c) or (c == "." and i + 1 < s.length() and _is_digit(s[i + 1])):
				var j := i
				var is_float := false
				while j < s.length() and (_is_digit(s[j]) or s[j] == "." or s[j] == "_" or ((s[j] == "e" or s[j] == "E") and j > i)):
					if s[j] == "." or s[j] == "e" or s[j] == "E":
						is_float = true
						if (s[j] == "e" or s[j] == "E") and j + 1 < s.length() and (s[j + 1] == "-" or s[j + 1] == "+"):
							j += 1
					j += 1
				var txt := s.substr(i, j - i).replace("_", "")
				out.append(_tok("NUM", txt.to_float() if is_float else txt.to_int(), ln))
				i = j
			elif _is_ident_start(c):
				var j := i
				while j < s.length() and (_is_ident_start(s[j]) or _is_digit(s[j])):
					j += 1
				out.append(_tok("NAME", s.substr(i, j - i), ln))
				i = j
			elif c == "\"" or c == "'":
				var j := i + 1
				var acc := ""
				var closed := false
				while j < s.length():
					var d: String = s[j]
					if d == "\\" and j + 1 < s.length():
						var e: String = s[j + 1]
						acc += {"n": "\n", "t": "\t", "\\": "\\", "'": "'", "\"": "\""}.get(e, "\\" + e)
						j += 2
						continue
					if d == c:
						closed = true
						break
					acc += d
					j += 1
				if not closed:
					err = "줄 %d: 문자열이 닫히지 않았습니다" % ln
					return []
				if not out.is_empty() and out[-1]["t"] == "STR":
					out[-1]["v"] += acc   # "a" "b" → "ab"
				else:
					out.append(_tok("STR", acc, ln))
				i = j + 1
			else:
				var three := s.substr(i, 3)
				var two := s.substr(i, 2)
				if three in ["**=", "//="]:
					out.append(_tok("OP", three, ln))
					i += 3
				elif two in ["**", "//", "==", "!=", "<=", ">=", "+=", "-=", "*=", "/=", "%=", "->"]:
					out.append(_tok("OP", two, ln))
					i += 2
				elif c in "+-*/%<>=()[]{},:.":
					if c in "([{":
						depth += 1
					elif c in ")]}":
						depth = maxi(0, depth - 1)
					out.append(_tok("OP", c, ln))
					i += 1
				else:
					err = "줄 %d: 알 수 없는 문자 '%s'" % [ln, c]
					return []
		if depth == 0 and not out.is_empty() and out[-1]["t"] not in ["NEWLINE", "INDENT", "DEDENT"]:
			out.append(_tok("NEWLINE", null, ln))
	var last: int = lines.size()
	if not out.is_empty() and out[-1]["t"] != "NEWLINE":
		out.append(_tok("NEWLINE", null, last))
	while stack.size() > 1:
		stack.pop_back()
		out.append(_tok("DEDENT", null, last))
	out.append(_tok("EOF", null, last))
	return out


# ======================= parser =======================

func _peek(o: int = 0) -> Dictionary:
	return _toks[mini(_pos + o, _toks.size() - 1)]


func _is(t: String, v = null, o: int = 0) -> bool:
	var k := _peek(o)
	return k["t"] == t and (v == null or k["v"] == v)


func _is_op(v: String, o: int = 0) -> bool:
	return _is("OP", v, o)


func _is_kw(v: String, o: int = 0) -> bool:
	return _is("NAME", v, o)


func _next() -> Dictionary:
	var k := _peek()
	_pos = mini(_pos + 1, _toks.size() - 1)
	return k


func _expect_op(v: String) -> void:
	if not _is_op(v):
		_syntax("'%s'가 필요합니다" % v)
		return
	_next()


func _syntax(msg: String) -> void:
	if err == "":
		var k := _peek()
		var got: String = "줄 끝" if k["t"] == "NEWLINE" else ("파일 끝" if k["t"] == "EOF" else str(k["v"]))
		err = "줄 %d: 문법 오류 — %s (만난 것: %s)" % [k["l"], msg, got]


func _expect_name() -> String:
	if not _is("NAME") or _peek()["v"] in KEYWORDS:
		_syntax("이름이 필요합니다")
		return ""
	return _next()["v"]


func _block() -> Array:
	_expect_op(":")
	if err != "":
		return []
	var body: Array = []
	if _is("NEWLINE"):
		_next()
		if not _is("INDENT"):
			_syntax("들여쓴 블록이 필요합니다")
			return []
		_next()
		while not _is("DEDENT") and not _is("EOF"):
			if _is("NEWLINE"):
				_next()
				continue
			body.append(_statement())
			if err != "":
				return []
		if _is("DEDENT"):
			_next()
	else:
		body.append(_simple_statement())
		if _is("NEWLINE"):
			_next()
	return body


func _statement() -> Dictionary:
	var l: int = _peek()["l"]
	if _is_kw("def"):
		_next()
		var name := _expect_name()
		_expect_op("(")
		var params: Array = []
		var defaults: Array = []
		while not _is_op(")") and err == "":
			params.append(_expect_name())
			if _is_op("="):
				_next()
				defaults.append(_test())
			else:
				defaults.append(null)
			if _is_op(","):
				_next()
			elif not _is_op(")"):
				_syntax("',' 또는 ')'가 필요합니다")
		_expect_op(")")
		if _is_op("->"):
			_next()
			_test()
		var body := _block()
		return {"k": "def", "l": l, "name": name, "params": params, "defaults": defaults, "body": body}
	if _is_kw("if"):
		_next()
		var branches: Array = []
		var cond = _test()
		branches.append([cond, _block()])
		var other: Array = []
		while _is_kw("elif") and err == "":
			_next()
			var c2 = _test()
			branches.append([c2, _block()])
		if _is_kw("else"):
			_next()
			other = _block()
		return {"k": "if", "l": l, "branches": branches, "else": other}
	if _is_kw("while"):
		_next()
		var cond = _test()
		return {"k": "while", "l": l, "cond": cond, "body": _block()}
	if _is_kw("for"):
		_next()
		var target := _target_list()
		if not _is_kw("in"):
			_syntax("'in'이 필요합니다")
			return {}
		_next()
		var it = _test_list()
		return {"k": "for", "l": l, "target": target, "iter": it, "body": _block()}
	var st := _simple_statement()
	if _is("NEWLINE"):
		_next()
	elif not _is("EOF") and not _is("DEDENT") and err == "":
		_syntax("한 줄에 문장 하나만 쓸 수 있습니다")
	return st


func _target_list() -> Array:
	var names: Array = []
	var paren := false
	if _is_op("("):
		_next()
		paren = true
	names.append(_expect_name())
	while _is_op(","):
		_next()
		names.append(_expect_name())
	if paren:
		_expect_op(")")
	return names


func _simple_statement() -> Dictionary:
	var l: int = _peek()["l"]
	if _is_kw("return"):
		_next()
		if _is("NEWLINE") or _is("EOF") or _is("DEDENT"):
			return {"k": "return", "l": l, "v": null}
		return {"k": "return", "l": l, "v": _test_list()}
	if _is_kw("pass"):
		_next()
		return {"k": "pass", "l": l}
	if _is_kw("break"):
		_next()
		return {"k": "break", "l": l}
	if _is_kw("continue"):
		_next()
		return {"k": "continue", "l": l}
	if _is_kw("global"):
		_next()
		var names: Array = [_expect_name()]
		while _is_op(","):
			_next()
			names.append(_expect_name())
		return {"k": "global", "l": l, "names": names}
	var e = _test_list()
	if _is_op("="):
		var targets: Array = [e]
		var value = null
		while _is_op("="):
			_next()
			value = _test_list()
			targets.append(value)
		targets.pop_back()
		for tg in targets:
			if not _assignable(tg):
				_syntax("여기에는 대입할 수 없습니다")
		return {"k": "assign", "l": l, "targets": targets, "v": value}
	for aop in ["+=", "-=", "*=", "/=", "//=", "%=", "**="]:
		if _is_op(aop):
			_next()
			if not _assignable(e) or e["k"] == "tuple":
				_syntax("여기에는 대입할 수 없습니다")
			var rhs = _test_list()
			return {"k": "augassign", "l": l, "target": e, "op": aop.substr(0, aop.length() - 1), "v": rhs}
	return {"k": "expr", "l": l, "v": e}


func _assignable(e: Dictionary) -> bool:
	if e["k"] == "name" or e["k"] == "index":
		return true
	if e["k"] == "tuple":
		for x in e["items"]:
			if x["k"] != "name":
				return false
		return true
	return false


## a, b, c  → tuple; a single expression otherwise
func _test_list() -> Dictionary:
	var l: int = _peek()["l"]
	var first := _test()
	if not _is_op(","):
		return first
	var items: Array = [first]
	while _is_op(","):
		_next()
		if _is("NEWLINE") or _is_op("=") or _is_op(")") or _is_op(":"):
			break
		items.append(_test())
	return {"k": "tuple", "l": l, "items": items}


func _test() -> Dictionary:
	var l: int = _peek()["l"]
	if _is_kw("lambda"):
		_next()
		var params: Array = []
		while not _is_op(":") and err == "":
			params.append(_expect_name())
			if _is_op(","):
				_next()
		_expect_op(":")
		var body := _test()
		return {"k": "lambda", "l": l, "params": params, "body": body}
	var e := _or()
	if _is_kw("if") and err == "":
		_next()
		var cond := _or()
		if not _is_kw("else"):
			_syntax("조건식에는 'else'가 필요합니다")
			return e
		_next()
		var other := _test()
		return {"k": "ternary", "l": l, "cond": cond, "a": e, "b": other}
	return e


func _or() -> Dictionary:
	var l: int = _peek()["l"]
	var e := _and()
	while _is_kw("or") and err == "":
		_next()
		e = {"k": "or", "l": l, "a": e, "b": _and()}
	return e


func _and() -> Dictionary:
	var l: int = _peek()["l"]
	var e := _not()
	while _is_kw("and") and err == "":
		_next()
		e = {"k": "and", "l": l, "a": e, "b": _not()}
	return e


func _not() -> Dictionary:
	var l: int = _peek()["l"]
	if _is_kw("not"):
		_next()
		return {"k": "not", "l": l, "a": _not()}
	return _comparison()


func _comparison() -> Dictionary:
	var l: int = _peek()["l"]
	var first := _arith()
	var ops: Array = []
	var rest: Array = []
	while err == "":
		var op := ""
		if _is("OP") and _peek()["v"] in ["<", ">", "==", "!=", "<=", ">="]:
			op = _next()["v"]
		elif _is_kw("in"):
			_next()
			op = "in"
		elif _is_kw("not") and _is_kw("in", 1):
			_next()
			_next()
			op = "not in"
		elif _is_kw("is"):
			_next()
			op = "is"
			if _is_kw("not"):
				_next()
				op = "is not"
		else:
			break
		ops.append(op)
		rest.append(_arith())
	if ops.is_empty():
		return first
	return {"k": "compare", "l": l, "first": first, "ops": ops, "rest": rest}


func _arith() -> Dictionary:
	var l: int = _peek()["l"]
	var e := _term()
	while (_is_op("+") or _is_op("-")) and err == "":
		var op: String = _next()["v"]
		e = {"k": "bin", "l": l, "op": op, "a": e, "b": _term()}
	return e


func _term() -> Dictionary:
	var l: int = _peek()["l"]
	var e := _factor()
	while (_is_op("*") or _is_op("/") or _is_op("//") or _is_op("%")) and err == "":
		var op: String = _next()["v"]
		e = {"k": "bin", "l": l, "op": op, "a": e, "b": _factor()}
	return e


func _factor() -> Dictionary:
	var l: int = _peek()["l"]
	if _is_op("-") or _is_op("+"):
		var op: String = _next()["v"]
		return {"k": "unary", "l": l, "op": op, "a": _factor()}
	return _power()


func _power() -> Dictionary:
	var l: int = _peek()["l"]
	var e := _postfix()
	if _is_op("**"):
		_next()
		return {"k": "bin", "l": l, "op": "**", "a": e, "b": _factor()}
	return e


func _postfix() -> Dictionary:
	var e := _atom()
	while err == "":
		var l: int = _peek()["l"]
		if _is_op("("):
			_next()
			var args: Array = []
			var kwargs: Dictionary = {}
			while not _is_op(")") and err == "":
				if _is("NAME") and _is_op("=", 1):
					var kn: String = _next()["v"]
					_next()
					kwargs[kn] = _test()
				else:
					var a := _test()
					if _is_kw("for"):
						a = _comprehension(a, l)
					args.append(a)
				if _is_op(","):
					_next()
				elif not _is_op(")"):
					_syntax("',' 또는 ')'가 필요합니다")
			_expect_op(")")
			e = {"k": "call", "l": l, "f": e, "args": args, "kwargs": kwargs}
		elif _is_op("["):
			_next()
			var lo = null
			var hi = null
			var is_slice := false
			if not _is_op(":"):
				lo = _test()
			if _is_op(":"):
				_next()
				is_slice = true
				if not _is_op("]"):
					hi = _test()
			_expect_op("]")
			if is_slice:
				e = {"k": "slice", "l": l, "a": e, "lo": lo, "hi": hi}
			else:
				e = {"k": "index", "l": l, "a": e, "i": lo}
		elif _is_op("."):
			_next()
			e = {"k": "attr", "l": l, "a": e, "name": _expect_name()}
		else:
			break
	return e


func _comprehension(elt: Dictionary, l: int) -> Dictionary:
	var clauses: Array = []
	while _is_kw("for") and err == "":
		_next()
		var target := _target_list()
		if not _is_kw("in"):
			_syntax("'in'이 필요합니다")
			break
		_next()
		var it := _or()
		var conds: Array = []
		while _is_kw("if") and err == "":
			_next()
			conds.append(_or())
		clauses.append({"target": target, "iter": it, "conds": conds})
	return {"k": "comp", "l": l, "elt": elt, "clauses": clauses}


func _atom() -> Dictionary:
	var k := _peek()
	var l: int = k["l"]
	if k["t"] == "NUM":
		_next()
		return {"k": "const", "l": l, "v": k["v"]}
	if k["t"] == "STR":
		_next()
		return {"k": "const", "l": l, "v": k["v"]}
	if k["t"] == "NAME":
		var nm: String = k["v"]
		if nm == "True" or nm == "False" or nm == "None":
			_next()
			return {"k": "const", "l": l, "v": true if nm == "True" else (false if nm == "False" else null)}
		if nm in KEYWORDS:
			_syntax("여기에 '%s'를 쓸 수 없습니다" % nm)
			return {"k": "const", "l": l, "v": null}
		_next()
		return {"k": "name", "l": l, "name": nm}
	if _is_op("("):
		_next()
		if _is_op(")"):
			_next()
			return {"k": "list", "l": l, "items": []}
		var e := _test()
		if _is_kw("for"):
			e = _comprehension(e, l)
			_expect_op(")")
			return e
		if _is_op(","):
			var items: Array = [e]
			while _is_op(",") and err == "":
				_next()
				if _is_op(")"):
					break
				items.append(_test())
			_expect_op(")")
			return {"k": "list", "l": l, "items": items}
		_expect_op(")")
		return e
	if _is_op("["):
		_next()
		if _is_op("]"):
			_next()
			return {"k": "list", "l": l, "items": []}
		var first := _test()
		if _is_kw("for"):
			var c := _comprehension(first, l)
			_expect_op("]")
			return c
		var items: Array = [first]
		while _is_op(",") and err == "":
			_next()
			if _is_op("]"):
				break
			items.append(_test())
		_expect_op("]")
		return {"k": "list", "l": l, "items": items}
	if _is_op("{"):
		_syntax("딕셔너리 {}는 지원하지 않습니다 — 리스트를 쓰세요")
		return {"k": "const", "l": l, "v": null}
	_syntax("식이 필요합니다")
	_next()
	return {"k": "const", "l": l, "v": null}


# ======================= execution =======================

func _tick(l: int) -> bool:
	_line = l
	steps += 1
	if steps > step_limit:
		fail("실행 단계가 %d을 넘었습니다 (무한 루프?)" % step_limit)
	return err == ""


func _exec_block(body: Array, env: Dictionary) -> int:
	for st: Dictionary in body:
		var c := _exec(st, env)
		if c != C_NORMAL:
			return c
		if err != "":
			return C_ERROR
	return C_NORMAL


func _exec(st: Dictionary, env: Dictionary) -> int:
	if not _tick(int(st.get("l", 0))):
		return C_ERROR
	match st["k"]:
		"expr":
			_eval(st["v"], env)
		"assign":
			var v = _eval(st["v"], env)
			if err != "":
				return C_ERROR
			for tg in st["targets"]:
				_assign(tg, v, env)
		"augassign":
			var cur = _eval(st["target"], env)
			var rhs = _eval(st["v"], env)
			if err != "":
				return C_ERROR
			_assign(st["target"], _binop(st["op"], cur, rhs), env)
		"if":
			for br in st["branches"]:
				var c = _eval(br[0], env)
				if err != "":
					return C_ERROR
				if _truthy(c):
					return _exec_block(br[1], env)
			return _exec_block(st["else"], env)
		"while":
			while true:
				var c = _eval(st["cond"], env)
				if err != "":
					return C_ERROR
				if not _truthy(c):
					break
				var r := _exec_block(st["body"], env)
				if r == C_BREAK:
					break
				if r == C_RETURN or r == C_ERROR:
					return r
		"for":
			var it = _iterable(_eval(st["iter"], env))
			if err != "":
				return C_ERROR
			for item in it:
				_bind_targets(st["target"], item, env)
				if err != "":
					return C_ERROR
				var r := _exec_block(st["body"], env)
				if r == C_BREAK:
					break
				if r == C_RETURN or r == C_ERROR:
					return r
		"return":
			_ret = null if st["v"] == null else _eval(st["v"], env)
			return C_ERROR if err != "" else C_RETURN
		"break":
			return C_BREAK
		"continue":
			return C_CONTINUE
		"pass":
			pass
		"global":
			for n in st["names"]:
				env["globals"][n] = true
		"def":
			var defaults: Array = []
			for d in st["defaults"]:
				defaults.append(null if d == null else _eval(d, env))
			env["vars"][st["name"]] = {"__fn": true, "name": st["name"], "params": st["params"], "defaults": defaults,
				"body": st["body"], "env": env}
	return C_ERROR if err != "" else C_NORMAL


func _bind_targets(names: Array, item, env: Dictionary) -> void:
	if names.size() == 1:
		_set_var(names[0], item, env)
		return
	if not item is Array or (item as Array).size() != names.size():
		fail("값 %d개로 풀 수 없습니다" % names.size())
		return
	for i in names.size():
		_set_var(names[i], item[i], env)


func _set_var(name: String, v, env: Dictionary) -> void:
	if env["globals"].has(name):
		globals_env["vars"][name] = v
	else:
		env["vars"][name] = v


func _assign(tg: Dictionary, v, env: Dictionary) -> void:
	match tg["k"]:
		"name":
			_set_var(tg["name"], v, env)
		"tuple":
			var names: Array = []
			for x in tg["items"]:
				names.append(x["name"])
			_bind_targets(names, v, env)
		"index":
			var obj = _eval(tg["a"], env)
			var idx = _eval(tg["i"], env)
			if err != "":
				return
			if not obj is Array:
				fail("리스트에만 [ ]로 대입할 수 있습니다")
				return
			var i := _norm_index(obj, idx)
			if err == "":
				obj[i] = v


func _lookup(name: String, env: Dictionary):
	var e = env
	while e != null:
		if e["vars"].has(name):
			return e["vars"][name]
		e = e["parent"]
	if name in BUILTINS:
		return {"__bi": name}
	fail("이름 '%s'가 정의되지 않았습니다" % name)
	return null


const BUILTINS := ["print", "len", "range", "min", "max", "abs", "sorted", "sum", "any", "all", "int", "float",
	"str", "round", "list", "enumerate", "zip", "reversed", "bool"]


func _eval(e: Dictionary, env: Dictionary):
	if not _tick(int(e.get("l", 0))):
		return null
	match e["k"]:
		"const":
			return e["v"]
		"name":
			return _lookup(e["name"], env)
		"list", "tuple":
			var out: Array = []
			for x in e["items"]:
				out.append(_eval(x, env))
				if err != "":
					return null
			return out
		"bin":
			var a = _eval(e["a"], env)
			var b = _eval(e["b"], env)
			if err != "":
				return null
			return _binop(e["op"], a, b)
		"unary":
			var a = _eval(e["a"], env)
			if err != "":
				return null
			if not _is_num(a):
				fail("숫자가 아닌 값에 부호를 붙였습니다")
				return null
			return -a if e["op"] == "-" else a
		"not":
			var a = _eval(e["a"], env)
			return not _truthy(a)
		"and":
			var a = _eval(e["a"], env)
			if err != "" or not _truthy(a):
				return a
			return _eval(e["b"], env)
		"or":
			var a = _eval(e["a"], env)
			if err != "" or _truthy(a):
				return a
			return _eval(e["b"], env)
		"ternary":
			var c = _eval(e["cond"], env)
			if err != "":
				return null
			return _eval(e["a"] if _truthy(c) else e["b"], env)
		"compare":
			var left = _eval(e["first"], env)
			for i in e["ops"].size():
				var right = _eval(e["rest"][i], env)
				if err != "":
					return null
				if not _compare(e["ops"][i], left, right):
					return false
				if err != "":
					return null
				left = right
			return true
		"lambda":
			return {"__fn": true, "name": "lambda", "params": e["params"], "defaults": [], "body": null, "expr": e["body"], "env": env}
		"call":
			var fv = _eval(e["f"], env)
			if err != "":
				return null
			var args: Array = []
			for a in e["args"]:
				args.append(_eval(a, env))
				if err != "":
					return null
			var kwargs: Dictionary = {}
			for kn in e["kwargs"]:
				kwargs[kn] = _eval(e["kwargs"][kn], env)
			if err != "":
				return null
			return _call_value(fv, args, kwargs)
		"index":
			var obj = _eval(e["a"], env)
			var idx = _eval(e["i"], env)
			if err != "":
				return null
			if obj is Array or obj is String:
				var i := _norm_index(obj, idx)
				return null if err != "" else obj[i]
			fail("[ ]는 리스트와 문자열에만 쓸 수 있습니다")
			return null
		"slice":
			var obj = _eval(e["a"], env)
			var lo = 0 if e["lo"] == null else _eval(e["lo"], env)
			var hi = null if e["hi"] == null else _eval(e["hi"], env)
			if err != "":
				return null
			if not (obj is Array or obj is String):
				fail("슬라이스는 리스트와 문자열에만 쓸 수 있습니다")
				return null
			var n: int = obj.size() if obj is Array else obj.length()
			var a := clampi(int(lo) + (n if int(lo) < 0 else 0), 0, n)
			var b := n if hi == null else clampi(int(hi) + (n if int(hi) < 0 else 0), 0, n)
			if b <= a:
				return [] if obj is Array else ""
			return obj.slice(a, b) if obj is Array else obj.substr(a, b - a)
		"attr":
			var obj = _eval(e["a"], env)
			if err != "":
				return null
			return _get_attr(obj, e["name"])
		"comp":
			var out: Array = []
			var cenv := {"vars": {}, "parent": env, "globals": {}}
			_comp_loop(e, 0, cenv, out)
			return null if err != "" else out
	fail("알 수 없는 식")
	return null


func _comp_loop(e: Dictionary, ci: int, env: Dictionary, out: Array) -> void:
	if ci >= e["clauses"].size():
		out.append(_eval(e["elt"], env))
		return
	var cl: Dictionary = e["clauses"][ci]
	var it = _iterable(_eval(cl["iter"], env))
	if err != "":
		return
	for item in it:
		_bind_targets(cl["target"], item, env)
		var ok := true
		for c in cl["conds"]:
			var cv = _eval(c, env)
			if err != "":
				return
			if not _truthy(cv):
				ok = false
				break
		if ok:
			_comp_loop(e, ci + 1, env, out)
		if err != "":
			return


func _norm_index(obj, idx) -> int:
	if not (idx is int):
		fail("인덱스는 정수여야 합니다")
		return 0
	var n: int = obj.size() if obj is Array else obj.length()
	var i: int = idx + n if idx < 0 else idx
	if i < 0 or i >= n:
		fail("인덱스 %d가 범위를 벗어났습니다 (길이 %d)" % [idx, n])
		return 0
	return i


func _get_attr(obj, name: String):
	if obj is Array:
		if name in ["append", "pop", "index", "count", "sort", "insert", "remove", "extend", "reverse", "copy"]:
			return {"__bm": name, "self": obj}
	elif obj is String:
		if name in ["startswith", "endswith", "find", "upper", "lower", "split", "join", "replace", "strip"]:
			return {"__bm": name, "self": obj}
	elif obj is Dictionary and obj.has("__obj") and host != null:
		return host.py_attr(obj, name, self)
	fail("'%s'에는 .%s 가 없습니다" % [_type_name(obj), name])
	return null


# ======================= values =======================

static func _is_num(v) -> bool:
	return v is int or v is float or v is bool


static func _truthy(v) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	if v is String:
		return v != ""
	if v is Array:
		return not v.is_empty()
	return true


func _type_name(v) -> String:
	if v == null:
		return "None"
	if v is bool:
		return "bool"
	if v is int:
		return "int"
	if v is float:
		return "float"
	if v is String:
		return "str"
	if v is Array:
		return "list"
	if v is Dictionary:
		if v.has("__obj"):
			return {"enemy": "적", "snap": "적(예측)", "tower": "타워"}.get(v["__obj"], "객체")
		if v.has("__fn") or v.has("__bi") or v.has("__bm"):
			return "함수"
	return "값"


func _iterable(v) -> Array:
	if v is Array:
		return v
	if v is String:
		var out: Array = []
		for ch in v:
			out.append(ch)
		return out
	if err == "":
		fail("'%s'는 반복할 수 없습니다" % _type_name(v))
	return []


static func _num(v):
	return int(v) if v is bool else v


func _binop(op: String, a, b):
	if _is_num(a) and _is_num(b):
		a = _num(a)
		b = _num(b)
		match op:
			"+":
				return a + b
			"-":
				return a - b
			"*":
				return a * b
			"/":
				if b == 0:
					fail("0으로 나눌 수 없습니다")
					return null
				return float(a) / float(b)
			"//":
				if b == 0:
					fail("0으로 나눌 수 없습니다")
					return null
				if a is int and b is int:
					var q: int = a / b
					if (a % b != 0) and ((a < 0) != (b < 0)):
						q -= 1
					return q
				return floorf(float(a) / float(b))
			"%":
				if b == 0:
					fail("0으로 나눌 수 없습니다")
					return null
				if a is int and b is int:
					var r: int = a % b
					if r != 0 and ((r < 0) != (b < 0)):
						r += b
					return r
				var rf := fmod(float(a), float(b))
				if rf != 0.0 and ((rf < 0.0) != (float(b) < 0.0)):
					rf += float(b)
				return rf
			"**":
				if a is int and b is int and b >= 0:
					var p := 1
					for i in mini(b, 63):
						p *= a
					return p
				return pow(float(a), float(b))
	if op == "+" and a is String and b is String:
		return a + b
	if op == "+" and a is Array and b is Array:
		return a + b
	if op == "*" and ((a is String or a is Array) and b is int):
		return _repeat(a, b)
	if op == "*" and (a is int and (b is String or b is Array)):
		return _repeat(b, a)
	if op == "%" and a is String:
		return a % (b if b is Array else [b])
	fail("'%s' %s '%s' 는 계산할 수 없습니다" % [_type_name(a), op, _type_name(b)])
	return null


static func _repeat(v, n: int):
	if v is String:
		return v.repeat(maxi(0, n))
	var out: Array = []
	for i in maxi(0, mini(n, 1000)):
		out += v
	return out


func _eq(a, b) -> bool:
	if _is_num(a) and _is_num(b):
		return _num(a) == _num(b)
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary and a.has("__obj") and b.has("__obj"):
		return a.get("node") == b.get("node") and a.get("__obj") == b.get("__obj") and (a["__obj"] != "snap" or a.get("f") == b.get("f"))
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _eq(a[i], b[i]):
				return false
		return true
	return a == b


func _compare(op: String, a, b) -> bool:
	match op:
		"==", "is":
			return _eq(a, b)
		"!=", "is not":
			return not _eq(a, b)
		"in", "not in":
			var found := false
			if b is Array:
				for x in b:
					if _eq(a, x):
						found = true
						break
			elif b is String and a is String:
				found = b.contains(a)
			else:
				fail("'in' 오른쪽에는 리스트나 문자열이 필요합니다")
			return found if op == "in" else not found
	var ok := (_is_num(a) and _is_num(b)) or (a is String and b is String)
	if not ok:
		fail("'%s'와 '%s'는 크기를 비교할 수 없습니다" % [_type_name(a), _type_name(b)])
		return false
	if _is_num(a):
		a = _num(a)
		b = _num(b)
	match op:
		"<":
			return a < b
		">":
			return a > b
		"<=":
			return a <= b
		">=":
			return a >= b
	return false


func _str(v, repr: bool = false) -> String:
	if v == null:
		return "None"
	if v is bool:
		return "True" if v else "False"
	if v is float:
		if is_finite(v) and v == floorf(v) and absf(v) < 1e15:
			return "%.1f" % v
		return str(v)
	if v is String:
		return ("'%s'" % v) if repr else v
	if v is Array:
		var parts := PackedStringArray()
		for x in v:
			parts.append(_str(x, true))
		return "[" + ", ".join(parts) + "]"
	if v is Dictionary:
		if v.has("__obj") and host != null:
			return host.py_repr(v)
		if v.has("__fn"):
			return "<함수 %s>" % v["name"]
		if v.has("__bi"):
			return "<내장 함수 %s>" % v["__bi"]
		if v.has("__bm"):
			return "<메서드 %s>" % v["__bm"]
	return str(v)


# ======================= calls =======================

func _call_value(fv, args: Array, kwargs: Dictionary):
	if not fv is Dictionary:
		fail("'%s'는 호출할 수 없습니다" % _type_name(fv))
		return null
	if fv.has("__fn"):
		return _call_user(fv, args, kwargs)
	if fv.has("__bi"):
		return _builtin(fv["__bi"], args, kwargs)
	if fv.has("__bm"):
		var obj = fv["self"]
		if obj is Dictionary and obj.has("__obj"):
			return host.py_call(obj, fv["__bm"], args, kwargs, self)
		return _method(obj, fv["__bm"], args, kwargs)
	fail("'%s'는 호출할 수 없습니다" % _type_name(fv))
	return null


func _call_user(fv: Dictionary, args: Array, kwargs: Dictionary):
	var params: Array = fv["params"]
	if args.size() > params.size():
		fail("%s()는 인자를 %d개까지 받습니다 (%d개 줌)" % [fv["name"], params.size(), args.size()])
		return null
	_depth += 1
	if _depth > MAX_DEPTH:
		fail("재귀가 너무 깊습니다")
		_depth -= 1
		return null
	var env := {"vars": {}, "parent": fv["env"], "globals": {}}
	var defaults: Array = fv["defaults"]
	for i in params.size():
		if i < args.size():
			env["vars"][params[i]] = args[i]
		elif kwargs.has(params[i]):
			env["vars"][params[i]] = kwargs[params[i]]
		elif i < defaults.size() and defaults[i] != null:
			env["vars"][params[i]] = defaults[i]
		else:
			fail("%s()에 인자 '%s'가 빠졌습니다" % [fv["name"], params[i]])
			_depth -= 1
			return null
	var result = null
	if fv.get("expr") != null:
		result = _eval(fv["expr"], env)
	else:
		_ret = null
		var c := _exec_block(fv["body"], env)
		if c == C_RETURN:
			result = _ret
		elif c == C_BREAK or c == C_CONTINUE:
			fail("반복문 밖에서 break/continue를 썼습니다")
	_depth -= 1
	return null if err != "" else result


func _key_of(kwargs: Dictionary, v):
	if kwargs.has("key") and kwargs["key"] != null:
		return _call_value(kwargs["key"], [v], {})
	return v


func _builtin(name: String, args: Array, kwargs: Dictionary):
	match name:
		"print":
			var parts := PackedStringArray()
			for a in args:
				parts.append(_str(a))
			emit(" ".join(parts))
			return null
		"len":
			if args.size() == 1 and (args[0] is Array):
				return (args[0] as Array).size()
			if args.size() == 1 and args[0] is String:
				return (args[0] as String).length()
			fail("len()에는 리스트나 문자열 하나가 필요합니다")
		"range":
			for x in args:
				if not (x is int or x is bool):
					fail("range()에는 정수가 필요합니다")
					return null
			var a := 0
			var b := 0
			var s := 1
			if args.size() == 1:
				b = int(args[0])
			elif args.size() >= 2:
				a = int(args[0])
				b = int(args[1])
				if args.size() == 3:
					s = int(args[2])
			if s == 0:
				fail("range()의 간격은 0일 수 없습니다")
				return null
			var out: Array = []
			var i := a
			while (s > 0 and i < b) or (s < 0 and i > b):
				out.append(i)
				i += s
				if out.size() > 10000:
					fail("range()가 너무 깁니다")
					return null
			return out
		"min", "max":
			var items: Array = args[0] if (args.size() == 1 and args[0] is Array) else args
			if items.is_empty():
				if kwargs.has("default"):
					return kwargs["default"]
				fail("%s()에 빈 리스트를 줬습니다 (default=None을 쓰면 None이 나옵니다)" % name)
				return null
			var best = items[0]
			var bk = _key_of(kwargs, best)
			for i in range(1, items.size()):
				var k = _key_of(kwargs, items[i])
				if err != "":
					return null
				if (name == "min" and _compare("<", k, bk)) or (name == "max" and _compare(">", k, bk)):
					best = items[i]
					bk = k
			return best
		"abs":
			if args.size() == 1 and _is_num(args[0]):
				return absi(args[0]) if args[0] is int else absf(args[0])
			fail("abs()에는 숫자가 필요합니다")
		"sorted":
			if args.size() != 1 or not args[0] is Array:
				fail("sorted()에는 리스트가 필요합니다")
				return null
			return _sorted(args[0], kwargs)
		"sum":
			var total = 0
			for x in _iterable(args[0] if not args.is_empty() else []):
				total = _binop("+", total, x)
				if err != "":
					return null
			return total
		"any":
			for x in _iterable(args[0] if not args.is_empty() else []):
				if _truthy(x):
					return true
			return false
		"all":
			for x in _iterable(args[0] if not args.is_empty() else []):
				if not _truthy(x):
					return false
			return true
		"int":
			if args.size() == 1 and _is_num(args[0]):
				return int(args[0])
			if args.size() == 1 and args[0] is String and (args[0] as String).is_valid_int():
				return (args[0] as String).to_int()
			fail("int()로 바꿀 수 없는 값입니다")
		"float":
			if args.size() == 1 and _is_num(args[0]):
				return float(args[0])
			if args.size() == 1 and args[0] is String and (args[0] as String).is_valid_float():
				return (args[0] as String).to_float()
			fail("float()로 바꿀 수 없는 값입니다")
		"str":
			return _str(args[0]) if not args.is_empty() else ""
		"bool":
			return _truthy(args[0]) if not args.is_empty() else false
		"round":
			if args.is_empty() or not _is_num(args[0]):
				fail("round()에는 숫자가 필요합니다")
				return null
			if args.size() >= 2:
				var m := pow(10.0, float(args[1]))
				return round(float(args[0]) * m) / m
			return int(round(float(args[0])))
		"list":
			return _iterable(args[0]).duplicate() if not args.is_empty() else []
		"enumerate":
			var out: Array = []
			var i := 0
			for x in _iterable(args[0] if not args.is_empty() else []):
				out.append([i, x])
				i += 1
			return out
		"zip":
			var out: Array = []
			if args.is_empty():
				return out
			var n := 1 << 30
			for a in args:
				n = mini(n, _iterable(a).size())
			for i in n:
				var row: Array = []
				for a in args:
					row.append(a[i])
				out.append(row)
			return out
		"reversed":
			var r: Array = _iterable(args[0] if not args.is_empty() else []).duplicate()
			r.reverse()
			return r
	return null


func _sorted(items: Array, kwargs: Dictionary) -> Array:
	var keyed: Array = []
	for i in items.size():
		keyed.append([_key_of(kwargs, items[i]), i, items[i]])
		if err != "":
			return []
	# insertion sort keeps it stable and lets comparison errors surface cleanly (lists here are short)
	for i in range(1, keyed.size()):
		var cur = keyed[i]
		var j := i - 1
		while j >= 0 and _compare(">", keyed[j][0], cur[0]):
			keyed[j + 1] = keyed[j]
			j -= 1
		keyed[j + 1] = cur
		if err != "":
			return []
	var out: Array = []
	for k in keyed:
		out.append(k[2])
	if _truthy(kwargs.get("reverse", false)):
		out.reverse()
	return out


func _method(obj, name: String, args: Array, kwargs: Dictionary):
	if obj is Array:
		var a: Array = obj
		match name:
			"append":
				a.append(args[0] if not args.is_empty() else null)
				return null
			"pop":
				if a.is_empty():
					fail("빈 리스트에서 pop()")
					return null
				if args.is_empty():
					return a.pop_back()
				var i := _norm_index(a, args[0])
				return null if err != "" else a.pop_at(i)
			"index":
				for i in a.size():
					if _eq(a[i], args[0]):
						return i
				fail("리스트에 그 값이 없습니다")
				return null
			"count":
				var c := 0
				for x in a:
					if _eq(x, args[0]):
						c += 1
				return c
			"sort":
				var s := _sorted(a, kwargs)
				a.clear()
				a.append_array(s)
				return null
			"insert":
				a.insert(clampi(int(args[0]), 0, a.size()), args[1])
				return null
			"remove":
				for i in a.size():
					if _eq(a[i], args[0]):
						a.remove_at(i)
						return null
				fail("리스트에 그 값이 없습니다")
				return null
			"extend":
				a.append_array(_iterable(args[0]))
				return null
			"reverse":
				a.reverse()
				return null
			"copy":
				return a.duplicate()
	elif obj is String:
		var s: String = obj
		match name:
			"startswith":
				return s.begins_with(str(args[0]))
			"endswith":
				return s.ends_with(str(args[0]))
			"find":
				return s.find(str(args[0]))
			"upper":
				return s.to_upper()
			"lower":
				return s.to_lower()
			"split":
				var parts := s.split(str(args[0])) if not args.is_empty() else s.split(" ", false)
				return Array(parts)
			"join":
				var strs := PackedStringArray()
				for x in _iterable(args[0]):
					strs.append(_str(x))
				return s.join(strs)
			"replace":
				return s.replace(str(args[0]), str(args[1]))
			"strip":
				return s.strip_edges()
	fail("메서드 %s를 쓸 수 없습니다" % name)
	return null
