# bot: the first enemy (front first) that one shot really improves
def size(f):
    return sum(t.degree + 1 for t in f.terms)

for e in enemies:
    if e.special != "":
        continue
    a = e.after()
    if a.zero or a.damage < e.damage or size(a.f) < size(e.f):
        attack(e)
    if e.f.kind == "num" and abs(a.value) < abs(e.value):
        attack(e)
