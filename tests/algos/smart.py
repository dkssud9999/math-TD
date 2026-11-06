# test: fire only where one shot makes progress; nearest to the core first
def attack(enemies):
    good = []
    for e in enemies:
        a = e.after()
        if a.zero or a.ann_degree < e.ann_degree or a.damage < e.damage:
            good.append(e)
    return max(good, key=lambda e: e.progress, default=None)
