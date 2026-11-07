# bot, damping field e⁻ˣ·: it multiplies the WHOLE function, and a faded term never reaches 0 again
# (the core takes at least 1 from anything that is not exactly 0). So only damp an enemy whose every
# term still grows: eˣ sin x → sin x, e²ˣ + eˣ → eˣ + 1. Peel constants and polynomials off first
# (x + eˣ damped is xe⁻ˣ + 1: the xe⁻ˣ is stuck), and leave a single c·eᵃˣ to the log tower.
def grows(term):
    for fac in term.factors:
        if fac.kind == "exp" and fac.inner.has("x") and fac.inner.coef > 0:
            return True
    return False

def single_exp(f):
    ts = f.terms
    if len(ts) != 1:
        return False
    for fac in ts[0].factors:
        if fac.kind in ["sin", "cos", "pow", "x", "t"]:
            return False
    return True

def wants_damping(f):
    ts = f.terms
    return len(ts) > 0 and all(grows(t) for t in ts) and not single_exp(f)

attack([e for e in enemies if e.special == "" and wants_damping(e.f)])
