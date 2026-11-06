# test: switch ω to whatever the leading enemy needs
def attack(enemies):
    if not enemies:
        return None
    lead = max(enemies, key=lambda e: e.progress)
    for w in [1, 2]:
        if lead.has_mode(0, w):
            set_param(w)
            return lead
    hit = [e for e in enemies if e.has_mode(0, me.param)]
    return hit[0] if hit else None
