import numpy as np, wave
SR=44100
def env(n, a=0.005, d=0.4):
    t=np.arange(n)/SR
    return np.minimum(1,t/a)*np.exp(-t/d)
def tone(f, dur, d=0.4, harm=(1,0.5,0.25,0.12)):
    n=int(dur*SR); t=np.arange(n)/SR
    y=sum(h*np.sin(2*np.pi*f*(i+1)*t) for i,h in enumerate(harm))
    return y*env(n,0.003,d)
def bell(f, dur, d=0.5):
    n=int(dur*SR); t=np.arange(n)/SR
    parts=[(1,1),(2.76,0.45),(5.4,0.25),(8.93,0.12)]
    y=sum(a*np.sin(2*np.pi*f*r*t)*np.exp(-t/(d/(1+0.6*i))) for i,(r,a) in enumerate(parts))
    return y*np.minimum(1,t/0.002)
def boom(dur=0.9, f0=160, f1=38, d=0.35):
    n=int(dur*SR); t=np.arange(n)/SR
    f=f1+(f0-f1)*np.exp(-t/0.07)
    ph=2*np.pi*np.cumsum(f)/SR
    return np.sin(ph)*env(n,0.002,d)
def noise(dur, d=0.25, lp=0.2, seed=1):
    n=int(dur*SR); r=np.random.default_rng(seed).standard_normal(n)
    y=np.zeros(n); a=0
    for i in range(n):
        a+=lp*(r[i]-a); y[i]=a
    return y*env(n,0.002,d)
def whoosh(dur=0.22, seed=2):
    n=int(dur*SR); r=np.random.default_rng(seed).standard_normal(n)
    t=np.arange(n)/SR; y=np.zeros(n); a=0
    for i in range(n):
        k=0.02+0.5*(i/n)**2
        a+=k*(r[i]-a); y[i]=a
    return y*(t/dur)**2
def mix(total, *layers):
    out=np.zeros(int(total*SR))
    for at,g,y in layers:
        i=int(at*SR); y=y[:len(out)-i]; out[i:i+len(y)]+=g*y
    return out
def save(name, y):
    y=np.tanh(y*1.4); y=y/np.max(np.abs(y))*0.89
    st=np.stack([y,y],1); pcm=(st*32767).astype('<i2')
    with wave.open(name,'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
D=1.5
# Triple 20 : souffle, impact, accord brillant
save('t20.wav', mix(D, (0,0.9,whoosh()), (0.2,1.0,boom(0.7,200,50,0.22)), (0.2,0.7,noise(0.5,0.12,0.5)),
  (0.22,0.35,tone(523.25,1.0,0.35)), (0.22,0.3,tone(659.25,1.0,0.35)), (0.22,0.3,tone(783.99,1.0,0.35)), (0.30,0.25,tone(1046.5,0.9,0.3))))
# Bull : coup sourd + cloche
save('bull.wav', mix(D, (0,0.6,whoosh(0.15,3)), (0.14,1.0,boom(0.9,150,36,0.3)), (0.14,0.5,noise(0.6,0.2,0.15,4)), (0.16,0.55,bell(880,1.2,0.6))))
# Double bull : gros coup + deux cloches qui montent + souffle
save('dbull.wav', mix(D, (0,0.8,whoosh(0.2,5)), (0.18,1.1,boom(1.1,190,30,0.4)), (0.18,0.8,noise(0.9,0.3,0.3,6)),
  (0.20,0.5,bell(880,1.2,0.55)), (0.36,0.6,bell(1318.5,1.1,0.6)), (0.52,0.4,bell(1760,0.9,0.5))))
