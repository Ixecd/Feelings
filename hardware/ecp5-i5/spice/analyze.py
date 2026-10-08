import bisect

def load(fn):
    ts=[]; rs=[]; vr=[]; qg=[]
    with open(fn) as f:
        for line in f:
            p=line.split()
            if len(p)<10: continue
            ts.append(float(p[0]));  rs.append(float(p[1]))
            vr.append(float(p[3]));  qg.append(float(p[5]))
    return ts,rs,vr,qg

def report(name, fn):
    ts,rs,vr,qg=load(fn)
    R=390.0
    print(f"=== {name}  ({fn})  points={len(ts)}  t_end={ts[-1]*1e6:.0f}us ===")
    def at(t_us):
        i=min(bisect.bisect_left(ts,t_us*1e-6),len(ts)-1)
        return rs[i]/R*1000, rs[i], qg[i], vr[i]
    for t in [150,200,205,210,360,410,415,420]:
        I,r,g,v=at(t)
        print(f"   t={t:4d}us  I={I:7.3f}mA  rs={r:.4f}V  qgate={g:.3f}V  vref={v:.4f}V")
    idx_pos=[i for i,t in enumerate(ts) if 0<=t<=200e-6]
    idx_neg=[i for i,t in enumerate(ts) if 210e-6<=t<=410e-6]
    p=max(rs[i] for i in idx_pos)/R*1000 if idx_pos else 0
    n=max(rs[i] for i in idx_neg)/R*1000 if idx_neg else 0
    print(f"   pos max I = {p:.3f}mA ; neg max I = {n:.3f}mA")
    # first 6us after each on-edge (t=0 and t=210us) -> see spike
    for e in [0.0,210.0]:
        seg=[(t,rs[i]) for i,t in enumerate(ts) if e*1e-6<=t<=(e+6)*1e-6]
        if seg:
            mx=max(r for _,r in seg)/R*1000
            print(f"   first 6us after t={e:.0f}us: max I = {mx:.3f}mA")
    print()

report("WITH QD (windup fix)", "t1p_withqd.txt")
report("NO QD", "t1p_noqd.txt")
