"""CPU-only slice retiming, production and conservative acceptance for retime_bed.

The historical whole-bar/downbeat instruments remain in the report. Beat residuals
are additional evidence, not a replacement for a failing historical measurement.
"""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from numba import njit
from scipy.ndimage import uniform_filter1d
from scipy.signal import butter, sosfiltfilt, resample_poly
from scipy.stats import theilslopes

from audition import SR, HOP, load, lufs, db, kick_envelope, bands, shape, seam, key, wrap
from retime_bed import windowed_lags, lag_summary, DOWNBEAT_MS, DOWNBEAT_REACH_S, at_lufs, retime

FADE = round(.010 * SR)
MUSIC = Path('/home/andrew/Projects/music-video')


def circular(y, start, length):
    return y[np.arange(start, start + length) % len(y)].copy()


def correlation(ref, env, lo, hi, center=0, reach=83):
    """Normalized local envelope correlation; padded periodic context permits negative lags at zero."""
    r = ref[np.arange(lo, hi) % len(ref)].astype(float)
    r -= r.mean()
    norm = np.linalg.norm(r)
    if norm < 1e-8:
        return 0., 0.
    offsets = np.arange(center - reach, center + reach + 1)
    scores = []
    for lag in offsets:
        e = env[(np.arange(lo, hi) + lag) % len(env)].astype(float)
        e -= e.mean()
        scores.append(np.dot(r, e) / max(norm * np.linalg.norm(e), 1e-12))
    k = int(np.argmax(scores))
    frac = 0.
    if 0 < k < len(scores) - 1:
        den = scores[k-1] - 2*scores[k] + scores[k+1]
        frac = .5*(scores[k-1]-scores[k+1])/den if den else 0.
    return float(offsets[k]+frac), float(scores[k])


