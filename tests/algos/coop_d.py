# bot, D tower. Shoot only when D really helps:
#  - trig times an exponential (eˣ sin x, a product): never. The damping field must strip eˣ first;
#    D first gives eˣ(sin x + cos x), which nothing pairs with ([D, e⁻ˣ] ≠ 0).
#  - trig already paired on the field: leave it to Σ.
#  - trig without a partner: only if D CREATES a partner within two steps (cos x → −sin x when sin x is
#    on the field; sin 2x → … → −4 sin 2x, the ÷2 tower evens the size).
#    Differentiating blindly just cycles sin → cos → −sin and grows the coefficient.
#  - anything else: only if D makes progress (kills it, lowers its damage, or shrinks it).
keys = []                       # every "shape|coef" on the field, built once
shapes = []                     # the same terms: shape and coefficient apart
coefs = []
owner = []                      # the enemy each key belongs to
for o in enemies:
    for t in o.f.terms:
        keys.append(t.shape + "|" + str(t.coef))
        shapes.append(t.shape)
        coefs.append(t.coef)
        owner.append(o)

def pairs_with_other(f, e):
    # does some term of f cancel a term of another enemy on the field?
    for t in f.terms:
        k = t.shape + "|" + str(-t.coef)
        for i in range(len(keys)):
            if keys[i] == k and owner[i] != e:
                return True
    return False

def sign_pairs(f, e):
    # same shape, opposite sign, any size (÷2 evens the size out afterwards: sin 2x → … → −4 sin 2x)
    for t in f.terms:
        for i in range(len(shapes)):
            if owner[i] != e and shapes[i] == t.shape and coefs[i] * t.coef < 0:
                return True
    return False

def exp_times_trig(f):
    # eˣ sin x is a product; sin x + eˣ is a sum (D is fine there: Σ peels the sin off)
    for t in f.terms:
        if t.has("exp") and (t.has("sin") or t.has("cos")):
            return True
    return False

def too_big(e):
    # a term bigger than another enemy's same-shaped term is the ÷2 tower's job, not more D
    for t in e.f.terms:
        for i in range(len(shapes)):
            if owner[i] != e and shapes[i] == t.shape and abs(t.coef) > abs(coefs[i]):
                return True
    return False

def grown(e):
    # D multiplies sin kx by k each time; past 2 it is the ÷2 tower's turn
    for t in e.f.terms:
        if (t.has("sin") or t.has("cos")) and t.shape not in ["sin(x)", "cos(x)"] and abs(t.coef) > 2:
            return True
    return False

def size(f):
    return sum(t.degree + 1 for t in f.terms)

for e in enemies:
    if e.special != "":
        continue
    trig = e.f.has("sin") or e.f.has("cos")
    if trig:
        if exp_times_trig(e.f) or pairs_with_other(e.f, e) or too_big(e) or grown(e):
            continue
        a = e.after()
        if a.zero or pairs_with_other(a.f, e) or sign_pairs(a.f, e) or sign_pairs(derivative(a.f), e):
            attack(e)
    else:
        a = e.after()
        if a.zero or a.damage < e.damage or size(a.f) < size(e.f):
            attack(e)
