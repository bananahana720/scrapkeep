# W47-GRAPPLE-3D: the universal grapple rigs (rule G0/G1, Andrew 24 Nov 2026; master bible section 3.1,
# taste rubric section 6b). Every pilot keeps one line; what differs is the hardware of that line, drawn
# as four parts: the Head (what bites), the Line (what it is made of), the Drive (what pays out and reels
# in, and visibly turns) and the Mount (which hub it sits on). One GLB per part, so a build mutation
# swaps exactly one file (the one-part swap law, bible section 3.2).
# Concept: artifacts/local/w46-gate/asset-kinetic-pipeline/sheets/grounded/g10-universal-grapple-rigs-a.png
# and g11-universal-grapple-rigs-b.png. Tally's rig is W47-TALLY-A-3D's (shell_tally.py), not this file's.
#
#   blender -b --factory-startup --python-exit-code 1 -P tools/blender/grapple_rigs.py -- [--out-dir DIR] [--pilot NAME]
#
# Files: assets/models/grapple/grapple_<pilot>_<part>.glb for pilot in sable, rivet, kest, tarn, cannon and
# part in head, line, drive, mount. Detail class (assets/asset_budgets.json: 4,000 tris, 8,000 verts,
# 2 draws); every part here is one mesh on one surface, so one draw, and a whole rig draws four.
#
# Axes: Blender metres, +Y forward, +Z up; glTF and Godot +Y up, -Z forward (Blender (x, y, z) is Godot
# (x, z, -y)). Shell scale: the ball centre is the origin and the cutaway plating is 0.985 m.
#
# Node contract (the binder, W47-GRAPPLE-CODE, finds every node by name):
#   grapple_<pilot>_mount.glb   GrappleMount (empty, the ball centre) > MountRig (skeleton) > Mount (skinned)
#       Mount it at identity under the shell node named in FRAME below (Pod, or Pod > WeaponRing for the
#       pilots whose rig turns with the aim). Sockets (empties under GrappleMount):
#       socket_drive   the drive's axle centre; its local +X is the axle. Put the drive's root here.
#       socket_line    the fairlead the line leaves; its local Blender +Y (Godot -Z) is the rest lead.
#       socket_head    where the head docks at rest, pointing the same way as socket_line.
#       Bones: mount (root, the ball centre) and the one mount actuator in ACTUATORS.
#   grapple_<pilot>_drive.glb   GrappleDrive (empty, the axle centre) > Drive. The axle is local X: spin it
#       about X while the line pays out or reels in (payout positive). Every drive carries a flange tick,
#       a gear or a spring tab off its axis, so a quarter turn reads at the chase camera.
#   grapple_<pilot>_line.glb    GrappleLine (empty) > Line. A one-metre tile from the origin along Blender +Y
#       (Godot -Z): look_at the head from socket_line, then scale local Z to the length or tile it; the
#       strand twist is a whole number of turns per metre, so tiles meet without a seam.
#   grapple_<pilot>_head.glb    GrappleHead (empty, the line's attach eye) > HeadRig (skeleton) > Head
#       (skinned). It bites along Blender +Y (Godot -Z), so look_at aims it. Bones: head (root) and the head
#       actuators in ACTUATORS.
# Every actuator bone points along Blender +Y with no roll, so its rest frame is the model frame; ACTUATORS
# names the axis (Godot frame) each one turns about or slides along, and its bite pose.
# Paint: palette.gd hexes only (common.HEX and STEEL #9aa0a0), vertex colour on one surface per part:
# hydraulic (metal, keeps its colours, hero_assets.gd SLOT_SPECS) for the hardware, paint with take mask 0
# (keeps its colours under any paint) for hemp and braid. No emission and no mint: Sable's petrol lattice
# stays unlit (Andrew call #1), Tarn has no magnet or coil (call #4), Rivet's drill nose is untouched.
# The build fails on a part over its class, an open or inside-out island, or a rest assembly that reaches
# past REACH or hangs below FLOOR_Z outside the ball (the low-reach rule of shell_base.low_reach).

import argparse
import contextlib
import hashlib
import json
import math
import os
import struct
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import common  # noqa: E402
import shell_base as sb  # noqa: E402  (also registers the copper slot)
from common import Part  # noqa: E402

OUT_DIR = os.path.join(common.MODELS, "grapple")
CAP = {"tris": 4000, "verts": 8000, "draws": 1}     # detail class tris and verts; one draw per part by design
REACH = 1.75                                        # ruling en: the visual weapon reach from the ball centre
FLOOR_Z = -0.55                                     # ruling en: slopes never swallow a pod
LOW_RADIUS = 1.0                                    # below FLOOR_Z a part must stay inside the ball silhouette
PILOTS = ("sable", "rivet", "kest", "tarn", "cannon")
PARTS = ("head", "line", "drive", "mount")

STEEL = "9aa0a0"                                    # palette.gd STEEL
STEEL_DARK = common.mix(STEEL, "charcoal", 0.45)
STEEL_WORN = common.mix(STEEL, "bone", 0.40)        # bright wear on blade edges
HEMP = common.mix("sandstone", "bone", 0.35)
BRAID = common.mix("bone", STEEL, 0.40)
SATCHEL = common.mix("amber", "oxide", 0.30)        # Kest's amber satchels (master bible section 4)
SATCHEL_FLAP = common.mix("amber", "oxide", 0.55)

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def godot(v):
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]


def frame(origin=(0, 0, 0), axis=(0, 1, 0)):
    """Matrix taking local +Y to axis, local origin to origin (the lathe frame)."""
    m = Vector((0, 1, 0)).rotation_difference(Vector(axis).normalized()).to_matrix().to_4x4()
    m.translation = Vector(origin)
    return m


def basis(origin, ax, ay, az):
    """Matrix with columns ax, ay, az (any lengths) at origin."""
    m = Matrix.Identity(4)
    for i, v in enumerate((ax, ay, az)):
        for r in range(3):
            m[r][i] = v[r]
    m.translation = Vector(origin)
    return m


def x_to(axis):
    """Quaternion taking local +X to axis, keeping +Z as near up as it can."""
    a = Vector(axis).normalized()
    up = Z if abs(a.dot(Z)) < 0.95 else Y
    b = up.cross(a).normalized()          # local Y
    c = a.cross(b).normalized()           # local Z
    return basis((0, 0, 0), a, b, c).to_quaternion()


# --- one mesh under construction --------------------------------------------------------------------


