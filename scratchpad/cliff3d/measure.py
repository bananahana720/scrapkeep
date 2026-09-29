import json, hashlib, sys
import numpy as np
from PIL import Image
S = '/home/andrew/Projects/scrapkeep/artifacts/local/visual-development/geo-cliff3/scratchpad/cliff3d/cap'
def load(side, run, cam):
    p = f'{S}/{side}/{run}/subject-context-depth/{cam}.png'
    im = np.array(Image.open(p).convert('RGB'))
    assert im.shape == (1080, 1920, 3), im.shape
    black = (im == 0).all(axis=2)
    grey = (im == 127).all(axis=2)
    other = int((~black & ~grey).sum())
    return black, other, p, hashlib.sha256(open(p, 'rb').read()).hexdigest()
res = {'selection_rule': 'exact RGB (0,0,0) on native 1920x1080 subject-context-depth PNG (dam or G01 subject black, all else grey 127 depth-writing); other-value pixel count reported',
       'lost = count(base_dam_visible AND NOT head_dam_visible); overlap = count(head_G01_visible AND base_dam_visible)': True, 'cams': {}}
for cam in ['launch', 'overview']:
    r = {}
    for dam in ['dam-a', 'dam-b']:
        bb, ob, pb, hb = load('base', dam, cam)
        hh, oh, ph, hh_ = load('head', dam, cam)
        r[dam] = {'base_dam_px': int(bb.sum()), 'head_dam_px': int(hh.sum()),
                  'lost_px': int((bb & ~hh).sum()), 'gained_px': int((hh & ~bb).sum()),
                  'other_value_px': [ob, oh],
                  'files': {'base': pb, 'base_sha256': hb, 'head': ph, 'head_sha256': hh_}}
        gb, ogb, pgb, hgb = load('base', 'g01', cam)
        gh, ogh, pgh, hgh = load('head', 'g01', cam)
        r[dam]['overlap_head_g01_on_base_dam_px'] = int((gh & bb).sum())
        r[dam]['overlap_base_g01_on_base_dam_px'] = int((gb & bb).sum())
        r[dam]['overlap_head_g01_on_head_dam_px'] = int((gh & hh).sum())
    r['g01'] = {'base_px': int(gb.sum()), 'head_px': int(gh.sum()), 'lost_base_g01_px': int((gb & ~gh).sum()), 'new_head_g01_px': int((gh & ~gb).sum()),
                'other_value_px': [ogb, ogh],
                'files': {'base': pgb, 'base_sha256': hgb, 'head': pgh, 'head_sha256': hgh}}
    res['cams'][cam] = r
json.dump(res, open(S + '/../dam_measure.json', 'w'), indent=1)
print(json.dumps({c: {d: {k: v for k, v in x.items() if k != 'files'} for d, x in r.items()} for c, r in res['cams'].items()}, indent=1))
