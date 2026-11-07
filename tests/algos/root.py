roots = [e for e in enemies if e.special == "root"]
if roots:
    attack(max(roots, key=lambda e: e.damage))