class Rig:
    """One Part on one slot, every vertex tagged with the bone it is weighted to (when bones are given)."""

    def __init__(self, name, slot="hydraulic", bones=()):
        self.name = name
        self.part = Part(name)
        self.bm = self.part.bm
        self.slot = slot
        self.bones = list(bones)                  # (name, head, parent)
        self.names = [b[0] for b in self.bones]
        self.tag = self.bm.verts.layers.int.new("bone") if self.bones else None
        self.current = self.names[0] if self.bones else None

    @contextlib.contextmanager
    def on(self, bone):
        prev, self.current = self.current, bone
        try:
            yield
        finally:
            self.current = prev

    def _fin(self, faces, color):
        self.part.paint(faces, self.slot, color, alpha=0.0 if self.slot == "paint" else 1.0)
        if self.tag is not None:
            k = self.names.index(self.current) + 1
            for f in faces:
                for v in f.verts:
                    v[self.tag] = k
        return faces

    def v(self, co):
        return self.bm.verts.new(Vector(co))

    def box(self, center, size, color, m=None):
        mat = (m or Matrix.Identity(4)) @ Matrix.Translation(Vector(center)) @ Matrix.Diagonal((*size, 1.0))
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=mat)
        return self._fin(self.part._faces(r["verts"]), color)

    def obox(self, center, axes, size, color):
        """A box at center with edges along the three (unit) axes, sizes along each."""
        a, b, c = (Vector(x).normalized() for x in axes)
        mat = basis(center, a * size[0], b * size[1], c * size[2])
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=mat)
        return self._fin(self.part._faces(r["verts"]), color)

    def beam(self, a, b, w, h, color, up=None):
        a, b = Vector(a), Vector(b)
        d = (b - a)
        ax = d.normalized()
        up = Vector(up) if up is not None else (Z if abs(ax.dot(Z)) < 0.9 else X)
        s = ax.cross(up).normalized()
        u = s.cross(ax).normalized()
        return self.obox((a + b) / 2, (s, ax, u), (w, d.length, h), color)

    def lathe(self, m, profile, sides, colors, roll=None):
        """A closed surface of revolution about local +Y of m; profile (y, r), poles added at open ends.
        colors: one colour or one per band (len(profile) - 1)."""
        roll = math.pi / sides if roll is None else roll
        prof = list(profile)
        cols = list(colors) if isinstance(colors, list) else [colors] * (len(prof) - 1)
        if prof[0][1] > 0:
            prof.insert(0, (prof[0][0], 0.0))
            cols.insert(0, cols[0])
        if prof[-1][1] > 0:
            prof.append((prof[-1][0], 0.0))
            cols.append(cols[-1])
        rings = []
        for y, r in prof:
            if r <= 0:
                rings.append([self.v(m @ Vector((0, y, 0)))])
            else:
                rings.append([self.v(m @ Vector((r * math.cos(roll + k * math.tau / sides), y,
                                                  r * math.sin(roll + k * math.tau / sides))))
                              for k in range(sides)])
        faces = []
        for i in range(len(rings) - 1):
            a, b = rings[i], rings[i + 1]
            band = []
            for k in range(sides):
                j = (k + 1) % sides
                if len(a) == 1:
                    band.append(self.bm.faces.new((a[0], b[j], b[k])))
                elif len(b) == 1:
                    band.append(self.bm.faces.new((a[k], a[j], b[0])))
                else:
                    band.append(self.bm.faces.new((a[k], a[j], b[j], b[k])))
            faces += self._fin(band, cols[i])
        return faces

    def ring_lathe(self, m, loop, sides, colors):
        """A closed torus-like lathe: loop is a closed (y, r) polygon that never touches the axis."""
        cols = list(colors) if isinstance(colors, list) else [colors] * len(loop)
        roll = math.pi / sides
        rings = [[self.v(m @ Vector((r * math.cos(roll + k * math.tau / sides), y,
                                     r * math.sin(roll + k * math.tau / sides)))) for k in range(sides)]
                 for y, r in loop]
        faces = []
        n = len(rings)
        for i in range(n):
            a, b = rings[i], rings[(i + 1) % n]
            band = [self.bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k])) for k in range(sides)]
            faces += self._fin(band, cols[i])
        return faces

    def cyl(self, a, b, r, sides, color, r2=None):
        a, b = Vector(a), Vector(b)
        return self.lathe(frame(a, b - a), [(0.0, r), ((b - a).length, r if r2 is None else r2)], sides, color)

    def sweep(self, pts, radii, sides, color, up=(0, 0, 1), closed=False, roll=0.0):
        pts = [Vector(p) for p in pts]
        n = len(pts)
        radii = list(radii) if isinstance(radii, (list, tuple)) else [radii] * n
        up = Vector(up)
        rings = []
        for i, p in enumerate(pts):
            if closed:
                t = pts[(i + 1) % n] - pts[(i - 1) % n]
            else:
                t = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
            t.normalize()
            u = up - t * up.dot(t)
            if u.length < 1e-6:
                u = t.orthogonal()
            u.normalize()
            b = t.cross(u)
            rings.append([self.v(p + radii[i] * (math.cos(roll + k * math.tau / sides) * u
                                                 + math.sin(roll + k * math.tau / sides) * b))
                          for k in range(sides)])
        faces = []
        for i in range(n if closed else n - 1):
            a, b = rings[i], rings[(i + 1) % n]
            for k in range(sides):
                j = (k + 1) % sides
                faces.append(self.bm.faces.new((a[k], a[j], b[j], b[k])))
        if not closed:
            faces.append(self.bm.faces.new(list(reversed(rings[0]))))
            faces.append(self.bm.faces.new(rings[-1]))
        return self._fin(faces, color)

    def torus(self, center, normal, R, r, segs, sides, color):
        nrm = Vector(normal).normalized()
        u = nrm.orthogonal().normalized()
        w = nrm.cross(u)
        c = Vector(center)
        pts = [c + R * (math.cos(a) * u + math.sin(a) * w) for a in (k * math.tau / segs for k in range(segs))]
        return self.sweep(pts, r, sides, color, up=nrm, closed=True)

    def link(self, center, along, width, L, W, r, color, n=4, sides=6):
        """One chain link: a stadium of wire r, outer length L along `along`, outer width W along `width`."""
        a, w = Vector(along).normalized(), Vector(width).normalized()
        c = Vector(center)
        hl, hw = L / 2 - r, W / 2 - r
        pts = []
        for k in range(n + 1):
            ang = math.pi * k / n
            pts.append(c + a * (hl - hw) + hw * (math.cos(ang) * w + math.sin(ang) * a))
        for k in range(n + 1):
            ang = math.pi + math.pi * k / n
            pts.append(c - a * (hl - hw) + hw * (math.cos(ang) * w + math.sin(ang) * a))
        return self.sweep(pts, r, sides, color, up=a.cross(w), closed=True)

    def prism(self, outline, depth, m, color):
        faces = self.part.prism(self.slot, outline, depth, matrix=m)
        return self._fin(faces, color)

    def gear(self, m, r_root, r_tip, teeth, depth, color):
        """A spur gear: a toothed prism about local +Y of m (depth along Y)."""
        out = []
        for k in range(teeth):
            a = k * math.tau / teeth
            s = math.tau / teeth
            out += [(r_root, a), (r_tip, a + s * 0.2), (r_tip, a + s * 0.45), (r_root, a + s * 0.65)]
        rot = m @ Matrix.Rotation(-math.pi / 2, 4, "X")     # prism depth (local Z) onto local Y
        pts = [(r * math.cos(a), r * math.sin(a)) for r, a in out]
        return self.prism(pts, depth, rot, color)

    def helix_rope(self, strands, r_strand, r_helix, turns, segs, sides, color, length=1.0, phase=0.0):
        faces = []
        for s in range(strands):
            p0 = phase + s * math.tau / strands
            pts = [(r_helix * math.cos(p0 + math.tau * turns * length * i / segs), length * i / segs,
                    r_helix * math.sin(p0 + math.tau * turns * length * i / segs)) for i in range(segs + 1)]
            faces += self.sweep(pts, r_strand, sides, color, up=(0, 0, 1))
        return faces

    def verts(self):
        return [v.co.copy() for v in self.bm.verts]


# --- shared drive pieces (axle along local X) ------------------------------------------------------


AXLE = frame((0, 0, 0), X)


