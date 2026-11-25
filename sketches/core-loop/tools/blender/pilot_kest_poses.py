"""Kest's image observations and bounded body acting on the shared pilot rig."""
import math
import bpy
from mathutils import Vector, Euler
import anim_pilot_drop as anim
import anim_rivet_drop as shared

NOTES=[
    '01: neutral identity, small feather fans extend laterally from both control hands.',
    '02: elbows tuck, feather fans turn inward/down, head gives a small nod.',
    '03: compact high shoulders, wrists close to beak, crest swept back; generated goggles change shape, retain source.',
    '04: deep bow, wing hands over belly, crest upright relative to head; fixed seated legs retained.',
    '05: very broad flat head and torso, wings flung to sides. Image splays feet and adds feathers; preserve source legs and fan count.',
    '06: upward rebound, bent elbows at sides, beak tips upward, small opening.',
    '07: wide lifted arms and head back; source beak hinge approximates generated mouth cavity.',
    '08: strongest head-back caw, arms wide and raised; fewer rigid feathers and smaller beak opening than generated reference.',
    '09: proud wide wings held, head back, crest trails; maintain reference silhouette without added mouth cavity.',
    '10: wings fold back near controls and head returns level; beak closes.',
    '11: right fan up beside right cheek, head rolls toward it, left wrist stays down.',
    '12: beak contacts one right feather; generated eyelid and feather count changes ignored. Contact solved from source beak tip.',
    '13: head lifts away, right wing still slightly high, tiny beak opening, satisfied recovery.',
    '14: right wing drops beside knee while head stays proudly back; left wing at control.', '15: neutral driving pose recovered, wings level at controls.', '16: neutral identity; exact source rest overrides tiny generated proportion changes.',
]
BEAK_TIP=Vector((0, (.475-.2)*1.2325+.015, (.99-1.1)*1.2325+.17))
FEATHER_TIP=Vector((.49,.54,.09))


def contact(arm):
    b=arm.pose.bones['head']
    return b.matrix@b.bone.matrix_local.inverted()@BEAK_TIP


def pose(arm,k):
    pitch=[0,-3,-9,-15,-3,2,4,5,4,0,0,-2,2,-2,0,0][k-1]
    head=[0,-6,-15,-26,-4,14,27,36,31,3,-6,-14,9,20,0,0][k-1]
    bz=[1,.98,.90,.86,.70,1.04,1.12,1.16,1.14,1.03,1,.99,1.04,.98,1,1][k-1]
    hz=[1,1,.98,.96,.62,1,1,1.02,1,1,1,1,1,1,1,1][k-1]
    anim.body(arm,pitch,head,bz,hz,-.025 if k==5 else 0)
    crest=[0,5,20,8,20,-8,-12,-18,8,0,0,5,-5,3,0,0][k-1]
    anim.rotate(arm,'crest',(crest,0,0))
    jaw=[0,0,0,0,0,-10,-28,-40,-35,-4,0,0,-8,0,0,0][k-1]
    anim.rotate(arm,'jaw',(jaw,0,0))
    anim.rotate(arm,'snout',(-jaw*.25,0,0))
    right=(.32,.4,.05);left=(-.32,.4,.05)
    hand_r=(0,0,0);hand_l=(0,0,0)
    if k in (2,3,4):
        x={2:.26,3:.20,4:.17}[k]; y={2:.35,3:.31,4:.32}[k];z={2:.05,3:.01,4:-.12}[k]
        right=(x,y,z);left=(-x,y,z)
        hand_r=(0,15,{2:125,3:145,4:155}[k]);hand_l=(0,-15,-hand_r[2])
        for side in ('L','R'):arm.pose.bones['shoulder.'+side].location.z=.025
    if k in (5,6,7,8,9):
        x={5:.46,6:.46,7:.64,8:.68,9:.66}[k]
        y={5:.12,6:.24,7:.10,8:.05,9:.10}[k]
        z={5:.02,6:.20,7:.16,8:.17,9:.17}[k]
        right=(x,y,z);left=(-x,y,z)
        hand_r=(0,-55 if k>=7 else -30,-8);hand_l=(0,55 if k>=7 else 30,8)
    if k==10:
        right=(.34,.37,.08);left=(-.34,.37,.08)
        hand_r=(0,0,90);hand_l=(0,0,-90)
    if k==11:
        arm.pose.bones['head'].rotation_euler.y=math.radians(12)
        right=(.31,.34,.23);hand_r=(0,-15,55)
    if k==12:
        arm.pose.bones['head'].rotation_euler.y=math.radians(10)
        arm.pose.bones['head'].rotation_euler.z=math.radians(-8)
        bpy.context.view_layer.update()
        hand_r=(0,60,160)
        rotation=Euler(tuple(math.radians(v) for v in hand_r),'XYZ').to_matrix()
        right=contact(arm)-rotation@(FEATHER_TIP-arm.data.bones['hand.R'].head_local)
    if k==13:
        arm.pose.bones['head'].rotation_euler.y=math.radians(-5)
        right=(.35,.38,.14);hand_r=(0,-15,0)
    if k==14:
        right=(.44,.24,-.28);hand_r=(0,55,0)
    bpy.context.view_layer.update()
    if k not in (1,16):
        shared.solve_arm(arm,'R',right,1.12 if k in (7,8,9) else 1)
        shared.solve_arm(arm,'L',left,1.12 if k in (7,8,9) else 1)
        shared.world_hand(arm,'R',hand_r)
        shared.world_hand(arm,'L',hand_l)
