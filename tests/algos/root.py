# bot: Newton / bisection only touch equation enemies
def attack(enemies):
    roots = [e for e in enemies if e.special == "root"]
    return max(roots, key=lambda e: e.damage, default=None)