def axle_frame(x):
    return frame((x, 0, 0), X)


def wraps(rig, x0, x1, r_core, r_wire, n, color, segs=14, sides=5):
    for i in range(n):
        x = x0 + (x1 - x0) * (i / (n - 1) if n > 1 else 0.5)
        rig.torus((x, 0, 0), X, r_core + r_wire, r_wire, segs, sides, color)


def flange_ticks(rig, x, r0, r1, color, count=1, w=0.018, h=0.008, start=0.0):
    """Radial ticks proud of a flange face at axle station x (h along the axle, outward sign by x)."""
    sgn = 1 if x >= 0 else -1
    for k in range(count):
        a = start + k * math.tau / count
        d = Vector((0, math.cos(a), math.sin(a)))
        side = Vector((0, -math.sin(a), math.cos(a)))
        rig.obox(Vector((x + sgn * h / 2, 0, 0)) + d * (r0 + r1) / 2, (X, d, side), (h, r1 - r0, w), color)


def bolts(rig, x, radius, count, color, r=0.011, h=0.012, start=0.0):
    sgn = 1 if x >= 0 else -1
    for k in range(count):
        a = start + k * math.tau / count
        c = Vector((x, radius * math.cos(a), radius * math.sin(a)))
        rig.cyl(c - X * sgn * 0.002, c + X * sgn * h, r, 6, color)


# --- the five rigs ---------------------------------------------------------------------------------
# Each pilot: FRAME (the shell node the mount sits under), DRIVE_C and DRIVE_AXIS (world axle centre and
# direction), LINE_AT (the fairlead), HEAD_AT (the rest dock, or None) and the four builders.

HUBS, _, _ = sb.lattice_layout()


class Sable:
    """Forged tow hook with a snap latch on a short forged chain leader, steel cable, the era-2 grapple
    winch at 3 o'clock (shell_sable.py SPOOL_HUB 26, 1.06 m out so the drum wraps the baked SpoolKit
    spool) with a brake lever. Bank Shot: the brake bites, the chain wraps, the latch snaps open on exit."""
    FRAME = "Pod"
    DIR = HUBS[26].normalized()
    DRIVE_C = DIR * 1.06
    DRIVE_AXIS = Y
    UP = (Z - DIR * Z.dot(DIR)).normalized()          # in the cheek plane, away from the ground
    LINE_AT = DRIVE_C + Y * 0.19 + DIR * 0.085 - UP * 0.03
    HEAD_AT = LINE_AT

    @staticmethod
    def drive(rig):
        rig.lathe(AXLE, [(-0.125, 0.022), (0.17, 0.022)], 8, "charcoal")
        rig.lathe(AXLE, [(-0.076, 0.07), (0.076, 0.07)], 12, STEEL_DARK)
        wraps(rig, -0.06, 0.06, 0.07, 0.013, 5, STEEL)
        # The brake drum on the shaft outboard of the forward cheek; the mount's brake shoe bears on it.
        rig.lathe(AXLE, [(0.138, 0.05), (0.166, 0.05)], 14, "charcoal")
        flange_ticks(rig, 0.166, 0.012, 0.046, "copper", count=1, w=0.014, h=0.006)
        for s in (-1, 1):
            rig.lathe(AXLE, [(s * 0.076, 0.115), (s * 0.094, 0.115)], 16, "copper")
        rig.gear(axle_frame(0.101), 0.08, 0.104, 14, 0.014, "charcoal")
        flange_ticks(rig, -0.094, 0.03, 0.11, "bone", count=1, w=0.022)
        bolts(rig, -0.094, 0.05, 3, "charcoal", start=math.pi / 3)

    @classmethod
    def mount(cls, rig):
        c, d, up = cls.DRIVE_C, cls.DIR, cls.UP
        for s in (-1, 1):
            rig.obox(c + Y * s * 0.12 - d * 0.055, (d, Y, up), (0.17, 0.018, 0.13), "petrol")
            rig.cyl(c + Y * s * 0.11, c + Y * s * 0.135, 0.034, 10, "copper")
        rig.obox(c - d * 0.10, (d, Y, up), (0.05, 0.26, 0.15), "petrol")
        for s in (-1, 1):
            for t in (-1, 1):
                p = c - d * 0.075 + Y * s * 0.09 + up * t * 0.055
                rig.cyl(p, p + d * 0.012, 0.010, 6, "copper")
        # Ratchet pawl on the forward cheek, over the gear's teeth.
        rig.beam(c + Y * 0.11 + up * 0.112 - d * 0.03, c + Y * 0.10 + up * 0.10, 0.016, 0.014, "charcoal", up=d)
        # Fairlead: a copper rope ring on a stub arm off the forward cheek's outer lower corner.
        f = cls.LINE_AT
        rig.beam(c + Y * 0.12 + d * 0.02 - up * 0.065, f - Y * 0.012, 0.024, 0.02, "petrol", up=up)
        rig.torus(f, Y, 0.032, 0.011, 12, 6, "copper")
        with rig.on("lever"):
            p = cls.LEVER_PIVOT
            top = p + up * 0.125 + d * 0.02
            rig.cyl(p - Y * 0.016, p + Y * 0.01, 0.016, 8, "copper")
            rig.beam(p, top, 0.016, 0.022, "charcoal", up=Y)
            rig.lathe(frame(top, up), [(0.0, 0.016), (0.03, 0.016)], 8, "bone")
            shoe = c + Y * 0.152 - d * 0.064
            rig.obox(shoe, (d, Y, up), (0.016, 0.026, 0.05), "copper")
            rig.beam(c + Y * 0.178 - d * 0.04, shoe, 0.012, 0.012, "charcoal", up=d)

    LEVER_PIVOT = DRIVE_C + Y * 0.178 - DIR * 0.04 - UP * 0.065

    @staticmethod
    def line(rig):
        rig.lathe(frame((0, 0, 0), Y), [(0.0, 0.012), (1.0, 0.012)], 6, STEEL_DARK)
        rig.helix_rope(3, 0.012, 0.012, 5, 40, 5, STEEL)

    LATCH_HINGE = Vector((0, 0.448, -0.03))

    @classmethod
    def head(cls, rig):
        rig.lathe(frame((0, -0.05, 0), Y), [(0.0, 0.021), (0.05, 0.024)], 8, "copper")
        rig.torus((0, 0.03, 0), Z, 0.028, 0.009, 12, 6, STEEL)
        L, W, r, pitch = 0.09, 0.056, 0.012, 0.044
        for i in range(7):
            yc = 0.085 + i * pitch
            rig.link((0, yc, 0), Y, Z if i % 2 == 0 else X, L, W, r, STEEL_DARK if i % 2 else STEEL)
        rig.torus((0, 0.41, 0), Z, 0.03, 0.012, 12, 6, STEEL_DARK)
        rig.lathe(frame((0, 0.43, 0), Y), [(0.0, 0.03), (0.02, 0.026), (0.08, 0.026)], 10, STEEL_DARK)
        R, cy, cz = 0.075, 0.50, -0.075
        angs = [math.radians(90 - 260 * k / 16) for k in range(17)]
        pts = [(0, cy + R * math.cos(a), cz + R * math.sin(a)) for a in angs]
        radii = [0.028 - 0.015 * k / 16 for k in range(17)]
        rig.sweep(pts, radii, 8, STEEL, up=(1, 0, 0))
        tip = Vector(pts[-1])
        rig.lathe(frame(tip, Vector(pts[-1]) - Vector(pts[-2])), [(0.0, 0.013), (0.03, 0.003)], 8, STEEL_WORN)
        with rig.on("latch"):
            h = cls.LATCH_HINGE
            rig.cyl(h - X * 0.016, h + X * 0.016, 0.009, 8, "copper")
            e = tip + Vector((0, 0.012, 0.02))
            rig.beam(h, e, 0.022, 0.007, "copper", up=X)