def periodic_env(y):
    n = len(y)
    # One beat of actual wrap context avoids the first-frame zero-lag bias.
    pad = HOP * 256
    e = kick_envelope(np.concatenate([y[-pad:], y, y[:pad]]))
    return e[pad//HOP:(pad+n)//HOP]


def beat_lags(ref, env, beat, count):
    result, confidence = [], []
    for i in range(count):
        lo, hi = round((i*beat-.030*SR)/HOP), round(((i+1)*beat-.030*SR)/HOP)
        lag, score = correlation(ref, env, lo, hi)
        result.append(lag*HOP/SR*1000)
        confidence.append(score)
    return np.array(result), confidence


def quiet_joins(y, offsets, beat, indices=None):
    """Find a 10 ms low-energy overlap 15-100 ms before each beat, on both source sides.

    Reject windows containing a >6 dB energy rise. Record failed searches rather
    than quietly putting a fade over an attack. Equal-power weights include ends.
    """
    n = beat*len(offsets)
    power = uniform_filter1d(np.mean(y*y, axis=1), round(.003*SR), mode='wrap')
    joins, evidence = [], []
    for i in range(len(offsets)) if indices is None else indices:
        boundary = i*beat
        best = None
        for pos in range(boundary-round(.100*SR), boundary-round(.015*SR)-FADE, 32):
            ids = np.arange(pos, pos+FADE)
            a = power[(ids+offsets[i-1]) % len(y)]
            b = power[(ids+offsets[i]) % len(y)]
            attack = max(float(a[-64:].mean()/max(a[:64].mean(),1e-12)),
                         float(b[-64:].mean()/max(b[:64].mean(),1e-12)))
            energy = float(a.mean()+b.mean())
            score = energy * (1 + max(0., attack-4)*10)
            if best is None or score < best[0]:
                best = (score, pos, attack, energy)
        _, pos, attack, energy = best
        joins.append(pos)
        evidence.append(dict(beat=i+1, sample=pos % n, fade_ms=10,
                             attack_rise_db=round(10*np.log10(max(attack,1e-12)),2),
                             safe=bool(attack <= 4), source_energy_dbfs=round(10*np.log10(max(energy/2,1e-12)),2)))
    return joins, evidence


def assemble(y, offsets, joins, beat):
    n = beat*len(offsets)
    out = np.zeros((n,y.shape[1]))
    theta = np.linspace(0,np.pi/2,FADE)[:,None]
    for i, offset in enumerate(offsets):
        lo = joins[i]
        end = joins[i+1] if i+1 < len(joins) else joins[0]+n
        hi = end+FADE
        part = circular(y,lo+int(offset),hi-lo)
        part[:FADE] *= np.sin(theta)
        part[-FADE:] *= np.cos(theta)
        out[np.arange(lo,hi)%n] += part
    return out


def repair_rendered(drums, result, offsets, joins, guide_env, kick_env, beat, repairs, sources):
    """Rank donors on the edited waveform, not just on the unedited source envelope.

    Crossfades change envelope peaks. Keep every tested residual in the receipt;
    an exhausted donor pool leaves a failing slice instead of claiming success.
    """
    count=len(offsets)
    c=periodic_env(drums)
    for attempt in range(2):
        e=periodic_env(result)
        residual,_=beat_lags(guide_env,e,beat,count)
        changed=False
        for i in range(count):
            lo,hi=round((i*beat-.030*SR)/HOP),round(((i+1)*beat-.030*SR)/HOP)
            klo,khi=round((i*beat-.060*SR)/HOP),round((i*beat+.120*SR)/HOP)
            flam=correlation(kick_env,e,klo,khi,reach=41)[0]*HOP/SR*1000 if i%4==0 else 0.
            if abs(residual[i])<=10 and abs(flam)<=4:
                continue
            best=None
            for j in range(i%4,count,4):
                if j//4==i//4:
                    continue
                base=round((j-i)*beat/HOP)
                shift,_=correlation(guide_env,c,lo,hi,center=base)
                trial_offsets=offsets.copy()
                trial_offsets[i]=round(shift*HOP)
                for refinement in range(3):
                    trial_joins=joins.copy()
                    affected=(i,(i+1)%count)
                    positions,checks=quiet_joins(drums,trial_offsets,beat,affected)
                    for idx,pos in zip(affected,positions):
                        trial_joins[idx]=pos
                    trial=assemble(drums,trial_offsets,trial_joins,beat)
                    # Match the global STFT hop origin, retaining enough context
                    # for the lowpass and spectral flux before this slice.
                    start=(lo-128)*HOP
                    stop=(hi+128)*HOP
                    local=kick_envelope(circular(trial,start,stop-start))
                    env=e.copy()
                    indices=np.arange(lo-64,hi+64)
                    env[indices%len(env)]=local[indices-(lo-128)]
                    lag,quality=correlation(guide_env,env,lo,hi)
                    f=correlation(kick_env,env,klo,khi,reach=41)[0] if i%4==0 else 0.
                    err,flam_ms=lag*HOP/SR*1000,f*HOP/SR*1000
                    score=max(abs(err)/10,abs(flam_ms)/4)
                    rank=(not all(s['safe'] for s in checks),score>1, max(0.,score-1),-quality)
                    if best is None or rank<best[0]:
                        best=(rank,trial_offsets[i],j,err,flam_ms,quality,trial_joins)
                    if score<=1:
                        break
                    correction=f if i%4==0 and abs(flam_ms)>4 else lag
                    trial_offsets[i] += round(correction*HOP)
            rank,shift,donor,err,flam_ms,quality,trial_joins=best
            old_score=max(abs(residual[i])/10,abs(flam)/4)
            if max(abs(err)/10,abs(flam_ms)/4) < old_score:
                offsets[i]=shift
                sources[i]=donor
                joins[:]=trial_joins
                result=assemble(drums,offsets,joins,beat)
                e=periodic_env(result)
                repairs.append(dict(attempt=f'rendered-{attempt+1}',bar=i//4+1,beat=i%4+1,
                    residual_before_ms=round(float(residual[i]),2),donor_bar=donor//4+1,
                    repeat_bars=4 if (donor//4-i//4)%4==0 else 2 if (donor//4-i//4)%2==0 else 1,
                    residual_trial_ms=round(err,2),flam_trial_ms=round(flam_ms,2),correlation=round(quality,3)))
                changed=True
        if not changed:
            break
    return result,offsets,sources


def align(drums, guide, kick, bar, bars):
    beat, count = bar//4, bars*4
    g, c, k = (periodic_env(y[:bar*bars]) for y in (guide,drums,kick))
    initial, _ = beat_lags(g,c,beat,count)
    offsets = np.rint(initial/1000*SR).astype(int)
    # The live kick is the downbeat reference; guide separation can shift its envelope peak.
    for i in range(0,count,4):
        lag,_ = correlation(k,c,round((i*beat-.060*SR)/HOP),round((i*beat+.120*SR)/HOP),reach=41)
        offsets[i] = round(lag*HOP)
    sources = np.arange(count)
    repairs = []
    for attempt in range(3):
        joins, safe = quiet_joins(drums,offsets,beat)
        result = assemble(drums,offsets,joins,beat)
        e = periodic_env(result)
        residual,_ = beat_lags(g,e,beat,count)
        # Replacement is required for a post-alignment error >10 ms. Donors always
        # have the same beat and phrase position at a 1, 2 or 4 bar repeat period.
        bad = np.flatnonzero(np.abs(residual)>10)
        if not len(bad):
            break
        for i in bad:
            options = []
            lo,hi = round((i*beat-.030*SR)/HOP),round(((i+1)*beat-.030*SR)/HOP)
            target = circular(drums,i*beat,beat)
            target_spec = np.abs(np.fft.rfft(target.mean(axis=1),n=2048))
            for j in range(i%4,count,4):
                if j//4 == i//4:
                    continue
                period = 4 if (j//4-i//4)%4 == 0 else 2 if (j//4-i//4)%2 == 0 else 1
                base = round((j-i)*beat/HOP)
                lag,quality = correlation(g,c,lo,hi,center=base)
                candidate = circular(drums,j*beat,beat)
                spec = np.abs(np.fft.rfft(candidate.mean(axis=1),n=2048))
                timbre = np.dot(target_spec,spec)/max(np.linalg.norm(target_spec)*np.linalg.norm(spec),1e-12)
                options.append((quality+.12*timbre+.005*period,j,round(lag*HOP),quality,period))
            _, donor, shift, quality, period = max(options)
            repairs.append(dict(attempt=attempt+1,bar=int(i//4+1),beat=int(i%4+1),
                                residual_before_ms=round(float(residual[i]),2),
                                donor_bar=int(donor//4+1),repeat_bars=period,correlation=round(quality,3)))
            offsets[i],sources[i] = shift,donor
    # A short corrective pass only moves existing slices, and never conceals unresolved repairs.
    for _ in range(2):
        joins,safe = quiet_joins(drums,offsets,beat)
        result = assemble(drums,offsets,joins,beat)
        e = periodic_env(result)
        for i in range(count):
            ref = k if i%4==0 else g
            lo = round((i*beat-(.060 if i%4==0 else .030)*SR)/HOP)
            hi = round((i*beat+.120*SR)/HOP) if i%4==0 else round(((i+1)*beat-.030*SR)/HOP)
            lag,_ = correlation(ref,e,lo,hi,reach=14)
            if abs(lag*HOP/SR*1000) <= 10:
                offsets[i] += round(lag*HOP)
    joins,safe = quiet_joins(drums,offsets,beat)
    result = assemble(drums,offsets,joins,beat)
    result,offsets,sources = repair_rendered(drums,result,offsets,joins,g,k,beat,repairs,sources)
    joins,safe = quiet_joins(drums,offsets,beat)
    result = assemble(drums,offsets,joins,beat)
    return result, dict(offset_samples=offsets.tolist(),source_beat_1based=(sources+1).tolist(),
                        joins=safe,repairs=repairs,initial_beat_lag_ms=np.round(initial,2).tolist())


def continuous_keys(y, guide_env, cover_env, bar, bars):
    """Remove robust global drift without cutting or retriggering any sustained key.

    This tiny constant resampling ratio is reported in cents. It intentionally
    leaves expressive local key timing alone rather than chopping keys with drums.
    The source tail is retained; the eventual loop seam must pass independently.
    """
    lags = windowed_lags(guide_env,cover_env,bar,bars,DOWNBEAT_MS,DOWNBEAT_REACH_S)[0]
    slope,offset,_,_ = theilslopes(lags,np.arange(bars))
    n = bar*bars
    rate = 1+slope/1000*SR/bar
    positions = np.arange(n)*rate + offset/1000*SR
    result = np.stack([np.interp(positions,np.arange(len(y)),y[:,ch]) for ch in range(y.shape[1])],axis=1)
    return result,dict(method='continuous global drift correction; no internal cuts',
                       rate=float(rate),pitch_change_cents=round(float(1200*np.log2(rate)),2),
                       slope_ms_per_bar=round(float(slope),3),loop_join_sample=0,
                       loop_note='Original source tail retained; wrap seam measured independently.')


@njit(cache=True)
def smooth_gain(wanted, attack, release_fast, release_slow):
    out = np.empty(len(wanted))
    level = wanted[-1]
    for repeat in range(3):
        for i in range(len(wanted)):
            coef = attack if wanted[i]>level else release_fast+(release_slow-release_fast)*min(level/4,1.)
            level += (wanted[i]-level)*coef
            out[i] = level
    return out


def glue(drums,other,kick):
    def shelf(y):
        low = sosfiltfilt(butter(2,2500,fs=SR,output='sos'),np.tile(y,(3,1)),axis=0)[len(y):2*len(y)]
        return low + 10**(-3/20)*(y-low)
    drums,other = shelf(drums),shelf(other)
    bed = drums+other
    power = uniform_filter1d(np.mean(bed*bed,axis=1),round(.020*SR),mode='wrap')
    level = 10*np.log10(np.maximum(power,1e-12))
    low_threshold,high_threshold=float(np.min(level)),float(np.max(level))
    for _ in range(12):
        threshold=(low_threshold+high_threshold)/2
        wanted = np.maximum(level-threshold,0)*.5
        gr = smooth_gain(wanted,1-np.exp(-1/(.030*SR)),1-np.exp(-1/(.120*SR)),1-np.exp(-1/(.300*SR)))
        if gr.mean()>1.5:
            low_threshold=threshold
        else:
            high_threshold=threshold
    k = np.sqrt(uniform_filter1d(np.mean(kick*kick,axis=1),round(.003*SR),mode='wrap'))
    duck = smooth_gain(3*np.clip(k/max(np.quantile(k,.98),1e-9),0,1),
                       1-np.exp(-1/(.002*SR)),1-np.exp(-1/(.090*SR)),1-np.exp(-1/(.150*SR)))
    gain = 10**((1-gr-duck)/20)
    return drums*gain[:,None],other*gain[:,None],dict(ratio=2,attack_ms=30,auto_release_ms=[120,300],
        threshold_dbfs=round(threshold,2),makeup_db=1,gain_reduction_mean_db=round(float(gr.mean()),2),
        gain_reduction_p95_db=round(float(np.quantile(gr,.95)),2),gain_reduction_max_db=round(float(gr.max()),2),
        high_shelf_db=-3,high_shelf_hz=2500,duck_max_db=round(float(duck.max()),2),duck_mean_db=round(float(duck.mean()),2))


def joins_report(y,other,bar,bars,joins):
    n=len(y)
    steps=np.abs(y-np.roll(y,1,axis=0)).max(axis=1)
    mask=np.ones(n,dtype=bool)
    for j in joins:
        p=j['sample']
        width=round(j.get('fade_ms',10)/1000*SR)
        mask[np.arange(p-1,p+width+1)%n]=False
    threshold=float(np.quantile(steps[mask],.999))
    body_rms=np.sqrt(np.mean(other*other))
    rows=[]
    for b in range(bars):
        entry=[j for j in joins if (j.get('beat',b*4+1)-1)//4==b]
        stats=[]
        for j in entry:
            p=j['sample']
            width=round(j.get('fade_ms',10)/1000*SR)
            a=circular(y,p-round(.010*SR),round(.010*SR))
            z=circular(y,p+width,round(.010*SR))
            tail=circular(other,p-round(.015*SR),round(.015*SR))
            after=circular(other,p+width,round(.015*SR))
            tail_db=db(np.sqrt(np.mean(tail*tail)))-db(body_rms)
            jump=db(np.sqrt(np.mean(z*z)))-db(np.sqrt(np.mean(a*a)))
            key_jump=db(np.sqrt(np.mean(after*after)))-db(np.sqrt(np.mean(tail*tail)))
            stats.append(dict(sample=p,step_over_body_p999_db=round(db(steps[np.arange(p,p+width+1)%n].max())-db(threshold),2),
                              energy_jump_db=round(jump,2),keys_tail_vs_body_db=round(tail_db,2),
                              sustained_keys=bool(tail_db>-24),keys_energy_jump_db=round(key_jump,2),
                              possible_key_tail_cut=bool(tail_db>-24 and key_jump < -6)))
        rows.append(dict(bar=b+1,max_step_over_body_p999_db=max((r['step_over_body_p999_db'] for r in stats),default=-120),
                         max_abs_energy_jump_db=max((abs(r['energy_jump_db']) for r in stats),default=0),joins=stats))
    return dict(body_p999_step_dbfs=round(db(threshold),2),per_bar=rows,wrap=seam(y))


def timing(y,guide,kick,bar,bars):
    g,k,e=(kick_envelope(a) for a in (guide,kick,y))
    beat,quality=beat_lags(periodic_env(guide),periodic_env(y),bar//4,bars*4)
    step=bar//16
    event_lags,event_margins=windowed_lags(k,e,step,bars*16,(-25.,60.),.060)
    events=[]
    for b in range(bars):
        row=[]
        for s in range(16):
            p=b*bar+s*step
            before=np.sqrt(np.mean(circular(kick,p-round(.010*SR),round(.010*SR))**2))
            attack=np.sqrt(np.mean(circular(kick,p,round(.015*SR))**2))
            # Rising energy on the known sixteenth grid identifies actual hits
            # in the engine solo, including its added second-half syncopation.
            if db(attack)-db(before)>3 and attack>np.abs(kick).max()*.05:
                idx=b*16+s
                row.append(dict(sixteenth=s,lag_ms=round(float(event_lags[idx]),2),
                                at_search_bound=bool(abs(event_lags[idx])>=int(.060*SR/HOP)*HOP/SR*1000-.1),
                                runner_up_peak_ratio=event_margins[idx]))
        events.append(row)
    worst=[max((r['lag_ms'] for r in row),key=abs) if row else None for row in events]
    return dict(after_drift=lag_summary(*windowed_lags(g,e,bar,bars)),
                after_downbeat=lag_summary(*windowed_lags(g,e,bar,bars,DOWNBEAT_MS,DOWNBEAT_REACH_S)),
                flam_whole_bar=lag_summary(*windowed_lags(k,e,bar,bars)),
                flam_downbeat=lag_summary(*windowed_lags(k,e,bar,bars,DOWNBEAT_MS,DOWNBEAT_REACH_S)),
                flam_each_engine_kick=events,flam_worst_per_bar_ms=worst,
                beat_lag_ms=np.round(beat.reshape(bars,4),2).tolist(),
                worst_beat_residual_ms=np.round(np.max(np.abs(beat.reshape(bars,4)),axis=1),2).tolist(),
                beat_correlation=np.round(np.array(quality).reshape(bars,4),3).tolist())


def master(y,path):
    sys.path.insert(0,str(MUSIC))
    from engine.dsp import true_peak_limit
    before=lufs(y)
    gain=-14-before
    for _ in range(8):
        z=true_peak_limit((y*10**(gain/20)).T,ceiling_db=-1.8).T
        loud=lufs(z)
        if abs(loud+14)<.02:
            break
        gain += -14-loud
    sf.write(path,z,SR,subtype='PCM_24')
    opus=path.with_suffix('.opus')
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(path),'-c:a','libopus','-b:a','96k',str(opus)],check=True)
    decoded=path.with_name('opus-decoded.wav')
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(opus),'-ar',str(SR),str(decoded)],check=True)
    enc=load(decoded)
    return z,dict(lufs_before=round(before,2),gain_db=round(gain,2),lufs_after=round(loud,2),
                  peak_dbfs=round(db(np.abs(z).max()),2),true_peak_dbtp=round(db(np.abs(resample_poly(z,4,1,axis=0)).max()),2),
                  opus=dict(path=str(opus),bitrate=96000,lufs=round(lufs(enc),2),peak_dbfs=round(db(np.abs(enc).max()),2),
                            true_peak_dbtp=round(db(np.abs(resample_poly(enc,4,1,axis=0)).max()),2)))


def produce(audition,engine,out,baseline):
    if baseline and out.resolve()==baseline.resolve():
        raise ValueError('slice output must not overwrite the read-only baseline')
    out.mkdir(parents=True,exist_ok=True)
    grid=json.loads((audition/'guide.json').read_text())
    eg=json.loads((engine/'engine.json').read_text())
    bar,bars=grid['samples_per_bar'],grid['bars']
    if (bar,bars)!=(eg['samples_per_bar'],eg['bars']) or bar%4:
        raise ValueError('engine and guide grids must match and contain four integral beats')
    n=bar*bars
    guide=load(audition/'guide-spillway-16bar.drums.wav')[:n]
    cover={s:load(audition/f'cover-spillway-raw.{s}.wav') for s in ('drums','other')}
    renders={s:load(engine/f'engine-{s}.wav') for s in ('above','drums','keys','kick')}
    if any(len(y)!=n for y in renders.values()):
        raise ValueError('engine solo length mismatch')
    print('slice alignment',flush=True)
    drums,edit=align(cover['drums'][:n],guide,renders['kick'],bar,bars)
    other,key_edit=continuous_keys(cover['other'],kick_envelope(guide),kick_envelope(cover['drums']),bar,bars)
    before=timing(cover['drums'][:n],guide,renders['kick'],bar,bars)
    variants={}
    if baseline:
        old=json.loads((baseline/'metrics-hybrid.json').read_text())
        for name,folder in [('drift',baseline),('downbeat',baseline/'downbeat')]:
            # Legacy audition files master each stem separately. Its hybrid used
            # the unmastered arrays instead; reconstruct those exact source maps.
            shifts=old['variants'][name]['shift_samples']
            d=wrap(*retime(cover['drums'],shifts,bar,bars))
            o=wrap(*retime(cover['other'],shifts,bar,bars))
            old_timing=timing(d,guide,renders['kick'],bar,bars)
            d,_=at_lufs(d,lufs(renders['drums']))
            o,_=at_lufs(o,lufs(renders['keys']))
            joins=[dict(beat=b*4+1,sample=(b*bar-round(.025*SR))%n,fade_ms=10) for b in range(bars)]
            joins[0]=dict(beat=1,sample=0,fade_ms=20)
            variants[name]=dict(**old_timing,joins=joins_report(d+o,o,bar,bars,joins),
                                hybrid=old['variants'][name]['hybrid'])
    drums,dgain=at_lufs(drums,lufs(renders['drums']))
    other,ogain=at_lufs(other,lufs(renders['keys']))
    drums,other,processing=glue(drums,other,renders['kick'])
    # AUDIO-V3 section 12.3 keeps the synth core audible at its 0.15 floor.
    # V1 omitted that floor; record this comparison difference explicitly.
    mixed=renders['above']+drums+other+.15*(renders['drums']+renders['keys'])
    processing['synth_core_floor']=.15
    path=out/'hybrid-spillway-16bar.wav'
    mastered,loud=master(mixed,path)
    after=timing(drums,guide,renders['kick'],bar,bars)
    joins=joins_report(drums+other,other,bar,bars,edit['joins'])
    mix_joins=joins_report(mastered,other,bar,bars,edit['joins'])
    passed=dict(residual_all_bars_le_10ms=max(abs(v) for v in after['after_drift']['lag_ms_per_bar'])<=10,
                residual_all_beats_le_10ms=max(after['worst_beat_residual_ms'])<=10,
                flam_all_downbeats_le_5ms=max(abs(v) for v in after['flam_downbeat']['lag_ms_per_bar'])<=5,
                flam_all_engine_kicks_le_5ms=all(v is not None and abs(v)<=5 for v in after['flam_worst_per_bar_ms']),
                joins_under_body_p999=all(r['max_step_over_body_p999_db']<=0 for r in joins['per_bar']) and joins['wrap']['join_over_p999_db']<=0,
                mix_joins_under_body_p999=all(r['max_step_over_body_p999_db']<=0 for r in mix_joins['per_bar']) and mix_joins['wrap']['join_over_p999_db']<=0,
                fades_clear_of_detected_attacks=all(j['safe'] for j in edit['joins']),
                stem_wraps_under_body_p999=all(seam(y)['join_over_p999_db']<=0 for y in (drums,other)),
                loudness=abs(loud['lufs_after']+14)<=.1 and abs(loud['opus']['lufs']+14)<=.2,
                peak=loud['true_peak_dbtp']<-1 and loud['opus']['true_peak_dbtp']<-1)
    loops={}
    for s,y in [('drums',drums),('other',other)]:
        target=out/f'retimed-cover-{s}.candidate.wav'
        sf.write(target,y,SR,subtype='PCM_24')
        loops[s]=dict(path=str(target),seam=seam(y),lufs=round(lufs(y),2))
        if all(passed.values()):
            sf.write(out/f'bed-{s}.loop.wav',y,SR,subtype='PCM_24')
        elif (out/f'bed-{s}.loop.wav').exists():
            stale=out/f'bed-{s}.loop.wav'
            digest=hashlib.sha256(stale.read_bytes()).hexdigest()[:12]
            stale.rename(out/f'bed-{s}.rejected-{digest}.wav')
    variants['slice']=dict(**after,placement=dict(drums_gain_db=dgain,other_gain_db=ogain),
                           edits=edit,keys=key_edit,processing=processing,joins=joins,mix_joins=mix_joins,loops=loops,
                           hybrid=dict(path=str(path),seconds=n/SR,master=loud,lufs=round(lufs(mastered),2),
                                       bands=bands(mastered),**shape(mastered,bar),key=key(mastered)[1],opus=loud['opus']['path']))
    metrics=dict(grid=dict(samples_per_bar=bar,bars=bars,frames=n,sample_rate=SR,bpm=grid['bpm']),
                 method='10 ms equal-power low-energy quarter slices; same-position donor repair; continuous keys',
                 lag_reference='guide separated drums; legacy whole-bar and downbeat plus periodic quarter correlation',
                 flam_reference='engine kick solo, pressure 0.9; envelope correlation, not a listening verdict',
                 before=before,variants=variants,gate=dict(pass_all=all(passed.values()),criteria=passed),
                 limitations=['Envelope correlation is sensitive to different drum patterns and kick timbres.',
                              'Sustained-key flags use energy, not note transcription.',
                              'No human listening acceptance or native engine integration in this task.'])
    if baseline:
        metrics['before_slice']=metrics['before']
        metrics['before']=old['before']
        for field in ('synth','engine','windows'):
            metrics[field]=old[field]
        for name in ('drift','downbeat'):
            metrics['variants'][name]={**old['variants'][name],**metrics['variants'][name]}
    (out/'metrics-hybrid.json').write_text(json.dumps(metrics,indent=2)+'\n')
    hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [path,path.with_suffix('.opus'),
             Path(__file__),Path(__file__).with_name('retime_bed.py'),audition/'guide.json',engine/'engine.json',
             audition/'cover-spillway-raw.drums.wav',audition/'cover-spillway-raw.other.wav',
             audition/'guide-spillway-16bar.drums.wav',*[engine/f'engine-{s}.wav' for s in renders],
             MUSIC/'engine/dsp.py',Path(__file__).with_name('audition.py'),
             Path(__file__).with_name('test_retime_slice.py')]}
    (out/'hashes.json').write_text(json.dumps(hashes,indent=2)+'\n')
    print(json.dumps(dict(gate=metrics['gate'],lag=after['after_drift']['lag_ms_per_bar'],
                         flam=after['flam_downbeat']['lag_ms_per_bar'],master=loud),indent=2),flush=True)
