def growing(f):
    for term in f.terms:
        for fac in term.factors:
            if fac.kind == "exp" and fac.inner.has("x") and fac.inner.coef > 0:
                return True
    return False

attack([e for e in enemies if e.special == "" and growing(e.f)])