class Rivet:
    """Barbed harpoon with a flip-out toggle, braided steel cable drawn dead straight, the era-2 harpoon
    spool with a capstan warping head and a level-wind cable guide, low on the front right of the weapon
    ring so it turns with the aim beside the drill nose (shell_rivet.py DRILL_Z; the nose is untouched).
    Line Drive: the toggle flips out on bite, the capstan reverses and the cable thrums straight."""
    FRAME = "Pod/WeaponRing"
    DRIVE_C = Vector((0.46, 0.96, -0.42))
    DRIVE_AXIS = Y
    LINE_AT = Vector((0.46, 1.112, -0.29))
    HEAD_AT = LINE_AT

    @staticmethod
    def drive(rig):
        rig.lathe(AXLE, [(-0.15, 0.022), (0.255, 0.022)], 8, "charcoal")
        rig.lathe(AXLE, [(-0.091, 0.075), (0.091, 0.075)], 12, STEEL_DARK)
        wraps(rig, -0.077, 0.077, 0.075, 0.0125, 7, STEEL)
        for s in (-1, 1):
            a, b = (0.09, 0.11) if s > 0 else (-0.11, -0.09)
            rig.lathe(axle_frame(0), [(a, 0.112), (a, 0.125), (b, 0.125), (b, 0.112)], 16,
                      ["charcoal", "copper", "charcoal"])
        rig.lathe(AXLE, [(0.14, 0.086), (0.165, 0.074), (0.19, 0.062), (0.215, 0.074), (0.24, 0.086)], 14,
                  "copper")
        for k in range(4):
            a = k * math.tau / 4 + math.pi / 4
            d = Vector((0, math.cos(a), math.sin(a)))
            rig.obox(Vector((0.228, 0, 0)) + d * 0.08, (X, d, d.cross(X)), (0.03, 0.03, 0.03), "charcoal")
        flange_ticks(rig, -0.11, 0.035, 0.12, "bone", count=1, w=0.024)
        bolts(rig, -0.11, 0.055, 4, "copper")

    @classmethod
    def mount(cls, rig):
        c = cls.DRIVE_C
        for y in (0.83, 1.085):
            rig.box((c.x, y, c.z + 0.045), (0.11, 0.02, 0.25), "charcoal")
            rig.cyl((c.x, y - 0.014, c.z), (c.x, y + 0.014, c.z), 0.034, 10, "copper")
        rig.box((c.x, 0.957, c.z + 0.175), (0.05, 0.275, 0.03), "charcoal")
        # Hanger post up to the ring's bearing collar (sb.RING_COLLAR), copper clamp band at its top.
        top = Vector((c.x * 0.99, c.y * 0.99, -0.065))
        rig.cyl((c.x, c.y, c.z + 0.175), top, 0.026, 8, "charcoal")
        rig.cyl(top - Z * 0.03, top + Z * 0.004, 0.034, 8, "copper")
        # Level-wind guide bar along the axle, over the drum.
        rig.cyl((c.x, 0.84, -0.29), (c.x, 1.075, -0.29), 0.011, 8, "copper")
        # Fairlead: four copper rollers framing a square window on the front cheek's top.
        f = cls.LINE_AT
        rig.box((f.x, f.y - 0.006, f.z + 0.01), (0.10, 0.012, 0.08), "charcoal")
        for s in (-1, 1):
            rig.cyl(f + Vector((s * 0.03, 0.006, -0.038)), f + Vector((s * 0.03, 0.006, 0.045)), 0.009, 8, "copper")
            rig.cyl(f + Vector((-0.045, 0.006, s * 0.03)), f + Vector((0.045, 0.006, s * 0.03)), 0.009, 8, "copper")
        rig.beam((f.x, 1.085, f.z - 0.05), (f.x, f.y - 0.01, f.z - 0.05), 0.04, 0.02, "charcoal")
        with rig.on("guide"):
            g = Vector((c.x, 0.957, -0.29))
            rig.box(g, (0.05, 0.045, 0.036), "charcoal")
            for s in (-1, 1):
                rig.cyl(g + Vector((-0.03, s * 0.012, -0.03)), g + Vector((0.03, s * 0.012, -0.03)), 0.009, 8, "copper")

    GUIDE_AT = Vector((0.46, 0.957, -0.29))

    @staticmethod
    def line(rig):
        rig.lathe(frame((0, 0, 0), Y), [(0.0, 0.011), (1.0, 0.011)], 6, STEEL_DARK)
        rig.helix_rope(3, 0.013, 0.011, 8, 48, 5, STEEL)

    TOGGLE_HINGE = Vector((0, 0.352, 0.032))

    @classmethod
    def head(cls, rig):
        rig.lathe(frame((0, -0.04, 0), Y), [(0.0, 0.02), (0.04, 0.024)], 8, "copper")
        rig.torus((0, 0.022, 0), X, 0.022, 0.008, 10, 6, STEEL)
        rig.lathe(frame((0, 0.04, 0), Y), [(0.0, 0.02), (0.30, 0.02)], 8, STEEL_DARK)
        for y0 in (0.06, 0.27):
            rig.lathe(frame((0, y0, 0), Y), [(0.0, 0.026), (0.02, 0.026)], 8, "copper")
        rig.lathe(frame((0, 0.34, 0), Y), [(0.0, 0.034), (0.02, 0.04), (0.12, 0.003)], 10, STEEL)
        for k in range(3):
            a = math.pi / 2 + k * math.tau / 3 + math.pi / 3
            rad = Vector((math.cos(a), 0, math.sin(a)))
            tg = Y.cross(rad)
            m = basis((0, 0, 0), Y, rad, tg)
            rig.prism([(0.41, 0.022), (0.345, 0.07), (0.37, 0.024)], 0.008, m, STEEL_WORN)
        with rig.on("toggle"):
            h = cls.TOGGLE_HINGE
            rig.cyl(h - X * 0.018, h + X * 0.018, 0.009, 8, "charcoal")
            rig.box((0, 0.27, 0.032), (0.024, 0.17, 0.012), "copper")


