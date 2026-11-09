import math
f=lambda v: f"{v:.1f}".rstrip('0').rstrip('.')
# 1. Redline bar tach: 30 segs, 0-12k, redline at seg 25, active 17
out=[]
W=760; n=30; step=W/n; sw=step-7
for i in range(n):
    h=22+i*2.3; x=i*step; y=100-h
    red=i>=25; act=i<17
    c = ('#FF3B1F' if red else '#FFB000') if act else ('#3A0D0A' if red else '#2A1E08')
    out.append(f'<rect x="{f(x)}" y="{f(y)}" width="{f(sw)}" height="{f(h)}" rx="1.5" fill="{c}"/>')
open('redline.svg','w').write(f'<svg width="760" height="100" viewBox="0 0 760 100" xmlns="http://www.w3.org/2000/svg">'+''.join(out)+'</svg>')
# 2. Vanguard ring: 40 segments over 270deg via individual arc segments (robust, no dasharray)
cx=cy=240
def pt(r,a): a=math.radians(a); return cx+r*math.cos(a), cy+r*math.sin(a)
def arcseg(r1,r2,a1,a2,fill):
    p1=pt(r2,a1);p2=pt(r2,a2);p3=pt(r1,a2);p4=pt(r1,a1)
    return f'<path d="M{f(p1[0])} {f(p1[1])}A{r2} {r2} 0 0 1 {f(p2[0])} {f(p2[1])}L{f(p3[0])} {f(p3[1])}A{r1} {r1} 0 0 0 {f(p4[0])} {f(p4[1])}Z" fill="{fill}"/>'
o=[]
n=40; span=270/n
for i in range(n):
    a1=135+i*span+0.9; a2=135+(i+1)*span-0.9
    red=i>=int(n*10/12); act=i<int(n*6.8/12)
    c=('#E8263F' if act else ('#4A0F18' if red else '#1E1418'))
    if act and i>=int(n*6.8/12)-3: c='#FF5A6E'
    o.append(arcseg(196,222,a1,a2,c))
# cyan inner tick ring with numbers positions
for k in range(13):
    a=135+k*270/12; p1=pt(186,a); p2=pt(176 if k%2==0 else 181,a)
    o.append(f'<line x1="{f(p1[0])}" y1="{f(p1[1])}" x2="{f(p2[0])}" y2="{f(p2[1])}" stroke="#7FE3F0" stroke-width="{2 if k%2==0 else 1}"/>')
# red zone outer hairline
p1=pt(230,360); p2=pt(230,405)
o.append(f'<path d="M{f(p1[0])} {f(p1[1])}A230 230 0 0 1 {f(p2[0])} {f(p2[1])}" stroke="#E8263F" stroke-width="2" fill="none"/>')
# outer cyan hairline arcs
p1=pt(232,140); p2=pt(232,355)
o.append(f'<path d="M{f(p1[0])} {f(p1[1])}A232 232 0 1 1 {f(p2[0])} {f(p2[1])}" stroke="#7FE3F0" stroke-opacity="0.35" stroke-width="1" fill="none"/>')
open('vanguard.svg','w').write('<svg width="480" height="480" viewBox="0 0 480 480" xmlns="http://www.w3.org/2000/svg">'+''.join(o)+'</svg>')
# numbers for vanguard (rpm x1000 at even k)
nums=[]
for k in range(0,13,2):
    a=135+k*270/12; p=pt(160,a); nums.append((k,round(p[0]),round(p[1])))
print('vanguard nums',nums)
# 3. Shard: skewed parallelogram tach, 24 segs across 440px, heights rising
o=[]
n=24; W=430; step=W/n; sw=step-5
for i in range(n):
    h=14+i*1.6; x=i*step; base=60; y=base-h
    red=i>=20; act=i<14
    c=('#FFC400' if not red else '#FF4D2E') if act else ('#3A2E05' if not red else '#3A140D')
    sk=h*0.35
    o.append(f'<polygon points="{f(x+sk)},{f(y)} {f(x+sk+sw)},{f(y)} {f(x+sw)},{f(base)} {f(x)},{f(base)}" fill="{c}"/>')
open('shard_tach.svg','w').write('<svg width="450" height="60" viewBox="0 0 450 60" xmlns="http://www.w3.org/2000/svg">'+''.join(o)+'</svg>')
# 4. Twin dials 240: ticks over 270deg; returns svg with ticks+needle
def dial(major,minor_per,redfrom,needle_frac,labels):
    c=120
    def P(r,a): a=math.radians(a); return c+r*math.cos(a), c+r*math.sin(a)
    o=[]
    total=(major-1)*minor_per
    for k in range(total+1):
        a=135+k*270/total; maj=k%minor_per==0
        r2=96 if maj else 102
        col='#F0552B' if (k/minor_per)>=redfrom else '#EDE6D6'
        p1=P(110,a);p2=P(r2,a)
        o.append(f'<line x1="{f(p1[0])}" y1="{f(p1[1])}" x2="{f(p2[0])}" y2="{f(p2[1])}" stroke="{col}" stroke-width="{3 if maj else 1.2}"/>')
    a=135+needle_frac*270
    tip=P(104,a); t1=P(3.5,a+90); t2=P(3.5,a-90); tail=P(18,a+180)
    o.append(f'<polygon points="{f(tip[0])},{f(tip[1])} {f(t1[0])},{f(t1[1])} {f(tail[0])},{f(tail[1])} {f(t2[0])},{f(t2[1])}" fill="#F0552B"/>')
    o.append('<circle cx="120" cy="120" r="9" fill="#1C1C1C" stroke="#3A3A3A" stroke-width="1.5"/>')
    lab=[]
    for i,t in enumerate(labels):
        a=135+i*270/(len(labels)-1); p=P(78,a); lab.append((t,round(p[0]),round(p[1])))
    return '<svg width="240" height="240" viewBox="0 0 240 240" xmlns="http://www.w3.org/2000/svg">'+''.join(o)+'</svg>', lab
s,l=dial(8,4,99,42/140,['0','20','40','60','80','100','120','140']); open('twin_speed.svg','w').write(s); print('speed labels',l)
s,l=dial(7,4,5,6.8/12,['0','2','4','6','8','10','12']); open('twin_tach.svg','w').write(s); print('tach labels',l)
