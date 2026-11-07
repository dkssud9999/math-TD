# a player's finished 과제 ② (tests only; never shipped)
def paired(f, e):
    for o in enemies:
        if o != e and f + o.f == 0:
            return True
    return False

for e in enemies:
    d1 = e.f.derivative()
    if not paired(e.f, e) and (paired(d1, e) or paired(d1.derivative(), e)):
        attack(e)