class Kest:
    """Grapnel with slotted vane flukes (her fin vanes), light braided aviation wire, a spring reel under
    the perch with a satchel trolley riding the line. Cable Charge: the flukes snap open, the trolley rolls
    down the line and the clacker fires it. Kest stays seated inside the ball; nothing here enters it."""
    FRAME = "Pod"
    DRIVE_C = Vector((0.0, 1.02, -0.42))
    DRIVE_AXIS = X
    LINE_AT = Vector((0.0, 1.15, -0.33))
    HEAD_AT = LINE_AT
    TROLLEY_AT = LINE_AT + Vector((0, 0.07, 0))

    @staticmethod
    def drive(rig):
        rig.lathe(AXLE, [(-0.14, 0.018), (0.11, 0.018)], 8, "charcoal")
        rig.lathe(AXLE, [(-0.066, 0.06), (0.066, 0.06)], 12, STEEL_DARK)
        wraps(rig, -0.052, 0.052, 0.06, 0.0105, 6, BRAID)
        for s in (-1, 1):
            rig.lathe(AXLE, [(s * 0.066, 0.105), (s * 0.08, 0.105)], 16, STEEL)
        rig.lathe(AXLE, [(-0.08, 0.10), (-0.112, 0.10)], 16, "copper")
        for rr in (0.04, 0.065, 0.088):
            rig.torus((-0.114, 0, 0), X, rr, 0.005, 16, 4, "charcoal")
        flange_ticks(rig, -0.112, 0.012, 0.095, "charcoal", count=1, w=0.02, h=0.012)
        flange_ticks(rig, 0.08, 0.03, 0.10, "bone", count=1, w=0.02)

    @classmethod
    def mount(cls, rig):
        c = cls.DRIVE_C
        for x in (-0.13, 0.095):
            rig.beam((x, 0.90, -0.24), (x, c.y, c.z), 0.03, 0.05, "petrol", up=X)
            rig.cyl((x - 0.015, c.y, c.z), (x + 0.015, c.y, c.z), 0.03, 10, "copper")
        rig.beam((-0.145, 0.915, -0.26), (0.11, 0.915, -0.26), 0.03, 0.03, "petrol")
        f = cls.LINE_AT
        rig.beam((0.095, 0.99, -0.29), f + Vector((0.025, -0.01, 0.02)), 0.02, 0.02, "petrol")
        rig.torus(f, Y, 0.024, 0.0075, 12, 6, STEEL)
        with rig.on("trolley"):
            t = cls.TROLLEY_AT
            for s in (-1, 1):
                rig.lathe(frame(t + Vector((-0.012, s * 0.026, 0.035)), X), [(0.0, 0.022), (0.024, 0.022)], 10, STEEL)
            rig.box(t + Vector((0.02, 0, 0.03)), (0.008, 0.09, 0.05), "petrol")
            rig.beam(t + Vector((0.02, 0, 0.01)), t + Vector((0.02, 0, -0.035)), 0.01, 0.01, "charcoal")
            rig.box(t + Vector((0.0, 0, -0.075)), (0.075, 0.09, 0.075), SATCHEL)
            rig.box(t + Vector((0.0, -0.002, -0.05)), (0.08, 0.094, 0.03), SATCHEL_FLAP)
            rig.box(t + Vector((0.0, -0.048, -0.065)), (0.018, 0.006, 0.022), "bone")
            rig.cyl(t + Vector((0.025, 0.03, -0.04)), t + Vector((0.035, 0.03, 0.0)), 0.005, 6, "charcoal")

    FLUKE_HINGE_Y = 0.30
    FLUKE_R = 0.032
    FLUKE_OPEN = math.radians(55)

    @classmethod
    def flukes(cls):
        out = []
        for k in range(3):
            phi = math.pi / 2 + k * math.tau / 3
            rad = Vector((math.cos(phi), 0, math.sin(phi)))
            tg = Vector((-math.sin(phi), 0, math.cos(phi)))
            hinge = Vector((0, cls.FLUKE_HINGE_Y, 0)) + rad * cls.FLUKE_R
            d = (-Y * math.cos(cls.FLUKE_OPEN) + rad * math.sin(cls.FLUKE_OPEN)).normalized()
            out.append((k, hinge, d, tg))
        return out

    @staticmethod
    def line(rig):
        rig.helix_rope(2, 0.0095, 0.0085, 10, 60, 5, BRAID)

    @classmethod
    def head(cls, rig):
        rig.lathe(frame((0, -0.035, 0), Y), [(0.0, 0.016), (0.035, 0.019)], 8, "copper")
        rig.torus((0, 0.018, 0), X, 0.018, 0.007, 10, 6, STEEL)
        rig.lathe(frame((0, 0.03, 0), Y), [(0.0, 0.014), (0.27, 0.014)], 8, STEEL_DARK)
        rig.lathe(frame((0, 0.28, 0), Y), [(0.0, 0.03), (0.04, 0.03), (0.10, 0.004)], 10, ["copper", STEEL])
        for k, hinge, d, tg in cls.flukes():
            with rig.on("fluke.%d" % k):
                nrm = d.cross(tg).normalized()
                rig.cyl(hinge - tg * 0.014, hinge + tg * 0.014, 0.008, 6, "copper")
                rig.cyl(hinge, hinge + d * 0.21, 0.009, 6, STEEL_DARK)
                for off in (-0.03, 0.0, 0.03):
                    rig.obox(hinge + d * 0.13 + tg * off, (tg, d, nrm), (0.017, 0.15, 0.006), "petrol")
                for s in (0.055, 0.205):
                    rig.obox(hinge + d * s, (tg, d, nrm), (0.078, 0.012, 0.009), STEEL)


