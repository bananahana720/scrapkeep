"""Storyboard stills for the Sable title intro (design-v3/TITLE-INTROS.md).

Run from the repo root:  blender -b -P sketches/core-loop/design-v3/storyboards/intro-sable/render_shots.py -- 01,02,03 final
Shots: 01 02 03 04 05 06 07 08 08b 09 10 11. Quality: draft (480x270) or final (960x540).
Output goes to artifacts/local/intro-sable/<quality>/, which git ignores.
"""
import sys, os; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__))); from render_lib import *
args=sys.argv[sys.argv.index("--")+1:]
which=args[0]; q=args[1] if len(args)>1 else "draft"
RES=(960,540) if q=="final" else (480,270); SMP=28 if q=="final" else 10
OUT=os.path.join(os.getcwd(),"artifacts","local","intro-sable",q)+"/"; os.makedirs(OUT,exist_ok=True)
def pose(root, action, frame):
    for o in root.children_recursive:
        if o.animation_data is not None or o.type=='ARMATURE':
            if o.animation_data is None: o.animation_data_create()
            a=bpy.data.actions.get(action)
            if a: o.animation_data.action=a
    bpy.context.scene.frame_set(frame)

def s01():  # postcard: the dam at dawn
    reset(RES,SMP, ink_w=1.0); sky((0.30,0.45,0.85),(1.0,0.62,0.38))
    d=load("world_one/dam.glb",(0,0,-26))
    plane(2000,(0,0,0),(0.18,0.42,0.38))
    plane(2000,(0,-300,-2),(0.55,0.42,0.30))
    ball("sable",(18,2,90.5),(0,0,200),scale=2.2)
    cam((-30,140,4),(8,0,62),lens=24,roll=-6)
    sun((70,0,-120),4.0,(1,0.8,0.6))
    render(OUT+"01.png")
def s02():  # low-angle hero, backlit
    reset(RES,SMP, ink_w=1.6); sky((0.95,0.55,0.25),(1.0,0.88,0.55))
    plane(200,(0,0,0),(0.35,0.30,0.25))
    b=ball("sable",(0,0,1.0),(0,0,10))
    cam((0.6,3.2,0.25),(0,0,1.55),lens=24,roll=-8)
    sun((120,0,180),3.0,(1,0.75,0.5)); point((1.5,2.5,0.5),120,(0.6,1,0.85)); point((-2,-2,3),300,(1,0.6,0.3))
    render(OUT+"02.png")
def s03():  # freeze-frame name card portrait
    reset(RES,SMP, ink_w=2.0); sky((0.55,0.95,0.80),(0.95,0.95,0.55))
    p=load("pilot_sable_anim.glb",(0,0,0)); pose(p,"big_cheer",30)
    cam((0.9,3.0,0.45),(0,0,0.35),lens=55,roll=6)
    sun((60,0,150),3.5); point((2,2,1),80,(0.6,1,0.85))
    render(OUT+"03.png")
def s04():  # action: launch over the chasers
    reset(RES,SMP, ink_w=1.4); sky((0.25,0.55,0.95),(0.85,0.95,1.0))
    plane(400,(0,0,0),(0.40,0.36,0.28))
    for i,(x,y,r) in enumerate([(-2.5,1,30),(1.5,-1.5,-60),(3.5,2.5,120)]):
        load("world_one/enemy_chaser.glb",(x,y,1.5),(25*(i-1),40,r))
    ball("sable",(0.5,0.5,4.6),(-30,15,40),scale=1.3)
    cam((-4,9,2.0),(0.4,0,3.4),lens=22,roll=-14)
    sun((45,10,140),4.0)
    render(OUT+"04.png")
