# bot, ÷2 tower: shrink a trig term that is a multiple of another enemy's same-shaped term (−4 sin 2x vs sin 2x)
keys = []
for o in enemies:
    for u in o.f.terms:
        keys.append([u.shape, abs(u.coef), o])

for e in enemies:
    for t in e.f.terms:
        if not (t.has("sin") or t.has("cos")):
            continue
        for k in keys:
            if k[2] != e and k[0] == t.shape and abs(t.coef) >= 2 * k[1]:
                attack(e)
for e in enemies:
    if e.f.kind == "num" and e.value % 2 == 0:
        attack(e)