class Tarn:
    """The claw itself: one articulated worn-steel claw launches on heavy hemp rope from the era-2 pull
    drum low at the rear. The drum rides the weapon ring with the claws, so it never crosses them at any
    aim, and the rope runs round the lower right flank in oxide clips to a roller fairlead at 3 o'clock.
    Claw Drag: the claw fires off its ram and clamps, the drum winds while the rams brace. No magnet and
    no coil (Andrew call #4: magnets are the Fleet's, copper coil is Sable's)."""
    FRAME = "Pod/WeaponRing"
    DRIVE_C = Vector((0.0, -0.95, -0.40))
    DRIVE_AXIS = X
    LINE_AT = Vector((1.10, 0.10, -0.24))
    HEAD_AT = LINE_AT
    PAWL_AT = DRIVE_C + Vector((0.222, 0.05, 0.16))

    @staticmethod
    def drive(rig):
        rig.lathe(AXLE, [(-0.25, 0.03), (0.25, 0.03)], 8, "charcoal")
        rig.lathe(AXLE, [(-0.171, 0.10), (0.171, 0.10)], 12, "charcoal")
        wraps(rig, -0.145, 0.145, 0.10, 0.023, 6, HEMP, segs=16, sides=6)
        for s in (-1, 1):
            a, b = (0.17, 0.196) if s > 0 else (-0.196, -0.17)
            rig.lathe(AXLE, [(a, 0.152), (b, 0.152)], 16, "oxide")
        rig.gear(axle_frame(0.204), 0.10, 0.128, 12, 0.016, "charcoal")
        bolts(rig, -0.196, 0.11, 6, STEEL, r=0.013)
        flange_ticks(rig, -0.196, 0.035, 0.145, "bone", count=1, w=0.026)

    @classmethod
    def mount(cls, rig):
        c = cls.DRIVE_C
        for s in (-1, 1):
            x = s * 0.232
            rig.box((x, c.y, c.z + 0.01), (0.026, 0.13, 0.2), "oxide")
            rig.cyl((x - s * 0.016, c.y, c.z), (x + s * 0.018, c.y, c.z), 0.042, 10, "copper")
            rig.beam((x, c.y + 0.02, c.z + 0.1), (s * 0.20, -1.035, -0.07), 0.05, 0.04, "oxide")
        rig.cyl((-0.24, -1.13, c.z), (0.24, -1.13, c.z), 0.02, 8, "charcoal")
        for s in (-1, 1):
            rig.beam((s * 0.232, -1.08, c.z), (s * 0.232, -1.13, c.z), 0.03, 0.03, "oxide")
        # The rope run: the hemp leaves the drum's top, runs round the lower right flank at 1.05 m in
        # three oxide clips and reaches the fairlead at 3 o'clock.
        start = c + Vector((0.12, 0.02, 0.124))
        run = [start]
        for k in range(1, 10):
            a = math.radians(-90 + 90 * k / 9)
            rr = 1.07
            run.append(Vector((rr * math.cos(a), rr * math.sin(a) + 0.0 * k, -0.30 + 0.06 * k / 9)))
        run.append(cls.LINE_AT - Y * 0.05)
        rig.sweep(run, 0.022, 6, HEMP, up=(0, 0, 1))
        for k in (3, 5, 7):
            p = run[k]
            tdir = (run[k + 1] - run[k - 1]).normalized()
            out = Vector((p.x, p.y, 0)).normalized()
            rig.obox(p, (tdir, out, Z), (0.03, 0.05, 0.06), "oxide")
        f = cls.LINE_AT
        rig.box(f - Y * 0.035, (0.10, 0.03, 0.10), "oxide")
        for s in (-1, 1):
            rig.cyl(f + Vector((s * 0.034, -0.01, -0.05)), f + Vector((s * 0.034, -0.01, 0.05)), 0.012, 8, "copper")
            rig.cyl(f + Vector((-0.05, -0.01, s * 0.034)), f + Vector((0.05, -0.01, s * 0.034)), 0.012, 8, "copper")
        rig.beam(f - Y * 0.05 - X * 0.04, Vector((1.02, 0.02, -0.08)), 0.04, 0.04, "oxide")
        with rig.on("pawl"):
            p = cls.PAWL_AT
            rig.cyl(p - X * 0.012, p + X * 0.012, 0.014, 8, "copper")
            rig.beam(p, c + Vector((0.215, 0.0, 0.132)), 0.02, 0.022, "charcoal", up=X)

    @staticmethod
    def line(rig):
        rig.helix_rope(3, 0.022, 0.018, 4, 40, 6, HEMP)

    TALON_HINGE = 0.25
    TALONS = ((math.radians(90 - 42), 1.0), (math.radians(90 + 42), 1.0), (math.radians(270), 1.15))

    @classmethod
    def talons(cls):
        out = []
        for k, (phi, scale) in enumerate(cls.TALONS):
            rad = Vector((math.cos(phi), 0, math.sin(phi)))
            tg = Vector((-math.sin(phi), 0, math.cos(phi)))
            hinge = Vector((0, cls.TALON_HINGE, 0)) + rad * 0.05
            out.append((k, hinge, rad, tg, scale))
        return out

    @classmethod
    def head(cls, rig):
        rig.lathe(frame((0, -0.05, 0), Y), [(0.0, 0.03), (0.05, 0.034)], 8, "copper")
        rig.torus((0, 0.02, 0), X, 0.03, 0.011, 10, 6, STEEL_DARK)
        rig.lathe(frame((0, 0.04, 0), Y), [(0.0, 0.07), (0.02, 0.076), (0.08, 0.076), (0.10, 0.066)], 12,
                  ["charcoal", "oxide", "charcoal"])
        rig.obox((0, 0.19, 0), (X, Y, Z), (0.16, 0.13, 0.13), "oxide")
        rig.obox((0, 0.19, 0.068), (X, Y, Z), (0.12, 0.10, 0.012), "bone")
        rig.cyl((0, 0.07, 0.085), (0, 0.17, 0.085), 0.022, 8, "copper")
        rig.cyl((0, 0.17, 0.085), (0, 0.235, 0.075), 0.012, 8, STEEL)
        for s in (-1, 1):
            rig.cyl((s * 0.08, 0.15, 0), (s * 0.095, 0.15, 0), 0.03, 8, STEEL_DARK)
        for k, hinge, rad, tg, scale in cls.talons():
            with rig.on("talon.%d" % k):
                rig.cyl(hinge - tg * 0.03, hinge + tg * 0.03, 0.022, 8, STEEL_DARK)
                L = 0.30 * scale
                pts, radii = [], []
                for i in range(9):
                    t = i / 8
                    ang = math.radians(12 - 70 * t)      # leaves 12 deg outward, curls 58 deg inward
                    along = L * math.sin(math.radians(80) * t) * 0.95
                    off = rad * (L * 0.32 * math.sin(math.pi * t * 0.9) - L * 0.18 * t * t)
                    pts.append(hinge + Y * along + off)
                    radii.append(0.034 - 0.028 * t)
                rig.sweep(pts, radii, 7, STEEL_DARK, up=tg)
                edge = [p - rad * (r * 0.85) for p, r in zip(pts[2:], radii[2:])]
                rig.sweep(edge, [0.008 - 0.005 * i / (len(edge) - 1) for i in range(len(edge))], 5, STEEL_WORN, up=tg)


