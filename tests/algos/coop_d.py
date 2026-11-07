# bot, D tower: differentiate trig enemies that have no cancelling partner yet; otherwise make progress
keys = []                       # every "shape|coef" on the field, built once (cheap lookups after)
mags = []                       # [shape, |coef|, enemy] to spot terms that need ÷2 first
for o in enemies:
    for t in o.f.terms:
        keys.append(t.shape + "|" + str(t.coef))
        mags.append([t.shape, abs(t.coef), o])

def too_big(e):
    for t in e.f.terms:
        for m in mags:
            if m[2] != e and m[0] == t.shape and abs(t.coef) > m[1]:
                return True
    return False

def partnered(e):
    for t in e.f.terms:
        if t.shape + "|" + str(-t.coef) in keys:
            return True
    return False

def grown(e):
    # D multiplies sin kx by k each time; past 2 it is the ÷2 tower's turn, not more D
    for t in e.f.terms:
        if (t.has("sin") or t.has("cos")) and t.shape not in ["sin(x)", "cos(x)"] and abs(t.coef) > 2:
            return True
    return False

def size(f):
    return sum(t.degree + 1 for t in f.terms)

for e in enemies:
    if e.special != "":
        continue
    if e.f.has("sin") or e.f.has("cos"):
        if not partnered(e) and not too_big(e) and not grown(e):
            attack(e)
    else:
        a = e.after()
        if a.zero or a.damage < e.damage or size(a.f) < size(e.f):
            attack(e)
