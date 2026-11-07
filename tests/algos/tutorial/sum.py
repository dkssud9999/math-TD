# a player's finished 과제 ① (tests only; never shipped)
for a in enemies:
    for b in enemies:
        if a != b and a.f + b.f == 0:
            attack([a, b])