class Cannon:
    """Explosive piton with a shaped-charge cap, short armoured steel cable, a recoil anchor winch low on
    the right side hub by the split ports (shell_cannon.py PORT_DIR), level under the bone barrel's sweep.
    Stake / Breach: the piton drives in, the lock dog holds the cable rigid against recoil, the cap fires
    on release."""
    FRAME = "Pod"
    DRIVE_C = Vector((0.97, -0.24, -0.40))
    DRIVE_AXIS = Y
    DRZ = Vector((0.97, 0, -0.40)).normalized()
    UP = Vector((0.40, 0, 0.97)).normalized()
    LINE_AT = DRIVE_C + Y * 0.17 + DRZ * 0.06 + UP * 0.06
    HEAD_AT = LINE_AT
    LOCK_AT = DRIVE_C - Y * 0.14 + UP * 0.07 + DRZ * 0.02

    @staticmethod
    def drive(rig):
        rig.lathe(AXLE, [(-0.13, 0.02), (0.13, 0.02)], 8, "charcoal")
        rig.lathe(AXLE, [(-0.071, 0.065), (0.071, 0.065)], 12, STEEL_DARK)
        wraps(rig, -0.056, 0.056, 0.065, 0.013, 5, STEEL)
        for s in (-1, 1):
            a, b = (0.07, 0.088) if s > 0 else (-0.088, -0.07)
            rig.lathe(AXLE, [(a, 0.035), (a, 0.11), (b, 0.11), (b, 0.035)], 16, ["charcoal", "bone", "charcoal"])
        rig.gear(axle_frame(0.095), 0.108, 0.13, 16, 0.014, "copper")
        bolts(rig, -0.088, 0.075, 4, "charcoal", r=0.012)
        # One dash of the barrel's harmonic green (palette ANCIENT, unlit) on the rear flange: the turn read.
        flange_ticks(rig, -0.088, 0.04, 0.105, "ancient", count=1, w=0.03)

    @classmethod
    def mount(cls, rig):
        c, d, up = cls.DRIVE_C, cls.DRZ, cls.UP
        for s in (-1, 1):
            rig.obox(c + Y * s * 0.115 - d * 0.05, (d, Y, up), (0.17, 0.02, 0.12), "petrol")
            rig.cyl(c + Y * s * 0.103, c + Y * s * 0.128, 0.032, 10, "copper")
        rig.obox(c - d * 0.10, (d, Y, up), (0.05, 0.25, 0.15), "petrol")
        # Pinion and motor on the forward cheek, meshing with the drive's copper gear.
        pin = c + up * 0.152 + Y * 0.095
        rig.cyl(pin - Y * 0.01, pin + Y * 0.02, 0.025, 10, "copper")
        rig.cyl(pin + Y * 0.02, pin + Y * 0.10, 0.034, 10, "charcoal")
        rig.obox(c + up * 0.10 + Y * 0.115, (d, Y, up), (0.06, 0.03, 0.10), "petrol")
        f = cls.LINE_AT
        rig.beam(c + Y * 0.12 + up * 0.03, f - Y * 0.012, 0.024, 0.02, "petrol", up=up)
        rig.torus(f, Y, 0.03, 0.011, 12, 6, "copper")
        with rig.on("lock"):
            p = cls.LOCK_AT
            rig.cyl(p - Y * 0.012, p + Y * 0.012, 0.015, 8, "copper")
            tip = p + up * 0.11 + d * 0.04
            rig.beam(p, tip, 0.016, 0.02, "charcoal", up=Y)
            rig.lathe(frame(tip, up), [(0.0, 0.016), (0.028, 0.016)], 8, "bone")
            rig.beam(p, p + d * 0.06 - up * 0.04, 0.016, 0.02, "charcoal", up=Y)

    @staticmethod
    def line(rig):
        rig.helix_rope(3, 0.011, 0.009, 6, 36, 5, STEEL)
        for k in range(8):
            y = 0.0625 + 0.125 * k
            rig.lathe(frame((0, y - 0.025, 0), Y), [(0.0, 0.026), (0.006, 0.03), (0.044, 0.03), (0.05, 0.026)], 8,
                      STEEL_DARK)

    CAP_AT = Vector((0, 0.065, 0))

    @classmethod
    def head(cls, rig):
        rig.lathe(frame((0, -0.04, 0), Y), [(0.0, 0.02), (0.04, 0.022)], 8, "copper")
        rig.torus((0, 0.026, 0), X, 0.024, 0.008, 10, 6, STEEL)
        rig.lathe(frame((0, 0.045, 0), Y), [(0.0, 0.016), (0.22, 0.016)], 8, STEEL_DARK)
        rig.lathe(frame((0, 0.25, 0), Y), [(0.0, 0.03), (0.01, 0.042), (0.035, 0.042), (0.045, 0.034)], 10, "copper")
        rig.lathe(frame((0, 0.29, 0), Y), [(0.0, 0.032), (0.11, 0.027), (0.29, 0.004)], 10, STEEL)
        for k in range(4):
            a = k * math.tau / 4 + math.pi / 4
            rad = Vector((math.cos(a), 0, math.sin(a)))
            m = basis((0, 0, 0), Y, rad, Y.cross(rad))
            rig.prism([(0.30, 0.02), (0.31, 0.058), (0.36, 0.05), (0.45, 0.018)], 0.008, m, STEEL_DARK)
        with rig.on("cap"):
            loop = [(0.07, 0.019), (0.07, 0.05), (0.095, 0.055), (0.115, 0.055), (0.125, 0.055), (0.18, 0.055),
                    (0.205, 0.046), (0.232, 0.02)]
            cols = ["charcoal", "charcoal", "bone", "ancient", "bone", "charcoal", "copper", "copper"]
            rig.ring_lathe(frame((0, 0, 0), Y), loop, 12, cols)


RIGS = {"sable": Sable, "rivet": Rivet, "kest": Kest, "tarn": Tarn, "cannon": Cannon}

# Actuators the binder drives in bone-local space (Blender frame, matching rivet_revolvers.py:
# +Y is forward along the line, +X is right, +Z is up; angles in degrees, right-hand rule).
def vec3(v):
    return [round(v[0], 4), round(v[1], 4), round(v[2], 4)]


ACTUATORS = {
    "sable": {"mount": {"lever": {"turn_about": vec3(Y), "bite": -18, "why": "the brake lever bites the gear rim"}},
              "head": {"latch": {"turn_about": vec3(X), "open": 55, "why": "the snap latch swings into the throat on exit"}}},
    "rivet": {"mount": {"guide": {"slide_along": vec3(Y), "travel_m": [-0.09, 0.09], "why": "the level-wind traverses the drum as it winds"}},
              "head": {"toggle": {"turn_about": vec3(X), "bite": 90, "why": "the toggle flips out athwart the shaft on bite"}}},
    "kest": {"mount": {"trolley": {"slide_along": vec3(Y), "why": "the satchel trolley rides down the wire from socket_line to the head"}},
             "head": {"fluke.%d" % k: {"turn_about": vec3(tg), "fold": -50, "why": "rest is open (bite); fold for flight"}
                      for k, _, _, tg in Kest.flukes()}},
    "tarn": {"mount": {"pawl": {"turn_about": vec3(X), "lift": 20, "why": "the drum pawl lifts while the drum winds"}},
             "head": {"talon.%d" % k: {"turn_about": vec3(tg), "clamp": 35, "why": "rest is open; the fingers clamp inward on bite"}
                      for k, _, _, tg, _ in Tarn.talons()}},
    "cannon": {"mount": {"lock": {"turn_about": vec3(Y), "lock": -25, "why": "the lock dog holds the cable rigid against recoil"}},
               "head": {"cap": {"slide_along": vec3(-Y), "pop_m": 0.25, "why": "the shaped-charge cap pops off the tail on release"}}},
}


def bones_for(pilot, part):
    if part == "mount":
        name, at = {"sable": ("lever", Sable.LEVER_PIVOT), "rivet": ("guide", Rivet.GUIDE_AT),
                    "kest": ("trolley", Kest.TROLLEY_AT), "tarn": ("pawl", Tarn.PAWL_AT),
                    "cannon": ("lock", Cannon.LOCK_AT)}[pilot]
        return [("mount", Vector((0, 0, 0)), None), (name, at, "mount")]
    if part == "head":
        out = [("head", Vector((0, 0, 0)), None)]
        if pilot == "sable":
            out.append(("latch", Sable.LATCH_HINGE, "head"))
        elif pilot == "rivet":
            out.append(("toggle", Rivet.TOGGLE_HINGE, "head"))
        elif pilot == "kest":
            out += [("fluke.%d" % k, hinge, "head") for k, hinge, _, _ in Kest.flukes()]
        elif pilot == "tarn":
            out += [("talon.%d" % k, hinge, "head") for k, hinge, _, _, _ in Tarn.talons()]
        elif pilot == "cannon":
            out.append(("cap", Cannon.CAP_AT, "head"))
        return out
    return []


# --- checks, rig, export ---------------------------------------------------------------------------


def islands(bm):
    bm.faces.index_update()
    seen, out = set(), []
    for start in bm.faces:
        if start.index in seen:
            continue
        group, stack = [], [start]
        seen.add(start.index)
        while stack:
            f = stack.pop()
            group.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        out.append(group)
    return out