def s05():  # roll call portraits
    for name,bg in [("rivet",((0.45,0.9,0.75),(0.2,0.45,0.4))),("kest",((0.95,0.6,0.35),(0.6,0.25,0.2))),("tarn",((0.95,0.45,0.35),(0.4,0.15,0.2)))]:
        reset((RES[0]//2,RES[1]),SMP, ink_w=1.6); sky(*bg)
        ball(name,(0,0,0),(0,0,0))
        cam((0.6,3.1,0.3),(0,0,0.15),lens=45,roll=4)
        sun((50,0,150),3.5); point((-2,1,2),120,(1,0.9,0.8))
        render(OUT+f"05_{name}.png")
def s06():  # collision: Brindle's machine, dutch tilt
    reset(RES,SMP, ink_w=1.2); sky((0.25,0.05,0.08),(0.85,0.30,0.15))
    plane(800,(0,0,0),(0.20,0.16,0.15))
    b=load("bosses/boss_brindle.glb",(0,-6,0),(0,0,200),scale=1.3); pose(b,"charge_warn",20)
    ball("sable",(5.5,8,1.0),(0,0,200),scale=1.0)
    cam((7.0,14,0.6),(-1,-6,7),lens=22,roll=14)
    sun((40,0,0),2.0,(1,0.5,0.3)); point((0,8,4),800,(1,0.35,0.2),2)
    render(OUT+"06.png")
def s07():  # Brindle name card portrait
    reset(RES,SMP, ink_w=2.0); sky((0.85,0.25,0.25),(0.98,0.80,0.45))
    s=load("bosses/boss_brindle_scooter.glb",(0,0,0),(0,0,0))
    cam((0.9,-2.9,1.0),(0,0.2,0.15),lens=38,roll=-7)
    sun((60,0,-30),3.5); point((1.5,-1.5,2),100,(1,0.8,0.6))
    render(OUT+"07.png")
def s08():  # the sad part: rain on one spot
    reset(RES,SMP, ink_w=1.2); sky((0.03,0.04,0.07),(0.07,0.09,0.14),0.3)
    plane(200,(0,0,0),(0.10,0.11,0.14))
    b=ball("sable",(0,0,1.0),(8,-12,0),pose_name="slump",pose_frame=30)
    l=bpy.data.objects.new("spot",bpy.data.lights.new("spot","SPOT")); l.data.energy=900; l.data.spot_size=math.radians(28); l.data.color=(0.7,0.8,1.0); l.location=(0,0,9); bpy.context.scene.collection.objects.link(l)
    cam((0.6,5.2,1.7),(0,0,0.9),lens=50,roll=0)
    render(OUT+"08.png")
def s08b():  # flashback panel: the Cannon (sepia applied on the page)
    reset((RES[0]//2,RES[1]),SMP, ink_w=1.8); sky((0.9,0.85,0.75),(0.7,0.6,0.5))
    load("pilot_cannon_anim.glb",(0,0,0),(0,0,0))
    bpy.context.scene.render.film_transparent=True
    cam((0.8,3.0,0.6),(0,0,0.1),lens=45,roll=-4)
    sun((50,0,140),3.5)
    render(OUT+"08b.png")
def s09():  # the wink: Moss's barge arrives in the rain
    reset(RES,SMP, ink_w=1.0); sky((0.06,0.08,0.12),(0.25,0.28,0.35),0.4)
    plane(1000,(0,0,0),(0.10,0.11,0.14))
    ball("sable",(1.2,6,1.0),(0,0,200))
    load("moss_hover_barge.glb",(-4,-30,9),(0,0,35),scale=0.5)
    cam((3.5,13,0.8),(-3,-25,8),lens=26,roll=-5)
    sun((60,0,30),1.5,(0.8,0.85,1.0)); point((-4,-22,4),9000,(1.0,0.75,0.45),4); point((-4,-30,16),4000,(1.0,0.85,0.6),3)
    render(OUT+"09.png")
def s10():  # back up: the Highdraft and the Mind's hand
    reset(RES,SMP, ink_w=1.0); sky((0.15,0.40,0.95),(0.98,0.88,0.75))
    load("highdraft/island_large.glb",(-35,-70,-4),(0,0,20))
    load("highdraft/island_medium.glb",(45,-95,22),(0,0,40))
    load("highdraft/island_small.glb",(20,-40,-18))
    h=load("warden_mind.glb",(8,-55,6),(0,0,180),scale=3.2); pose(h,"quote",15)
    ball("sable",(-2.5,18,4),(25,0,30),scale=1.4)
    cam((-4,34,-6),(4,-40,12),lens=20,roll=10)
    sun((50,0,210),4.0)
    render(OUT+"10.png")
def s11():  # title slam: the crew on the deck
    reset(RES,SMP, ink_w=1.4); sky((0.35,0.20,0.45),(1.0,0.65,0.35))
    plane(100,(0,0,0),(0.30,0.28,0.26))
    for n,x,y in [("rivet",-2.6,-0.6),("sable",0,0.4),("kest",2.6,-0.6),("tarn",-5.0,-1.6),("tally",5.0,-1.6)]:
        ball(n,(x,y,1.0),(0,0,0))
    cam((0,12,1.0),(0,-0.6,1.3),lens=40)
    sun((110,0,180),2.5,(1,0.7,0.4)); point((0,6,5),900,(1,0.85,0.7),3)
    render(OUT+"11.png")
for w in which.split(","):
    globals()["s"+w]()
