"""Small CPU regressions for timing, continuity and shared bus processing."""
import unittest
import numpy as np
from audition import SR, HOP, db, seam
from retime_slice import circular, correlation, quiet_joins, assemble, glue, joins_report, timing


class SliceTests(unittest.TestCase):
    def test_signed_periodic_delay_is_not_forced_to_zero_at_start(self):
        t=np.arange(300)
        ref=np.exp(-((t-9)/3)**2)+.5*np.exp(-((t-105)/6)**2)
        for shift in (-7,9):
            lag,quality=correlation(ref,np.roll(ref,shift),-20,65,reach=15)
            self.assertAlmostEqual(lag,shift,places=3)
            self.assertGreater(quality,.99)

    def test_silence_does_not_invent_a_lag(self):
        self.assertEqual(correlation(np.zeros(100),np.zeros(100),0,80), (0.,0.))

    def test_transients_survive_pre_attack_fades_and_periodic_boundary(self):
        beat=SR//4
        t=np.arange(beat*8)/SR
        phase=np.arange(len(t))%beat
        pulse=np.exp(-phase/(.025*SR))*np.sin(2*np.pi*75*t)
        y=np.column_stack((pulse,pulse))
        offsets=np.zeros(8,dtype=int)
        joins,checks=quiet_joins(y,offsets,beat)
        rendered=assemble(y,offsets,joins,beat)
        for i in range(8):
            np.testing.assert_allclose(rendered[i*beat:i*beat+round(.050*SR)],y[i*beat:i*beat+round(.050*SR)],atol=1e-12)
        self.assertTrue(all(c['safe'] for c in checks))
        self.assertLess(seam(rendered)['join_over_p999_db'],0)

    def test_join_probe_detects_introduced_click(self):
        n=SR
        y=np.full((n,2),.1)
        y[n//2:n//2+10] += .5
        row=joins_report(y,y,n,1,[dict(beat=1,sample=n//2,fade_ms=10)])
        self.assertGreater(row['per_bar'][0]['max_step_over_body_p999_db'],100)

    def test_glue_preserves_stereo_and_calibrates_reduction(self):
        n=2*SR
        t=np.arange(n)/SR
        envelope=.05+.1*(np.arange(n)%(SR//2)<SR//10)
        d=np.column_stack([envelope*np.sin(2*np.pi*80*t)]*2)
        o=np.column_stack([.04*np.sin(2*np.pi*330*t)]*2)
        drums,other,metrics=glue(d,o,d)
        self.assertAlmostEqual(metrics['gain_reduction_mean_db'],1.5,delta=.03)
        self.assertLessEqual(metrics['duck_max_db'],3)
        np.testing.assert_allclose(drums[:,0],drums[:,1],atol=1e-12)
        self.assertTrue(np.isfinite(drums+other).all())
        # A shared compressor must not shift one stem against the other.
        self.assertEqual(drums.shape,other.shape)

    def test_flam_checks_syncopated_kicks_as_well_as_downbeats(self):
        bar=61536
        mono=np.zeros(bar*2)
        t=np.arange(round(.07*SR))/SR
        hit=np.sin(2*np.pi*80*t)*np.exp(-t/.015)
        for b,steps in enumerate(([0,10],[0,10,11])):
            for s in steps:
                p=b*bar+s*(bar//16)
                mono[p:p+len(hit)] += hit
        y=np.column_stack((mono,mono))
        report=timing(y,y,y,bar,2)
        self.assertEqual([[r['sixteenth'] for r in row] for row in report['flam_each_engine_kick']],[[0,10],[0,10,11]])
        self.assertTrue(all(abs(v)<.1 for v in report['flam_worst_per_bar_ms']))


if __name__=='__main__':
    unittest.main()