def closed_report(obj):
    """MANIFOLD line (rivet_revolvers.closed_report): open, non-manifold and inside-out islands after a weld."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    boundary = sum(1 for e in bm.edges if len(e.link_faces) == 1)
    nonmanifold = sum(1 for e in bm.edges if len(e.link_faces) > 2)
    groups = islands(bm)
    inverted = 0
    for g in groups:
        vol = 0.0
        for f in g:
            vs = [v.co for v in f.verts]
            for i in range(1, len(vs) - 1):
                vol += vs[0].dot(vs[i].cross(vs[i + 1])) / 6.0
        inverted += 1 if vol <= 0.0 else 0
    bm.free()
    print("MANIFOLD %s islands=%d boundary=%d nonmanifold=%d inverted=%d" % (obj.name, len(groups), boundary,
                                                                            nonmanifold, inverted))
    return boundary == 0 and nonmanifold == 0 and inverted == 0


def smooth(obj, angle=40.0):
    for p in obj.data.polygons:
        p.use_smooth = True
    try:
        obj.data.set_sharp_from_angle(angle=math.radians(angle))
    except AttributeError:
        for p in obj.data.polygons:
            p.use_smooth = False


def make_armature(root, obj, bones, arm_name):
    data = bpy.data.armatures.new(arm_name)
    arm = bpy.data.objects.new(arm_name, data)
    bpy.context.scene.collection.objects.link(arm)
    common.place(arm, (0, 0, 0), root)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.scene.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, parent in bones:
        b = data.edit_bones.new(name)
        b.head = head
        b.tail = head + Vector((0, 0.04, 0))
        b.roll = 0.0
        if parent:
            b.parent = data.edit_bones[parent]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.parent = arm
    obj.matrix_parent_inverse.identity()
    obj.location = (0, 0, 0)
    mod = obj.modifiers.new("Rig", "ARMATURE")
    mod.object = arm
    tags = obj.data.attributes["bone"]
    names = [b[0] for b in bones]
    for i, name in enumerate(names):
        ids = [v.index for v in obj.data.vertices if tags.data[v.index].value == i + 1]
        obj.vertex_groups.new(name=name).add(ids, 1.0, "REPLACE")
    untagged = sum(1 for v in obj.data.vertices if tags.data[v.index].value == 0)
    if untagged:
        raise SystemExit("%s: %d vertices carry no bone" % (obj.name, untagged))
    obj.data.attributes.remove(tags)
    return arm


def export_glb(root, path, arm=None):
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in common.tree(root):
        o.select_set(True)
    if arm is not None:
        bpy.context.view_layer.objects.active = arm
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=False,
                              export_def_bones=False, export_skins=arm is not None, export_apply=arm is None,
                              export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
                              export_extras=False, export_cameras=False, export_lights=False)
    common.canonical_indices(path, vertices=True)


def gltf_metrics(path):
    data = open(path, "rb").read()
    n = struct.unpack("<I", data[12:16])[0]
    g = json.loads(data[20:20 + n])
    tris = verts = draws = 0
    mats = set()
    lo, hi = [9e9] * 3, [-9e9] * 3
    for mesh in g["meshes"]:
        for p in mesh["primitives"]:
            draws += 1
            acc = g["accessors"][p["attributes"]["POSITION"]]
            verts += acc["count"]
            tris += g["accessors"][p["indices"]]["count"] // 3
            lo = [min(a, b) for a, b in zip(lo, acc["min"])]
            hi = [max(a, b) for a, b in zip(hi, acc["max"])]
            if "material" in p:
                mats.add(g["materials"][p["material"]]["name"])
    nodes = sorted(nd.get("name", "") for nd in g["nodes"])
    joints = sorted(g["nodes"][j].get("name", "") for s in g.get("skins", []) for j in s["joints"])
    return {"tris": tris, "verts": verts, "draws": draws, "materials": sorted(mats), "nodes": nodes,
            "bones": joints, "size": [round(h - l, 4) for l, h in zip(lo, hi)]}


ROOTS = {"head": "GrappleHead", "line": "GrappleLine", "drive": "GrappleDrive", "mount": "GrappleMount"}
MESHES = {"head": "Head", "line": "Line", "drive": "Drive", "mount": "Mount"}
RIG_NAMES = {"head": "HeadRig", "mount": "MountRig"}


def sockets_for(pilot):
    r = RIGS[pilot]
    out = {"socket_drive": (r.DRIVE_C, x_to(r.DRIVE_AXIS)), "socket_line": (r.LINE_AT, None)}
    if r.HEAD_AT is not None:
        out["socket_head"] = (r.HEAD_AT, None)
    return out


def build_part(pilot, part, out_dir):
    common.reset()
    r = RIGS[pilot]
    slot = "paint" if (part == "line" and pilot in ("kest", "tarn")) else "hydraulic"
    bones = bones_for(pilot, part)
    rig = Rig(MESHES[part], slot, bones)
    getattr(r, part)(rig)
    bmesh.ops.recalc_face_normals(rig.bm, faces=rig.bm.faces[:])
    local = rig.verts()
    root = common.empty(ROOTS[part])
    obj = rig.part.to_object((0, 0, 0), root)
    smooth(obj)
    closed = closed_report(obj)
    arm = make_armature(root, obj, bones, RIG_NAMES[part]) if bones else None
    if part == "mount":
        for name, (loc, q) in sockets_for(pilot).items():
            e = common.empty(name, loc, root)
            if q is not None:
                e.rotation_mode = "QUATERNION"
                e.rotation_quaternion = q
    path = os.path.join(out_dir, "grapple_%s_%s.glb" % (pilot, part))
    export_glb(root, path, arm)
    m = gltf_metrics(path)
    m.update({"file": os.path.basename(path), "sha256": hashlib.sha256(open(path, "rb").read()).hexdigest(),
              "closed": closed})
    print("GRAPPLE_EXPORT", pilot, part, json.dumps(m, sort_keys=True))
    ok = closed and m["tris"] <= CAP["tris"] and m["verts"] <= CAP["verts"] and m["draws"] <= CAP["draws"]
    return ok, m, local


def assembly_report(pilot, locals_):
    """Reach and floor of the rest assembly: the mount, the drive at socket_drive, the head at socket_head."""
    r = RIGS[pilot]
    pts = list(locals_["mount"])
    q = x_to(r.DRIVE_AXIS)
    pts += [r.DRIVE_C + q @ p for p in locals_["drive"]]
    if r.HEAD_AT is not None:
        pts += [r.HEAD_AT + p for p in locals_["head"]]
    reach = max(p.length for p in pts)
    low = min(p.z for p in pts)
    outside = [p for p in pts if p.z < FLOOR_Z and p.length > LOW_RADIUS]
    ok = reach <= REACH and not outside
    print("GRAPPLE_ASSEMBLY %s frame=%s reach=%.4f (limit %.2f) low=%.4f low_outside_ball=%d %s" % (
        pilot, r.FRAME, reach, REACH, low, len(outside), "ok" if ok else "OUT"))
    return ok, {"frame": r.FRAME, "reach": round(reach, 4), "low": round(low, 4)}


def manifest(pilot):
    r = RIGS[pilot]
    return {"frame": r.FRAME,
            "socket_drive": godot(r.DRIVE_C), "drive_axle": godot(r.DRIVE_AXIS),
            "socket_line": godot(r.LINE_AT), "socket_head": godot(r.HEAD_AT) if r.HEAD_AT is not None else None,
            "actuators": ACTUATORS[pilot]}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default=OUT_DIR)
    ap.add_argument("--pilot", choices=PILOTS, action="append")
    args = ap.parse_args(argv)
    ok = True
    for pilot in args.pilot or PILOTS:
        locals_ = {}
        for part in PARTS:
            good, _, local = build_part(pilot, part, args.out_dir)
            ok = ok and good
            locals_[part] = local
        good, _ = assembly_report(pilot, locals_)
        ok = ok and good
        print("GRAPPLE_MANIFEST", pilot, json.dumps(manifest(pilot), sort_keys=True))
    if not ok:
        raise SystemExit("grapple_rigs: a part is over its class, open, or the rest assembly is out of reach")


if __name__ == "__main__":
    main()
