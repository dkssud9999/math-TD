# bot, Σ tower: add up the first pair that cancels a term
seen = []                       # [key, enemy] for every term seen so far
for e in enemies:
    for t in e.f.terms:
        want = t.shape + "|" + str(-t.coef)
        for k in seen:
            if k[0] == want and k[1] != e:
                attack([k[1], e])
        seen.append([t.shape + "|" + str(t.coef), e])
