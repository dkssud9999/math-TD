# test: switch ω to whatever the leading trig enemy needs
def attack(enemies):
    for e in enemies:
        for term in e.f.terms:
            for fac in term.factors:
                if fac.kind in ["sin", "cos"]:
                    if set_param(fac.inner.coef) or me.param == fac.inner.coef:
                        return e
    return None
