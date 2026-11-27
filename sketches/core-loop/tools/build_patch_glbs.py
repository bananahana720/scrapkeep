#!/usr/bin/env python3
"""Deterministic pure-Python glTF 2.0 (.glb) generator for Patch (7th hidden pilot, line_splicer).

Generates:
  1. assets/models/pilot_patch_anim.glb
     - Canonical 25-bone skeleton (PatchRig), bilateral rest symmetry (err == 0.0000 m),
       normalized float32 skin weights (sum == 1.0), 4 watertight manifold meshes
       (Pilot, TailBase, TailTip, Tool: 2010 stickered silver netbook + splice probe),
       and 8 expressive 30fps clips (idle_loop, brace, drop_land, heave, big_cheer, phew, slump, wince).
  2. assets/models/world_one/shell_patch.glb
     - Cutaway-first salvaged splicer ball with Core (32 Hub + 30 Gap lattice sockets),
       Pod, Dome (Pilot + PilotSeat), Gyro -> GyroInner, SpliceDish (wok-cut parabolic dish
       with quadripod feedhorn), CableSpool, WeaponRing (twin signal-tapper coils + forward mount),
       RopeExit, and Control.* sockets within Ruling en bounds.
"""

from __future__ import annotations

import json
import math
import pathlib
import struct
from typing import Callable

ROOT_DIR = pathlib.Path(__file__).resolve().parents[1]
PILOT_GLB_PATH = ROOT_DIR / "assets" / "models" / "pilot_patch_anim.glb"
SHELL_GLB_PATH = ROOT_DIR / "assets" / "models" / "world_one" / "shell_patch.glb"
SHELL_SABLE_PATH = ROOT_DIR / "assets" / "models" / "world_one" / "shell_sable.glb"

HAZARD_RGB = (1.0, 0.352941, 0.235294)


def srgb_to_lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgba(hex_str: str, alpha: float = 1.0) -> tuple[float, float, float, float]:
    h = hex_str.lstrip("#")
    sr = int(h[0:2], 16) / 255.0
    sg = int(h[2:4], 16) / 255.0
    sb = int(h[4:6], 16) / 255.0
    dist_hazard = math.sqrt((sr - HAZARD_RGB[0]) ** 2 + (sg - HAZARD_RGB[1]) ** 2 + (sb - HAZARD_RGB[2]) ** 2)
    if dist_hazard < 0.16:
        raise ValueError(f"Color #{h} too close to Palette.HAZARD ({dist_hazard:.3f})")
    return (srgb_to_lin(sr), srgb_to_lin(sg), srgb_to_lin(sb), alpha)


COL_FUR = hex_rgba("6e747a")
COL_FUR_DARK = hex_rgba("4d5359")
COL_CREAM = hex_rgba("e8e4da")
COL_EAR_DARK = hex_rgba("2b2d30")
COL_PINK = hex_rgba("d98ca3")
COL_NOSE_PINK = hex_rgba("ea7fa0")
COL_VERDIGRIS = hex_rgba("365754")
COL_VERDIGRIS_LIGHT = hex_rgba("4d7570")
COL_COPPER = hex_rgba("b77843")
COL_BRASS = hex_rgba("caa05a")
COL_CHARCOAL = hex_rgba("242a28")
COL_SLATE = hex_rgba("515a5c")
COL_SILVER = hex_rgba("b8c2c6")
COL_STICKER_TEAL = hex_rgba("63d2be")
COL_STICKER_GOLD = hex_rgba("d9b45b")
COL_STICKER_PINK = hex_rgba("ea7fa0")
COL_WHITE_PAINT = (1.0, 1.0, 1.0, 1.0)


def v_add(a: tuple[float, float, float], b: tuple[float, float, float]) -> tuple[float, float, float]:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def v_sub(a: tuple[float, float, float], b: tuple[float, float, float]) -> tuple[float, float, float]:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def v_mul(a: tuple[float, float, float], s: float) -> tuple[float, float, float]:
    return (a[0] * s, a[1] * s, a[2] * s)


def v_dot(a: tuple[float, float, float], b: tuple[float, float, float]) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def v_cross(a: tuple[float, float, float], b: tuple[float, float, float]) -> tuple[float, float, float]:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def v_len(a: tuple[float, float, float]) -> float:
    return math.sqrt(v_dot(a, a))


def v_norm(a: tuple[float, float, float]) -> tuple[float, float, float]:
    l = v_len(a)
    if l < 1e-12:
        return (0.0, 1.0, 0.0)
    return (a[0] / l, a[1] / l, a[2] / l)


def c_lerp(a: tuple[float, float, float, float], b: tuple[float, float, float, float], t: float) -> tuple[float, float, float, float]:
    u = max(0.0, min(1.0, t))
    return (
        a[0] + (b[0] - a[0]) * u,
        a[1] + (b[1] - a[1]) * u,
        a[2] + (b[2] - a[2]) * u,
        a[3] + (b[3] - a[3]) * u,
    )


def quat_from_euler_xyz(rx: float, ry: float, rz: float) -> tuple[float, float, float, float]:
    cx, sx = math.cos(rx * 0.5), math.sin(rx * 0.5)
    cy, sy = math.cos(ry * 0.5), math.sin(ry * 0.5)
    cz, sz = math.cos(rz * 0.5), math.sin(rz * 0.5)
    qw = cx * cy * cz - sx * sy * sz
    qx = sx * cy * cz + cx * sy * sz
    qy = cx * sy * cz - sx * cy * sz
    qz = cx * cy * sz + sx * sy * cz
    n = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
    return (qx / n, qy / n, qz / n, qw / n)


def mat4_from_trs(
    t: tuple[float, float, float],
    q: tuple[float, float, float, float],
    s: tuple[float, float, float] = (1.0, 1.0, 1.0),
) -> list[float]:
    x, y, z, w = q
    xx, yy, zz = x * x, y * y, z * z
    xy, xz, yz = x * y, x * z, y * z
    wx, wy, wz = w * x, w * y, w * z
    sx, sy, sz = s
    return [
        (1.0 - 2.0 * (yy + zz)) * sx,
        (2.0 * (xy + wz)) * sx,
        (2.0 * (xz - wy)) * sx,
        0.0,
        (2.0 * (xy - wz)) * sy,
        (1.0 - 2.0 * (xx + zz)) * sy,
        (2.0 * (yz + wx)) * sy,
        0.0,
        (2.0 * (xz + wy)) * sz,
        (2.0 * (yz - wx)) * sz,
        (1.0 - 2.0 * (xx + yy)) * sz,
        0.0,
        t[0],
        t[1],
        t[2],
        1.0,
    ]


def mat4_mul(a: list[float], b: list[float]) -> list[float]:
    out = [0.0] * 16
    for col in range(4):
        for row in range(4):
            out[col * 4 + row] = sum(a[k * 4 + row] * b[col * 4 + k] for k in range(4))
    return out


def mat4_inv_rigid(m: list[float]) -> list[float]:
    r00, r10, r20 = m[0], m[1], m[2]
    r01, r11, r21 = m[4], m[5], m[6]
    r02, r12, r22 = m[8], m[9], m[10]
    tx, ty, tz = m[12], m[13], m[14]
    itx = -(r00 * tx + r10 * ty + r20 * tz)
    ity = -(r01 * tx + r11 * ty + r21 * tz)
    itz = -(r02 * tx + r12 * ty + r22 * tz)
    return [
        r00, r01, r02, 0.0,
        r10, r11, r12, 0.0,
        r20, r21, r22, 0.0,
        itx, ity, itz, 1.0,
    ]


def basis_from_axis(forward_axis: tuple[float, float, float], up_hint: tuple[float, float, float] = (0.0, 1.0, 0.0)):
    ax_y = v_norm(forward_axis)
    if abs(v_dot(ax_y, up_hint)) > 0.94:
        up_hint = (0.0, 0.0, 1.0) if abs(ax_y[2]) < 0.8 else (1.0, 0.0, 0.0)
    ax_x = v_norm(v_cross(up_hint, ax_y))
    ax_z = v_norm(v_cross(ax_y, ax_x))
    return ax_x, ax_y, ax_z


def xform_point(
    origin: tuple[float, float, float],
    ax_x: tuple[float, float, float],
    ax_y: tuple[float, float, float],
    ax_z: tuple[float, float, float],
    local: tuple[float, float, float],
) -> tuple[float, float, float]:
    return (
        origin[0] + ax_x[0] * local[0] + ax_y[0] * local[1] + ax_z[0] * local[2],
        origin[1] + ax_x[1] * local[0] + ax_y[1] * local[1] + ax_z[1] * local[2],
        origin[2] + ax_x[2] * local[0] + ax_y[2] * local[1] + ax_z[2] * local[2],
    )


def normalize_weights(pairs: list[tuple[int, float]]) -> tuple[tuple[int, int, int, int], tuple[float, float, float, float]]:
    merged: dict[int, float] = {}
    for bidx, w in pairs:
        if w > 1e-6:
            merged[bidx] = merged.get(bidx, 0.0) + float(w)
    if not merged:
        merged = {0: 1.0}
    top = sorted(merged.items(), key=lambda kv: kv[1], reverse=True)[:4]
    while len(top) < 4:
        top.append((0, 0.0))
    total = sum(w for _, w in top)
    if total <= 1e-8:
        return (0, 0, 0, 0), (1.0, 0.0, 0.0, 0.0)
    raw = [struct.unpack("<f", struct.pack("<f", w / total))[0] for _, w in top]
    rem = 1.0 - (raw[1] + raw[2] + raw[3])
    raw[0] = struct.unpack("<f", struct.pack("<f", max(0.0, rem)))[0]
    joints = (top[0][0], top[1][0], top[2][0], top[3][0])
    weights = (raw[0], raw[1], raw[2], raw[3])
    return joints, weights


class SurfaceData:
    def __init__(self, material_name: str, skinned: bool = False):
        self.material_name = material_name
        self.skinned = skinned
        self.positions: list[tuple[float, float, float]] = []
        self.normals: list[tuple[float, float, float]] = []
        self.uvs: list[tuple[float, float]] = []
        self.colors: list[tuple[float, float, float, float]] = []
        self.joints: list[tuple[int, int, int, int]] = []
        self.weights: list[tuple[float, float, float, float]] = []
        self.indices: list[int] = []

    def add_lofted_tube(
        self,
        stations: list[tuple[tuple[float, float, float], float, float, tuple[float, float, float, float]]],
        axis_dir: tuple[float, float, float],
        segs: int = 12,
        up_hint: tuple[float, float, float] = (0.0, 1.0, 0.0),
        shape_pow: float = 1.0,
        skin_fn: Callable[[tuple[float, float, float]], list[tuple[int, float]]] | None = None,
        color_override_fn: Callable[[tuple[float, float, float], tuple[float, float, float], tuple[float, float, float, float]], tuple[float, float, float, float]] | None = None,
    ) -> None:
        assert len(stations) >= 2 and segs >= 4
        ax_x, ax_y, ax_z = basis_from_axis(axis_dir, up_hint)
        local_pos: list[tuple[float, float, float]] = []
        local_uv: list[tuple[float, float]] = []
        local_col: list[tuple[float, float, float, float]] = []
        local_tris: list[tuple[int, int, int]] = []

        ring_indices: list[list[int]] = []
        n_st = len(stations)
        for si, (center, rx, rz, base_col) in enumerate(stations):
            v_coord = si / max(1, n_st - 1)
            ring: list[int] = []
            for k in range(segs):
                ang = (2.0 * math.pi * k) / segs
                ca, sa = math.cos(ang), math.sin(ang)
                if abs(shape_pow - 1.0) > 1e-4:
                    ca = math.copysign(abs(ca) ** shape_pow, ca)
                    sa = math.copysign(abs(sa) ** shape_pow, sa)
                p = xform_point(center, ax_x, ax_y, ax_z, (ca * rx, 0.0, sa * rz))
                idx = len(local_pos)
                local_pos.append(p)
                local_uv.append((k / segs, v_coord))
                local_col.append(base_col)
                ring.append(idx)
            ring_indices.append(ring)

        c0, _, _, col0 = stations[0]
        p_bot = v_add(c0, v_mul(ax_y, -0.0025))
        bot_idx = len(local_pos)
        local_pos.append(p_bot)
        local_uv.append((0.5, 0.0))
        local_col.append(col0)

        c_last, _, _, col_last = stations[-1]
        p_top = v_add(c_last, v_mul(ax_y, 0.0025))
        top_idx = len(local_pos)
        local_pos.append(p_top)
        local_uv.append((0.5, 1.0))
        local_col.append(col_last)

        r0 = ring_indices[0]
        for k in range(segs):
            nk = (k + 1) % segs
            local_tris.append((bot_idx, r0[k], r0[nk]))

        for si in range(n_st - 1):
            ra = ring_indices[si]
            rb = ring_indices[si + 1]
            for k in range(segs):
                nk = (k + 1) % segs
                local_tris.append((ra[k], rb[k], rb[nk]))
                local_tris.append((ra[k], rb[nk], ra[nk]))

        rl = ring_indices[-1]
        for k in range(segs):
            nk = (k + 1) % segs
            local_tris.append((top_idx, rl[nk], rl[k]))

        self._commit_submesh(local_pos, local_uv, local_col, local_tris, skin_fn, color_override_fn)

    def add_curved_tube(
        self,
        spine: list[tuple[tuple[float, float, float], float, float, tuple[float, float, float, float]]],
        segs: int = 12,
        up_hint: tuple[float, float, float] = (0.0, 1.0, 0.0),
        skin_fn: Callable[[tuple[float, float, float]], list[tuple[int, float]]] | None = None,
    ) -> None:
        assert len(spine) >= 2
        local_pos: list[tuple[float, float, float]] = []
        local_uv: list[tuple[float, float]] = []
        local_col: list[tuple[float, float, float, float]] = []
        local_tris: list[tuple[int, int, int]] = []
        ring_indices: list[list[int]] = []
        n_st = len(spine)

        tangents: list[tuple[float, float, float]] = []
        for i in range(n_st):
            if i == 0:
                tangents.append(v_norm(v_sub(spine[1][0], spine[0][0])))
            elif i == n_st - 1:
                tangents.append(v_norm(v_sub(spine[-1][0], spine[-2][0])))
            else:
                tangents.append(v_norm(v_sub(spine[i + 1][0], spine[i - 1][0])))

        cur_up = up_hint
        for si, (center, rx, rz, col) in enumerate(spine):
            t_dir = tangents[si]
            ax_x, ax_y, ax_z = basis_from_axis(t_dir, cur_up)
            cur_up = ax_z
            ring: list[int] = []
            for k in range(segs):
                ang = (2.0 * math.pi * k) / segs
                p = xform_point(center, ax_x, ax_y, ax_z, (math.cos(ang) * rx, 0.0, math.sin(ang) * rz))
                idx = len(local_pos)
                local_pos.append(p)
                local_uv.append((k / segs, si / max(1, n_st - 1)))
                local_col.append(col)
                ring.append(idx)
            ring_indices.append(ring)

        p_bot = v_add(spine[0][0], v_mul(tangents[0], -0.0025))
        bot_idx = len(local_pos)
        local_pos.append(p_bot)
        local_uv.append((0.5, 0.0))
        local_col.append(spine[0][3])

        p_top = v_add(spine[-1][0], v_mul(tangents[-1], 0.0025))
        top_idx = len(local_pos)
        local_pos.append(p_top)
        local_uv.append((0.5, 1.0))
        local_col.append(spine[-1][3])

        for k in range(segs):
            nk = (k + 1) % segs
            local_tris.append((bot_idx, ring_indices[0][k], ring_indices[0][nk]))
        for si in range(n_st - 1):
            ra, rb = ring_indices[si], ring_indices[si + 1]
            for k in range(segs):
                nk = (k + 1) % segs
                local_tris.append((ra[k], rb[k], rb[nk]))
                local_tris.append((ra[k], rb[nk], ra[nk]))
        for k in range(segs):
            nk = (k + 1) % segs
            local_tris.append((top_idx, ring_indices[-1][nk], ring_indices[-1][k]))

        self._commit_submesh(local_pos, local_uv, local_col, local_tris, skin_fn, None)

    def add_chamfered_box(
        self,
        center: tuple[float, float, float],
        size: tuple[float, float, float],
        bevel: float,
        body_col: tuple[float, float, float, float],
        edge_col: tuple[float, float, float, float] | None = None,
        axis_dir: tuple[float, float, float] = (0.0, 1.0, 0.0),
        up_hint: tuple[float, float, float] = (0.0, 0.0, 1.0),
        skin_fn: Callable[[tuple[float, float, float]], list[tuple[int, float]]] | None = None,
    ) -> None:
        ec = edge_col if edge_col is not None else body_col
        hx = max(size[0] * 0.5, 0.003)
        hy = max(size[1] * 0.5, 0.003)
        hz = max(size[2] * 0.5, 0.003)
        b = min(bevel, min(hx, hy, hz) * 0.38)
        ax_x, ax_y, ax_z = basis_from_axis(axis_dir, up_hint)

        def rect_loop(rx: float, rz: float) -> list[tuple[float, float]]:
            cx = max(rx - b * 0.75, 0.0015)
            cz = max(rz - b * 0.75, 0.0015)
            return [
                (cx, rz), (rx, cz), (rx, -cz), (cx, -rz),
                (-cx, -rz), (-rx, -cz), (-rx, cz), (-cx, rz),
            ]

        y_rings = [
            (-hy, max(hx - b, 0.002), max(hz - b, 0.002), ec, 0.0),
            (-hy + b, hx, hz, body_col, 0.18),
            (hy - b, hx, hz, body_col, 0.82),
            (hy, max(hx - b, 0.002), max(hz - b, 0.002), ec, 1.0),
        ]
        local_pos: list[tuple[float, float, float]] = []
        local_uv: list[tuple[float, float]] = []
        local_col: list[tuple[float, float, float, float]] = []
        local_tris: list[tuple[int, int, int]] = []
        ring_indices: list[list[int]] = []

        for y_off, rx, rz, col, v_uv in y_rings:
            pts2 = rect_loop(rx, rz)
            ring: list[int] = []
            for k, (px, pz) in enumerate(pts2):
                p = xform_point(center, ax_x, ax_y, ax_z, (px, y_off, pz))
                idx = len(local_pos)
                local_pos.append(p)
                local_uv.append((k / 8.0, v_uv))
                local_col.append(col)
                ring.append(idx)
            ring_indices.append(ring)

        bot_idx = len(local_pos)
        local_pos.append(xform_point(center, ax_x, ax_y, ax_z, (0.0, -hy - 0.0015, 0.0)))
        local_uv.append((0.5, 0.0))
        local_col.append(ec)

        top_idx = len(local_pos)
        local_pos.append(xform_point(center, ax_x, ax_y, ax_z, (0.0, hy + 0.0015, 0.0)))
        local_uv.append((0.5, 1.0))
        local_col.append(ec)

        for k in range(8):
            nk = (k + 1) % 8
            local_tris.append((bot_idx, ring_indices[0][k], ring_indices[0][nk]))
        for si in range(len(y_rings) - 1):
            ra, rb = ring_indices[si], ring_indices[si + 1]
            for k in range(8):
                nk = (k + 1) % 8
                local_tris.append((ra[k], rb[k], rb[nk]))
                local_tris.append((ra[k], rb[nk], ra[nk]))
        for k in range(8):
            nk = (k + 1) % 8
            local_tris.append((top_idx, ring_indices[-1][nk], ring_indices[-1][k]))

        self._commit_submesh(local_pos, local_uv, local_col, local_tris, skin_fn, None)

    def add_torus(
        self,
        center: tuple[float, float, float],
        axis_dir: tuple[float, float, float],
        major_r: float,
        minor_rx: float,
        minor_ry: float,
        major_segs: int,
        minor_segs: int,
        col: tuple[float, float, float, float],
        rim_col: tuple[float, float, float, float] | None = None,
        up_hint: tuple[float, float, float] = (0.0, 0.0, 1.0),
        skin_fn: Callable[[tuple[float, float, float]], list[tuple[int, float]]] | None = None,
    ) -> None:
        rc = rim_col if rim_col is not None else col
        ax_x, ax_y, ax_z = basis_from_axis(axis_dir, up_hint)
        local_pos: list[tuple[float, float, float]] = []
        local_uv: list[tuple[float, float]] = []
        local_col: list[tuple[float, float, float, float]] = []
        local_tris: list[tuple[int, int, int]] = []
        rings: list[list[int]] = []

        for i in range(major_segs):
            phi = (2.0 * math.pi * i) / major_segs
            cp, sp = math.cos(phi), math.sin(phi)
            radial = (ax_x[0] * cp + ax_z[0] * sp, ax_x[1] * cp + ax_z[1] * sp, ax_x[2] * cp + ax_z[2] * sp)
            ring_center = v_add(center, v_mul(radial, major_r))
            ring: list[int] = []
            for j in range(minor_segs):
                theta = (2.0 * math.pi * j) / minor_segs
                ct, st = math.cos(theta), math.sin(theta)
                p = v_add(ring_center, v_add(v_mul(radial, ct * minor_rx), v_mul(ax_y, st * minor_ry)))
                idx = len(local_pos)
                local_pos.append(p)
                local_uv.append((i / major_segs, j / minor_segs))
                local_col.append(rc if ct > 0.35 else col)
                ring.append(idx)
            rings.append(ring)

        for i in range(major_segs):
            ni = (i + 1) % major_segs
            ra, rb = rings[i], rings[ni]
            for j in range(minor_segs):
                nj = (j + 1) % minor_segs
                local_tris.append((ra[j], ra[nj], rb[nj]))
                local_tris.append((ra[j], rb[nj], rb[j]))

        self._commit_submesh(local_pos, local_uv, local_col, local_tris, skin_fn, None)

    def _commit_submesh(
        self,
        local_pos: list[tuple[float, float, float]],
        local_uv: list[tuple[float, float]],
        local_col: list[tuple[float, float, float, float]],
        local_tris: list[tuple[int, int, int]],
        skin_fn: Callable[[tuple[float, float, float]], list[tuple[int, float]]] | None,
        color_override_fn: Callable[[tuple[float, float, float], tuple[float, float, float], tuple[float, float, float, float]], tuple[float, float, float, float]] | None,
    ) -> None:
        centroid = (
            sum(p[0] for p in local_pos) / len(local_pos),
            sum(p[1] for p in local_pos) / len(local_pos),
            sum(p[2] for p in local_pos) / len(local_pos),
        )
        vol6 = 0.0
        for i0, i1, i2 in local_tris:
            p0, p1, p2 = local_pos[i0], local_pos[i1], local_pos[i2]
            vol6 += v_dot(v_sub(p0, centroid), v_cross(v_sub(p1, p0), v_sub(p2, p0)))
        if vol6 < 0.0:
            local_tris = [(i0, i2, i1) for (i0, i1, i2) in local_tris]

        acc_n = [[0.0, 0.0, 0.0] for _ in local_pos]
        for i0, i1, i2 in local_tris:
            p0, p1, p2 = local_pos[i0], local_pos[i1], local_pos[i2]
            fn = v_cross(v_sub(p1, p0), v_sub(p2, p0))
            for idx in (i0, i1, i2):
                acc_n[idx][0] += fn[0]
                acc_n[idx][1] += fn[1]
                acc_n[idx][2] += fn[2]

        local_n = [v_norm((n[0], n[1], n[2])) for n in acc_n]
        for ti, (i0, i1, i2) in enumerate(local_tris):
            p0, p1, p2 = local_pos[i0], local_pos[i1], local_pos[i2]
            fn = v_cross(v_sub(p1, p0), v_sub(p2, p0))
            avg_n = v_add(local_n[i0], v_add(local_n[i1], local_n[i2]))
            if v_dot(fn, avg_n) < 0.0:
                fn_u = v_norm(fn)
                local_n[i0] = fn_u
                local_n[i1] = fn_u
                local_n[i2] = fn_u

        base_idx = len(self.positions)
        for vi, p in enumerate(local_pos):
            n = local_n[vi]
            col = local_col[vi]
            if color_override_fn is not None:
                col = color_override_fn(p, n, col)
            self.positions.append(p)
            self.normals.append(n)
            self.uvs.append(local_uv[vi])
            self.colors.append(col)
            if self.skinned:
                pairs = skin_fn(p) if skin_fn is not None else [(0, 1.0)]
                j4, w4 = normalize_weights(pairs)
                self.joints.append(j4)
                self.weights.append(w4)

        for i0, i1, i2 in local_tris:
            self.indices.append(base_idx + i0)
            self.indices.append(base_idx + i1)
            self.indices.append(base_idx + i2)

    def verify(self, label: str, num_joints: int = 25) -> dict:
        assert len(self.indices) % 3 == 0 and len(self.indices) > 0, f"{label}: empty indices"
        edge_counts: dict[tuple[tuple[int, int, int], tuple[int, int, int]], int] = {}
        degen = 0
        inverted = 0
        for t in range(0, len(self.indices), 3):
            i0, i1, i2 = self.indices[t], self.indices[t + 1], self.indices[t + 2]
            v0, v1, v2 = self.positions[i0], self.positions[i1], self.positions[i2]
            geo = v_cross(v_sub(v1, v0), v_sub(v2, v0))
            if v_dot(geo, geo) < 1e-12:
                degen += 1
                continue
            avg_n = v_add(self.normals[i0], v_add(self.normals[i1], self.normals[i2]))
            if v_dot(geo, avg_n) < 0.0:
                inverted += 1
            k0 = (round(v0[0] * 10000), round(v0[1] * 10000), round(v0[2] * 10000))
            k1 = (round(v1[0] * 10000), round(v1[1] * 10000), round(v1[2] * 10000))
            k2 = (round(v2[0] * 10000), round(v2[1] * 10000), round(v2[2] * 10000))
            for a, b in ((k0, k1), (k1, k2), (k2, k0)):
                if a == b:
                    degen += 1
                    continue
                ek = (a, b) if a < b else (b, a)
                edge_counts[ek] = edge_counts.get(ek, 0) + 1
        boundary = sum(1 for c in edge_counts.values() if c == 1)
        non_manifold = sum(1 for c in edge_counts.values() if c > 2)
        if degen or inverted or boundary or non_manifold:
            raise AssertionError(
                f"{label} failed manifold check: tris={len(self.indices)//3} degen={degen} "
                f"inverted={inverted} boundary={boundary} non_manifold={non_manifold}"
            )
        if self.skinned:
            for vi in range(len(self.positions)):
                wsum = sum(self.weights[vi])
                if abs(wsum - 1.0) > 1e-5:
                    raise AssertionError(f"{label} v{vi} weight sum={wsum}")
                for j, w in zip(self.joints[vi], self.weights[vi]):
                    if w > 0.0 and not (0 <= j < num_joints):
                        raise AssertionError(f"{label} v{vi} invalid joint {j}")
        if self.material_name == "paint":
            for vi, c in enumerate(self.colors):
                if abs(c[3] - 1.0) > 1e-4:
                    raise AssertionError(f"{label} paint surface v{vi} alpha={c[3]} != 1.0")
        return {"verts": len(self.positions), "tris": len(self.indices) // 3}


class GlbWriter:
    def __init__(self):
        self.bin = bytearray()
        self.buffer_views: list[dict] = []
        self.accessors: list[dict] = []
        self.materials: list[dict] = []
        self.mat_index: dict[str, int] = {}
        self.meshes: list[dict] = []
        self.nodes: list[dict] = []
        self.skins: list[dict] = []
        self.animations: list[dict] = []

    def ensure_material(self, name: str) -> int:
        if name in self.mat_index:
            return self.mat_index[name]
        idx = len(self.materials)
        self.materials.append(
            {
                "name": name,
                "pbrMetallicRoughness": {
                    "baseColorFactor": [1.0, 1.0, 1.0, 1.0],
                    "metallicFactor": 0.0,
                    "roughnessFactor": 0.85,
                },
            }
        )
        self.mat_index[name] = idx
        return idx

    def _pad4(self) -> None:
        while len(self.bin) % 4 != 0:
            self.bin.append(0)

    def add_accessor(
        self,
        raw_bytes: bytes,
        component_type: int,
        count: int,
        acc_type: str,
        target: int | None = None,
        mins: list[float] | None = None,
        maxs: list[float] | None = None,
    ) -> int:
        self._pad4()
        offset = len(self.bin)
        self.bin.extend(raw_bytes)
        bv: dict = {"buffer": 0, "byteOffset": offset, "byteLength": len(raw_bytes)}
        if target is not None:
            bv["target"] = target
        bv_idx = len(self.buffer_views)
        self.buffer_views.append(bv)

        acc: dict = {
            "bufferView": bv_idx,
            "componentType": component_type,
            "count": count,
            "type": acc_type,
        }
        if mins is not None:
            acc["min"] = mins
        if maxs is not None:
            acc["max"] = maxs
        acc_idx = len(self.accessors)
        self.accessors.append(acc)
        return acc_idx

    def add_mesh(self, name: str, surfaces: list[SurfaceData]) -> int:
        prims: list[dict] = []
        for surf in surfaces:
            nv = len(surf.positions)
            pos_bytes = b"".join(struct.pack("<3f", *p) for p in surf.positions)
            nrm_bytes = b"".join(struct.pack("<3f", *n) for n in surf.normals)
            uv_bytes = b"".join(struct.pack("<2f", *uv) for uv in surf.uvs)
            col_bytes = b"".join(struct.pack("<4f", *c) for c in surf.colors)
            idx_bytes = b"".join(struct.pack("<I", i) for i in surf.indices)

            mins = [min(p[k] for p in surf.positions) for k in range(3)]
            maxs = [max(p[k] for p in surf.positions) for k in range(3)]

            pos_acc = self.add_accessor(pos_bytes, 5126, nv, "VEC3", 34962, mins, maxs)
            nrm_acc = self.add_accessor(nrm_bytes, 5126, nv, "VEC3", 34962)
            uv_acc = self.add_accessor(uv_bytes, 5126, nv, "VEC2", 34962)
            col_acc = self.add_accessor(col_bytes, 5126, nv, "VEC4", 34962)
            idx_acc = self.add_accessor(idx_bytes, 5125, len(surf.indices), "SCALAR", 34963)

            attrs = {
                "POSITION": pos_acc,
                "NORMAL": nrm_acc,
                "TEXCOORD_0": uv_acc,
                "COLOR_0": col_acc,
            }
            if surf.skinned:
                j_bytes = b"".join(struct.pack("<4H", *j) for j in surf.joints)
                w_bytes = b"".join(struct.pack("<4f", *w) for w in surf.weights)
                attrs["JOINTS_0"] = self.add_accessor(j_bytes, 5123, nv, "VEC4", 34962)
                attrs["WEIGHTS_0"] = self.add_accessor(w_bytes, 5126, nv, "VEC4", 34962)

            prims.append(
                {
                    "attributes": attrs,
                    "indices": idx_acc,
                    "material": self.ensure_material(surf.material_name),
                    "mode": 4,
                }
            )
        m_idx = len(self.meshes)
        self.meshes.append({"name": name, "primitives": prims})
        return m_idx

    def add_node(
        self,
        name: str,
        translation: tuple[float, float, float] | None = None,
        rotation: tuple[float, float, float, float] | None = None,
        children: list[int] | None = None,
        mesh: int | None = None,
        skin: int | None = None,
    ) -> int:
        node: dict = {"name": name}
        if translation is not None:
            node["translation"] = [round(float(x), 6) for x in translation]
        if rotation is not None:
            node["rotation"] = [round(float(x), 7) for x in rotation]
        if children:
            node["children"] = children
        if mesh is not None:
            node["mesh"] = mesh
        if skin is not None:
            node["skin"] = skin
        idx = len(self.nodes)
        self.nodes.append(node)
        return idx

    def write(self, out_path: pathlib.Path, root_nodes: list[int]) -> None:
        self._pad4()
        gltf: dict = {
            "asset": {"version": "2.0", "generator": "Scrapkeep build_patch_glbs.py"},
            "scene": 0,
            "scenes": [{"nodes": root_nodes}],
            "nodes": self.nodes,
            "meshes": self.meshes,
            "materials": self.materials,
            "accessors": self.accessors,
            "bufferViews": self.buffer_views,
            "buffers": [{"byteLength": len(self.bin)}],
        }
        if self.skins:
            gltf["skins"] = self.skins
        if self.animations:
            gltf["animations"] = self.animations

        json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
        while len(json_bytes) % 4 != 0:
            json_bytes += b" "

        total_len = 12 + 8 + len(json_bytes) + 8 + len(self.bin)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total_len))
            f.write(struct.pack("<II", len(json_bytes), 0x4E4F534A))
            f.write(json_bytes)
            f.write(struct.pack("<II", len(self.bin), 0x004E4942))
            f.write(self.bin)


# ==============================================================================
# 1. PILOT PATCH ANIMATED GLB (25-bone PatchRig + 4 meshes + 8 clips)
# ==============================================================================

JOINT_SPECS = [
    ("root", None, (0.0, -0.600, 0.0), (-0.7071068, 0.0, 0.0, 0.7071068)),
    ("pelvis", "root", (0.0, 0.0, 0.300), (0.0, 0.0, 0.0, 1.0)),
    ("spine_01", "pelvis", (0.0, 0.0, 0.060), (0.0, 0.0, 0.0, 1.0)),
    ("spine_02", "spine_01", (0.0, 0.0, 0.140), (0.0, 0.0, 0.0, 1.0)),
    ("neck", "spine_02", (0.0, 0.015, 0.105), (0.0, 0.0, 0.0, 1.0)),
    ("head", "neck", (0.0, 0.01232, 0.165), (0.0, 0.0, 0.0, 1.0)),
    ("crest", "head", (0.0, -0.050, 0.240), (0.0, 0.0, 0.0, 1.0)),
    ("ear.L", "head", (-0.165, -0.020, 0.172), (0.0, 0.0, 0.0, 1.0)),
    ("ear.R", "head", (0.165, -0.020, 0.172), (0.0, 0.0, 0.0, 1.0)),
    ("goggles", "head", (0.0, 0.145, 0.095), (0.0, 0.0, 0.0, 1.0)),
    ("jaw", "head", (0.0, 0.175, -0.095), (0.0, 0.0, 0.0, 1.0)),
    ("snout", "head", (0.0, 0.275, -0.065), (0.0, 0.0, 0.0, 1.0)),
    ("shoulder.L", "spine_02", (-0.130, 0.005, 0.040), (0.0, 0.0, 0.0, 1.0)),
    ("upper_arm.L", "shoulder.L", (-0.110, 0.010, -0.030), (0.0, 0.0, 0.0, 1.0)),
    ("lower_arm.L", "upper_arm.L", (-0.120, 0.225, -0.030), (0.0, 0.0, 0.0, 1.0)),
    ("hand.L", "lower_arm.L", (0.040, 0.160, 0.170), (0.0, 0.0, 0.0, 1.0)),
    ("curl.L", "hand.L", (0.0, 0.030, 0.010), (0.0, 0.0, 0.0, 1.0)),
    ("shoulder.R", "spine_02", (0.130, 0.005, 0.040), (0.0, 0.0, 0.0, 1.0)),
    ("upper_arm.R", "shoulder.R", (0.110, 0.010, -0.030), (0.0, 0.0, 0.0, 1.0)),
    ("lower_arm.R", "upper_arm.R", (0.120, 0.225, -0.030), (0.0, 0.0, 0.0, 1.0)),
    ("hand.R", "lower_arm.R", (-0.040, 0.160, 0.170), (0.0, 0.0, 0.0, 1.0)),
    ("curl.R", "hand.R", (0.0, 0.030, 0.010), (0.0, 0.0, 0.0, 1.0)),
    ("tool.R", "hand.R", (0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0)),
    ("tail.01", "pelvis", (0.0, -0.160, 0.030), (0.0, 0.0, 0.0, 1.0)),
    ("tail.02", "tail.01", (0.0, -0.300, 0.070), (0.0, 0.0, 0.0, 1.0)),
]

JOINT_IDX = {name: i for i, (name, _, _, _) in enumerate(JOINT_SPECS)}


def build_pilot_patch_glb() -> dict:
    writer = GlbWriter()

    # 1. Build Pilot main opossum mesh (skinned to PatchRig)
    pilot_surf = SurfaceData("pilot", skinned=True)

    def torso_skin(p: tuple[float, float, float]) -> list[tuple[int, float]]:
        y = p[1]
        if y < -0.22:
            return [(JOINT_IDX["pelvis"], 0.85), (JOINT_IDX["spine_01"], 0.15)]
        if y < -0.08:
            t = (y - (-0.22)) / 0.14
            return [(JOINT_IDX["pelvis"], 1.0 - t), (JOINT_IDX["spine_01"], t)]
        if y < 0.06:
            t = (y - (-0.08)) / 0.14
            return [(JOINT_IDX["spine_01"], 1.0 - t), (JOINT_IDX["spine_02"], t)]
        return [(JOINT_IDX["spine_02"], 0.82), (JOINT_IDX["neck"], 0.18)]

    # Opossum seated lower body + verdigris splicer vest torso
    pilot_surf.add_lofted_tube(
        [
            ((0.0, -0.44, 0.02), 0.155, 0.145, COL_FUR_DARK),
            ((0.0, -0.34, 0.02), 0.215, 0.195, COL_FUR),
            ((0.0, -0.22, 0.01), 0.228, 0.205, COL_VERDIGRIS),
            ((0.0, -0.08, 0.00), 0.222, 0.195, COL_VERDIGRIS),
            ((0.0, 0.03, -0.01), 0.200, 0.175, COL_VERDIGRIS_LIGHT),
            ((0.0, 0.10, -0.015), 0.145, 0.135, COL_FUR),
        ],
        axis_dir=(0.0, 1.0, 0.0),
        segs=16,
        up_hint=(0.0, 0.0, 1.0),
        skin_fn=torso_skin,
    )

    # Seated opossum thighs/paws tucked at base
    for side in (-1.0, 1.0):
        pilot_surf.add_lofted_tube(
            [
                ((side * 0.13, -0.36, 0.00), 0.082, 0.085, COL_FUR_DARK),
                ((side * 0.145, -0.40, -0.12), 0.074, 0.076, COL_FUR),
                ((side * 0.145, -0.43, -0.24), 0.064, 0.058, COL_CHARCOAL),
            ],
            axis_dir=(side * 0.06, -0.25, -0.96),
            segs=10,
            skin_fn=lambda _p: [(JOINT_IDX["pelvis"], 1.0)],
        )

    # Utility belt + copper splice pouches + shoulder harness straps + USB lanyard
    pilot_surf.add_torus(
        (0.0, -0.21, 0.005),
        (0.0, 1.0, 0.0),
        0.224,
        0.026,
        0.032,
        16,
        8,
        COL_CHARCOAL,
        COL_COPPER,
        skin_fn=torso_skin,
    )
    for side in (-1.0, 1.0):
        pilot_surf.add_chamfered_box(
            (side * 0.195, -0.20, -0.08),
            (0.065, 0.085, 0.095),
            0.012,
            COL_COPPER,
            COL_BRASS,
            skin_fn=torso_skin,
        )
        pilot_surf.add_chamfered_box(
            (side * 0.105, -0.03, -0.175),
            (0.048, 0.24, 0.034),
            0.008,
            COL_CHARCOAL,
            COL_COPPER,
            axis_dir=(side * 0.08, 0.98, 0.16),
            skin_fn=torso_skin,
        )
    # USB lanyard + glowing badge on chest
    pilot_surf.add_torus(
        (0.0, 0.035, -0.105),
        (0.0, 0.82, -0.57),
        0.115,
        0.013,
        0.013,
        14,
        6,
        COL_STICKER_PINK,
        COL_COPPER,
        up_hint=(1.0, 0.0, 0.0),
        skin_fn=torso_skin,
    )
    pilot_surf.add_chamfered_box(
        (0.0, -0.075, -0.202),
        (0.068, 0.082, 0.026),
        0.006,
        COL_SILVER,
        COL_STICKER_TEAL,
        skin_fn=lambda _p: [(JOINT_IDX["spine_02"], 1.0)],
    )

    # Virginia opossum head: silver-grey cranium fading into pointed cream face & pink nose
    def head_color(p: tuple[float, float, float], _n: tuple[float, float, float], base: tuple[float, float, float, float]):
        if p[2] < -0.295:
            return COL_NOSE_PINK
        if p[2] < -0.11:
            t = min(1.0, (-0.09 - p[2]) / 0.10)
            return c_lerp(COL_FUR, COL_CREAM, t)
        if p[1] > 0.31 and abs(p[0]) < 0.065:
            return COL_FUR_DARK
        return base

    def head_skin(p: tuple[float, float, float]) -> list[tuple[int, float]]:
        if p[2] < -0.21:
            if p[1] < 0.135:
                return [(JOINT_IDX["jaw"], 0.65), (JOINT_IDX["head"], 0.35)]
            return [(JOINT_IDX["snout"], 0.72), (JOINT_IDX["head"], 0.28)]
        if p[1] < 0.12:
            return [(JOINT_IDX["neck"], 0.55), (JOINT_IDX["head"], 0.45)]
        return [(JOINT_IDX["head"], 1.0)]

    pilot_surf.add_lofted_tube(
        [
            ((0.0, 0.22, 0.135), 0.125, 0.118, COL_FUR_DARK),
            ((0.0, 0.235, 0.045), 0.188, 0.176, COL_FUR),
            ((0.0, 0.225, -0.055), 0.192, 0.172, COL_FUR),
            ((0.0, 0.200, -0.145), 0.148, 0.132, COL_CREAM),
            ((0.0, 0.178, -0.235), 0.092, 0.084, COL_CREAM),
            ((0.0, 0.168, -0.305), 0.048, 0.045, COL_NOSE_PINK),
            ((0.0, 0.166, -0.332), 0.026, 0.024, COL_NOSE_PINK),
        ],
        axis_dir=(0.0, -0.16, -0.987),
        segs=16,
        up_hint=(0.0, 1.0, 0.0),
        skin_fn=head_skin,
        color_override_fn=head_color,
    )

    # Lower cream jaw & chin
    pilot_surf.add_lofted_tube(
        [
            ((0.0, 0.135, -0.095), 0.105, 0.055, COL_CREAM),
            ((0.0, 0.128, -0.185), 0.072, 0.042, COL_CREAM),
            ((0.0, 0.132, -0.265), 0.038, 0.028, COL_CREAM),
        ],
        axis_dir=(0.0, -0.04, -0.999),
        segs=10,
        up_hint=(0.0, 1.0, 0.0),
        skin_fn=lambda _p: [(JOINT_IDX["jaw"], 0.8), (JOINT_IDX["head"], 0.2)],
    )

    # Dark glossy opossum eyes + forehead splicer visor goggles (symmetric L/R)
    pilot_surf.add_chamfered_box(
        (0.0, 0.285, -0.142),
        (0.285, 0.068, 0.075),
        0.016,
        COL_COPPER,
        COL_BRASS,
        skin_fn=lambda _p: [(JOINT_IDX["goggles"], 0.85), (JOINT_IDX["head"], 0.15)],
    )
    pilot_surf.add_torus(
        (0.0, 0.272, -0.015),
        (0.0, 1.0, -0.12),
        0.186,
        0.016,
        0.022,
        16,
        6,
        COL_CHARCOAL,
        COL_COPPER,
        skin_fn=lambda _p: [(JOINT_IDX["head"], 0.85), (JOINT_IDX["goggles"], 0.15)],
    )

    for side in (-1.0, 1.0):
        ear_joint = JOINT_IDX["ear.L" if side < 0.0 else "ear.R"]
        # Goggle lenses with test-card pink/teal accent
        pilot_surf.add_lofted_tube(
            [
                ((side * 0.078, 0.285, -0.165), 0.048, 0.042, COL_BRASS),
                ((side * 0.078, 0.285, -0.192), 0.042, 0.036, COL_STICKER_TEAL if side < 0.0 else COL_STICKER_PINK),
            ],
            axis_dir=(0.0, 0.0, -1.0),
            segs=10,
            skin_fn=lambda _p: [(JOINT_IDX["goggles"], 0.9), (JOINT_IDX["head"], 0.1)],
        )
        # Bead eye
        pilot_surf.add_lofted_tube(
            [
                ((side * 0.095, 0.215, -0.165), 0.024, 0.024, COL_CHARCOAL),
                ((side * 0.102, 0.217, -0.186), 0.018, 0.018, COL_CHARCOAL),
            ],
            axis_dir=(side * 0.32, 0.05, -0.94),
            segs=8,
            skin_fn=lambda _p: [(JOINT_IDX["head"], 1.0)],
        )
        # Signature round dark-rimmed opossum ears with pink inner cup
        def ear_col(p: tuple[float, float, float], _n: tuple[float, float, float], base: tuple[float, float, float, float], s=side):
            radial = math.sqrt((p[0] - s * 0.195) ** 2 + (p[1] - 0.365) ** 2)
            if p[2] < -0.012 and radial < 0.058:
                return COL_PINK
            return base

        pilot_surf.add_lofted_tube(
            [
                ((side * 0.155, 0.315, -0.005), 0.042, 0.024, COL_EAR_DARK),
                ((side * 0.195, 0.365, -0.008), 0.076, 0.022, COL_EAR_DARK),
                ((side * 0.218, 0.410, -0.010), 0.052, 0.018, COL_EAR_DARK),
            ],
            axis_dir=(side * 0.58, 0.81, -0.05),
            segs=12,
            up_hint=(0.0, 0.0, 1.0),
            skin_fn=lambda _p, ej=ear_joint: [(ej, 0.88), (JOINT_IDX["head"], 0.12)],
            color_override_fn=ear_col,
        )

    # Head tuft / crest (weighted to crest + head)
    pilot_surf.add_lofted_tube(
        [
            ((0.0, 0.375, 0.02), 0.036, 0.055, COL_FUR),
            ((0.0, 0.425, 0.05), 0.022, 0.038, COL_CREAM),
        ],
        axis_dir=(0.0, 0.86, 0.50),
        segs=8,
        up_hint=(1.0, 0.0, 0.0),
        skin_fn=lambda _p: [(JOINT_IDX["crest"], 0.8), (JOINT_IDX["head"], 0.2)],
    )

    # Symmetric L/R arms + cuffs + fingerless splicer mittens reaching canonical hands (-+0.320, 0.050, -0.400)
    for side in (-1.0, 1.0):
        tag = "L" if side < 0.0 else "R"
        j_sh = JOINT_IDX[f"shoulder.{tag}"]
        j_ua = JOINT_IDX[f"upper_arm.{tag}"]
        j_la = JOINT_IDX[f"lower_arm.{tag}"]
        j_hd = JOINT_IDX[f"hand.{tag}"]
        j_cu = JOINT_IDX[f"curl.{tag}"]

        def arm_skin(p: tuple[float, float, float], js=j_sh, ju=j_ua, jl=j_la, jh=j_hd, jc=j_cu) -> list[tuple[int, float]]:
            z = p[2]
            if z > -0.06:
                return [(js, 0.65), (ju, 0.35)]
            if z > -0.21:
                t = (-0.06 - z) / 0.15
                return [(ju, 1.0 - t * 0.65), (jl, t * 0.65)]
            if z > -0.35:
                t = (-0.21 - z) / 0.14
                return [(jl, 1.0 - t * 0.7), (jh, t * 0.7)]
            if z < -0.415:
                return [(jh, 0.55), (jc, 0.45)]
            return [(jh, 0.88), (jl, 0.12)]

        pilot_surf.add_curved_tube(
            [
                ((side * 0.155, -0.045, 0.005), 0.068, 0.068, COL_VERDIGRIS),
                ((side * 0.240, -0.085, -0.045), 0.062, 0.062, COL_VERDIGRIS),
                ((side * 0.345, -0.115, -0.225), 0.054, 0.054, COL_FUR),
                ((side * 0.332, -0.025, -0.335), 0.052, 0.052, COL_COPPER),
                ((side * 0.320, 0.050, -0.400), 0.056, 0.048, COL_CHARCOAL),
                ((side * 0.318, 0.058, -0.442), 0.044, 0.036, COL_PINK),
            ],
            segs=10,
            up_hint=(0.0, 1.0, 0.0),
            skin_fn=arm_skin,
        )

    # 2. TailBase & TailTip (signature pink scaly prehensile opossum tail)
    tail_base_surf = SurfaceData("pilot", skinned=True)
    tail_base_surf.add_curved_tube(
        [
            ((0.0, -0.30, 0.14), 0.068, 0.064, COL_FUR),
            ((0.0, -0.31, 0.24), 0.056, 0.054, COL_PINK),
            ((0.0, -0.28, 0.35), 0.048, 0.046, COL_PINK),
            ((0.0, -0.22, 0.45), 0.040, 0.040, COL_PINK),
        ],
        segs=10,
        up_hint=(0.0, 1.0, 0.0),
        skin_fn=lambda p: (
            [(JOINT_IDX["pelvis"], 0.65), (JOINT_IDX["tail.01"], 0.35)]
            if p[2] < 0.22
            else [(JOINT_IDX["tail.01"], 0.78), (JOINT_IDX["tail.02"], 0.22)]
        ),
    )

    tail_tip_surf = SurfaceData("pilot", skinned=True)
    tail_tip_surf.add_curved_tube(
        [
            ((0.0, -0.23, 0.43), 0.041, 0.041, COL_PINK),
            ((0.0, -0.14, 0.54), 0.034, 0.034, COL_PINK),
            ((0.0, -0.02, 0.60), 0.027, 0.027, COL_NOSE_PINK),
            ((0.0, 0.06, 0.56), 0.020, 0.020, COL_NOSE_PINK),
            ((0.0, 0.05, 0.49), 0.014, 0.014, COL_NOSE_PINK),
        ],
        segs=10,
        up_hint=(1.0, 0.0, 0.0),
        skin_fn=lambda p: [(JOINT_IDX["tail.02"], 0.88), (JOINT_IDX["tail.01"], 0.12)]
        if p[2] > 0.47
        else [(JOINT_IDX["tail.01"], 0.45), (JOINT_IDX["tail.02"], 0.55)],
    )

    # 3. Tool: Patch's 2010 stickered silver netbook + glowing terminal screen + copper splice probe
    tool_metal = SurfaceData("bare_metal", skinned=True)
    tool_accent = SurfaceData("class_accent", skinned=True)
    tool_skin = lambda _p: [(JOINT_IDX["tool.R"], 0.92), (JOINT_IDX["hand.R"], 0.08)]

    # Netbook base deck & hinged clamshell lid (mounted cleanly on outer right wrist/hand)
    tool_metal.add_chamfered_box(
        (0.355, 0.095, -0.415),
        (0.135, 0.018, 0.105),
        0.004,
        COL_SILVER,
        COL_SLATE,
        axis_dir=(0.18, 0.98, 0.0),
        skin_fn=tool_skin,
    )
    tool_metal.add_chamfered_box(
        (0.398, 0.162, -0.455),
        (0.135, 0.102, 0.016),
        0.004,
        COL_SILVER,
        COL_STICKER_GOLD,
        axis_dir=(-0.22, 0.94, 0.25),
        up_hint=(0.0, 0.0, 1.0),
        skin_fn=tool_skin,
    )
    # Copper coaxial splice probe extending forward from netbook USB port
    tool_metal.add_lofted_tube(
        [
            ((0.355, 0.102, -0.462), 0.012, 0.012, COL_COPPER),
            ((0.355, 0.108, -0.525), 0.007, 0.007, COL_BRASS),
        ],
        axis_dir=(0.0, 0.09, -0.996),
        segs=8,
        skin_fn=tool_skin,
    )
    # Glowing terminal screen + diagnostic LED bar on netbook
    tool_accent.add_chamfered_box(
        (0.390, 0.160, -0.445),
        (0.108, 0.076, 0.010),
        0.0025,
        COL_WHITE_PAINT,
        COL_WHITE_PAINT,
        axis_dir=(-0.22, 0.94, 0.25),
        up_hint=(0.0, 0.0, 1.0),
        skin_fn=tool_skin,
    )

    s_pilot = pilot_surf.verify("Patch.Pilot")
    s_tb = tail_base_surf.verify("Patch.TailBase")
    s_tt = tail_tip_surf.verify("Patch.TailTip")
    s_tm = tool_metal.verify("Patch.Tool.metal")
    s_ta = tool_accent.verify("Patch.Tool.accent")

    m_pilot = writer.add_mesh("Pilot", [pilot_surf])
    m_tb = writer.add_mesh("TailBase", [tail_base_surf])
    m_tt = writer.add_mesh("TailTip", [tail_tip_surf])
    m_tool = writer.add_mesh("Tool", [tool_metal, tool_accent])

    # Build 25 joint nodes in bottom-up order so children exist when parent is created, or create then link
    joint_node_ids: list[int] = []
    for name, _parent, t_rest, r_rest in JOINT_SPECS:
        nid = writer.add_node(name, translation=t_rest, rotation=r_rest)
        joint_node_ids.append(nid)

    children_map: dict[int, list[int]] = {i: [] for i in range(len(JOINT_SPECS))}
    for i, (_name, parent_name, _t, _r) in enumerate(JOINT_SPECS):
        if parent_name is not None:
            children_map[JOINT_IDX[parent_name]].append(i)
    for i, ch in children_map.items():
        if ch:
            writer.nodes[joint_node_ids[i]]["children"] = [joint_node_ids[c] for c in ch]

    # Compute exact world rest matrices and InverseBindMatrices
    world_mats: list[list[float]] = []
    for i, (_name, parent_name, t_rest, r_rest) in enumerate(JOINT_SPECS):
        local_m = mat4_from_trs(t_rest, r_rest)
        if parent_name is None:
            world_mats.append(local_m)
        else:
            world_mats.append(mat4_mul(world_mats[JOINT_IDX[parent_name]], local_m))

    ibm_bytes = b"".join(struct.pack("<16f", *mat4_inv_rigid(wm)) for wm in world_mats)
    ibm_acc = writer.add_accessor(ibm_bytes, 5126, len(JOINT_SPECS), "MAT4")

    writer.skins.append(
        {
            "name": "PatchRig",
            "inverseBindMatrices": ibm_acc,
            "joints": joint_node_ids,
            "skeleton": joint_node_ids[0],
        }
    )

    n_pilot = writer.add_node("Pilot", (0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0), mesh=m_pilot, skin=0)
    n_tb = writer.add_node("TailBase", (0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0), mesh=m_tb, skin=0)
    n_tt = writer.add_node("TailTip", (0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0), mesh=m_tt, skin=0)
    n_tool = writer.add_node("Tool", (0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0), mesh=m_tool, skin=0)
    n_rig = writer.add_node(
        "PatchRig",
        (0.0, 0.0, 0.0),
        (0.0, 0.0, 0.0, 1.0),
        children=[n_pilot, n_tb, n_tt, n_tool, joint_node_ids[0]],
    )

    # 8 expressive 30fps animation clips
    _build_patch_animations(writer, joint_node_ids)
    writer.write(PILOT_GLB_PATH, [n_rig])
    return {
        "pilot_tris": s_pilot["tris"] + s_tb["tris"] + s_tt["tris"] + s_tm["tris"] + s_ta["tris"],
        "pilot_verts": s_pilot["verts"] + s_tb["verts"] + s_tt["verts"] + s_tm["verts"] + s_ta["verts"],
        "joints": len(JOINT_SPECS),
        "clips": len(writer.animations),
    }


def _build_patch_animations(writer: GlbWriter, joint_node_ids: list[int]) -> None:
    fps = 30.0

    def add_clip(
        clip_name: str,
        duration: float,
        pose_fn: Callable[[float], dict[str, tuple[tuple[float, float, float] | None, tuple[float, float, float] | None]]],
    ) -> None:
        n_frames = max(3, int(round(duration * fps)) + 1)
        times = [i / (n_frames - 1) * duration for i in range(n_frames)]
        t_bytes = b"".join(struct.pack("<f", t) for t in times)
        t_acc = writer.add_accessor(t_bytes, 5126, n_frames, "SCALAR", mins=[times[0]], maxs=[times[-1]])

        samplers: list[dict] = []
        channels: list[dict] = []

        sampled = [pose_fn(i / (n_frames - 1)) for i in range(n_frames)]
        sampled[-1] = sampled[0]

        for j_idx, (j_name, _parent, rest_t, rest_r) in enumerate(JOINT_SPECS):
            node_id = joint_node_ids[j_idx]
            trans_track: list[tuple[float, float, float]] = []
            rot_track: list[tuple[float, float, float, float]] = []
            for f_dict in sampled:
                dt, deuler = f_dict.get(j_name, (None, None))
                if dt is not None:
                    trans_track.append((rest_t[0] + dt[0], rest_t[1] + dt[1], rest_t[2] + dt[2]))
                else:
                    trans_track.append(rest_t)
                if deuler is not None and j_name != "root":
                    rot_track.append(quat_from_euler_xyz(*deuler))
                else:
                    rot_track.append(rest_r)

            tr_bytes = b"".join(struct.pack("<3f", *v) for v in trans_track)
            rt_bytes = b"".join(struct.pack("<4f", *q) for q in rot_track)
            sc_bytes = b"".join(struct.pack("<3f", 1.0, 1.0, 1.0) for _ in range(n_frames))

            tr_acc = writer.add_accessor(tr_bytes, 5126, n_frames, "VEC3")
            rt_acc = writer.add_accessor(rt_bytes, 5126, n_frames, "VEC4")
            sc_acc = writer.add_accessor(sc_bytes, 5126, n_frames, "VEC3")

            for path_name, out_acc in (("translation", tr_acc), ("rotation", rt_acc), ("scale", sc_acc)):
                s_idx = len(samplers)
                samplers.append({"input": t_acc, "interpolation": "LINEAR", "output": out_acc})
                channels.append({"sampler": s_idx, "target": {"node": node_id, "path": path_name}})

        writer.animations.append({"name": clip_name, "samplers": samplers, "channels": channels})

    # Note: under root's -90deg X rotation, bone-local +Z is UP, +Y is FORWARD (-Z in glTF), +X is RIGHT!
    def pulse(u: float) -> float:
        return math.sin(math.pi * u) ** 2

    # 1. idle_loop (2.0s seamless breathing, opossum snout sniff, radar ears, curled tail sway)
    def anim_idle(u: float):
        a = 2.0 * math.pi * u
        b = math.sin(a)
        b2 = math.sin(2.0 * a)
        return {
            "pelvis": ((0.0, 0.0, 0.008 * b), (0.02 * b, 0.0, 0.015 * math.sin(a + 0.6))),
            "spine_01": (None, (0.035 * b, 0.0, 0.0)),
            "spine_02": (None, (0.045 * b, 0.018 * math.sin(a + 1.1), 0.0)),
            "head": (None, (-0.04 * b + 0.025 * b2, 0.03 * math.sin(a + 0.5), 0.04 * math.sin(a))),
            "snout": (None, (0.035 * b2, 0.0, 0.02 * b)),
            "ear.L": (None, (0.09 * math.sin(2.0 * a + 0.3), -0.06 * b, 0.04 * b2)),
            "ear.R": (None, (0.09 * math.sin(2.0 * a + 2.1), 0.06 * b, -0.04 * b2)),
            "tail.01": (None, (0.06 * b, 0.0, 0.11 * math.sin(a - 0.5))),
            "tail.02": (None, (0.09 * math.sin(a - 0.8), 0.0, 0.16 * math.sin(a - 1.1))),
            "hand.R": (None, (0.03 * b2, 0.0, 0.02 * b)),
            "tool.R": (None, (0.04 * b, 0.02 * b2, 0.0)),
        }

    # 2. brace (0.6s hunker into harness, flatten ears, coil tail)
    def anim_brace(u: float):
        p = pulse(u)
        return {
            "pelvis": ((0.0, 0.02 * p, -0.035 * p), (-0.12 * p, 0.0, 0.0)),
            "spine_01": (None, (-0.18 * p, 0.0, 0.0)),
            "spine_02": (None, (-0.16 * p, 0.0, 0.0)),
            "head": (None, (0.22 * p, 0.0, 0.0)),
            "ear.L": (None, (0.38 * p, -0.15 * p, 0.0)),
            "ear.R": (None, (0.38 * p, 0.15 * p, 0.0)),
            "shoulder.L": ((0.0, 0.0, 0.022 * p), None),
            "shoulder.R": ((0.0, 0.0, 0.022 * p), None),
            "upper_arm.L": (None, (0.22 * p, 0.14 * p, 0.0)),
            "upper_arm.R": (None, (0.22 * p, -0.14 * p, 0.0)),
            "tail.01": (None, (0.24 * p, 0.0, 0.0)),
            "tail.02": (None, (0.32 * p, 0.0, 0.0)),
        }

    # 3. drop_land (0.65s impact squash + springy rebound)
    def anim_drop_land(u: float):
        squash = math.exp(-5.5 * u) * math.sin(2.2 * math.pi * u) * pulse(min(1.0, u * 1.15)) if u < 0.95 else 0.0
        env = pulse(u)
        return {
            "pelvis": ((0.0, 0.0, -0.055 * env + 0.02 * squash), (-0.10 * env, 0.0, 0.0)),
            "spine_01": (None, (-0.14 * env + 0.08 * squash, 0.0, 0.0)),
            "spine_02": (None, (-0.12 * env + 0.08 * squash, 0.0, 0.0)),
            "head": (None, (-0.18 * squash, 0.0, 0.0)),
            "ear.L": (None, (0.32 * env - 0.25 * squash, -0.12 * env, 0.0)),
            "ear.R": (None, (0.32 * env - 0.25 * squash, 0.12 * env, 0.0)),
            "tail.01": (None, (-0.25 * env + 0.20 * squash, 0.0, 0.0)),
            "tail.02": (None, (-0.35 * env + 0.28 * squash, 0.0, 0.0)),
        }

    # 4. heave (0.7s line-splice haul back)
    def anim_heave(u: float):
        p = pulse(u)
        return {
            "pelvis": ((0.0, -0.03 * p, 0.02 * p), (0.16 * p, 0.0, 0.0)),
            "spine_01": (None, (0.22 * p, 0.0, 0.0)),
            "spine_02": (None, (0.20 * p, 0.0, 0.0)),
            "head": (None, (0.14 * p, 0.0, -0.08 * p)),
            "ear.L": (None, (-0.18 * p, 0.08 * p, 0.0)),
            "ear.R": (None, (-0.18 * p, -0.08 * p, 0.0)),
            "upper_arm.L": (None, (-0.28 * p, 0.12 * p, 0.0)),
            "upper_arm.R": (None, (-0.28 * p, -0.12 * p, 0.0)),
            "lower_arm.L": (None, (0.24 * p, 0.0, 0.0)),
            "lower_arm.R": (None, (0.24 * p, 0.0, 0.0)),
            "tail.01": (None, (0.26 * p, 0.0, 0.0)),
            "tail.02": (None, (0.34 * p, 0.0, 0.0)),
        }

    # 5. big_cheer (1.2s double hop, stickered netbook held high, happy tail wag)
    def anim_big_cheer(u: float):
        p = pulse(u)
        hop = abs(math.sin(2.0 * math.pi * u)) * p
        wag = math.sin(4.0 * math.pi * u) * p
        return {
            "pelvis": ((0.0, 0.0, 0.055 * hop), (0.08 * p, 0.0, 0.05 * wag)),
            "spine_01": (None, (0.12 * p, 0.0, 0.06 * wag)),
            "spine_02": (None, (0.14 * p, 0.05 * wag, 0.08 * p)),
            "head": (None, (0.16 * p, 0.08 * wag, 0.15 * p)),
            "jaw": (None, (0.18 * hop, 0.0, 0.0)),
            "ear.L": (None, (-0.24 * p, 0.12 * hop, 0.0)),
            "ear.R": (None, (-0.24 * p, -0.12 * hop, 0.0)),
            "shoulder.L": ((0.0, 0.0, 0.035 * p), None),
            "shoulder.R": ((0.0, 0.0, 0.045 * p), None),
            "upper_arm.L": (None, (0.45 * p, 0.22 * p, 0.28 * p)),
            "lower_arm.L": (None, (0.35 * p, 0.0, 0.0)),
            "upper_arm.R": (None, (0.72 * p, -0.32 * p, -0.35 * p)),
            "lower_arm.R": (None, (-0.42 * p, 0.15 * p, 0.0)),
            "tool.R": (None, (0.25 * p, 0.0, 0.18 * wag)),
            "tail.01": (None, (0.15 * p, 0.0, 0.28 * wag)),
            "tail.02": (None, (0.20 * p, 0.0, 0.38 * wag)),
        }

    # 6. phew (0.9s relieved sag + head shake)
    def anim_phew(u: float):
        p = pulse(u)
        shake = math.sin(3.0 * math.pi * u) * p
        return {
            "pelvis": ((0.0, 0.0, -0.025 * p), (-0.06 * p, 0.0, 0.0)),
            "spine_01": (None, (-0.12 * p, 0.0, 0.0)),
            "spine_02": (None, (-0.14 * p, 0.0, 0.0)),
            "head": (None, (-0.16 * p, 0.06 * shake, 0.14 * shake)),
            "ear.L": (None, (0.22 * p, -0.16 * p, 0.0)),
            "ear.R": (None, (0.22 * p, 0.16 * p, 0.0)),
            "upper_arm.L": (None, (0.32 * p, 0.20 * p, 0.22 * p)),
            "lower_arm.L": (None, (-0.28 * p, -0.14 * p, 0.18 * p)),
            "tail.01": (None, (-0.18 * p, 0.0, 0.10 * shake)),
            "tail.02": (None, (-0.24 * p, 0.0, 0.16 * shake)),
        }

    # 7. slump (1.4s signature "playing possum" dramatic side-wilt)
    def anim_slump(u: float):
        p = pulse(u)
        return {
            "pelvis": ((0.0, 0.02 * p, -0.06 * p), (-0.15 * p, 0.10 * p, 0.0)),
            "spine_01": (None, (-0.24 * p, 0.12 * p, 0.08 * p)),
            "spine_02": (None, (-0.26 * p, 0.16 * p, 0.12 * p)),
            "head": (None, (-0.32 * p, -0.28 * p, 0.22 * p)),
            "jaw": (None, (0.22 * p, 0.0, 0.0)),
            "ear.L": (None, (0.42 * p, -0.35 * p, 0.0)),
            "ear.R": (None, (0.42 * p, 0.35 * p, 0.0)),
            "shoulder.L": ((0.0, 0.0, -0.03 * p), None),
            "shoulder.R": ((0.0, 0.0, -0.03 * p), None),
            "upper_arm.L": (None, (-0.35 * p, -0.24 * p, 0.14 * p)),
            "upper_arm.R": (None, (-0.35 * p, 0.24 * p, -0.14 * p)),
            "tool.R": (None, (-0.35 * p, 0.0, 0.0)),
            "tail.01": (None, (-0.32 * p, 0.18 * p, 0.0)),
            "tail.02": (None, (-0.42 * p, 0.24 * p, 0.0)),
        }

    # 8. wince (0.5s sharp recoil flinch)
    def anim_wince(u: float):
        p = pulse(u)
        return {
            "pelvis": ((0.0, -0.02 * p, -0.025 * p), (0.10 * p, 0.0, 0.0)),
            "spine_01": (None, (-0.10 * p, -0.06 * p, 0.0)),
            "spine_02": (None, (-0.12 * p, -0.08 * p, 0.10 * p)),
            "head": (None, (-0.18 * p, 0.14 * p, 0.20 * p)),
            "ear.L": (None, (0.34 * p, -0.18 * p, 0.0)),
            "ear.R": (None, (0.34 * p, 0.18 * p, 0.0)),
            "shoulder.L": ((0.0, 0.0, 0.028 * p), None),
            "shoulder.R": ((0.0, 0.0, 0.028 * p), None),
            "upper_arm.L": (None, (0.16 * p, 0.12 * p, 0.22 * p)),
            "upper_arm.R": (None, (0.16 * p, -0.12 * p, -0.22 * p)),
            "tail.01": (None, (0.22 * p, 0.0, -0.15 * p)),
            "tail.02": (None, (0.30 * p, 0.0, -0.22 * p)),
        }

    add_clip("idle_loop-loop", 2.0, anim_idle)
    add_clip("brace", 0.6, anim_brace)
    add_clip("drop_land", 0.65, anim_drop_land)
    add_clip("heave", 0.7, anim_heave)
    add_clip("big_cheer", 1.2, anim_big_cheer)
    add_clip("phew", 0.9, anim_phew)
    add_clip("slump", 1.4, anim_slump)
    add_clip("wince", 0.5, anim_wince)


# ==============================================================================
# 2. SHELL PATCH GLB (Salvaged Splicer Cutaway-First Heroic Ball)
# ==============================================================================


def _read_sable_lattice_sockets() -> list[tuple[str, tuple[float, float, float]]]:
    raw = SHELL_SABLE_PATH.read_bytes()
    jlen, _ = struct.unpack_from("<II", raw, 12)
    g = json.loads(raw[20 : 20 + jlen])
    sockets: list[tuple[str, tuple[float, float, float]]] = []
    for node in g["nodes"]:
        nm = node.get("name", "")
        if nm.startswith("Hub.") or nm.startswith("Gap."):
            t = node.get("translation", [0.0, 0.0, 0.0])
            sockets.append((nm, (float(t[0]), float(t[1]), float(t[2]))))
    assert len(sockets) == 62, f"Expected 62 Hub/Gap sockets, got {len(sockets)}"
    return sockets


def build_shell_patch_glb() -> dict:
    writer = GlbWriter()
    lattice_sockets = _read_sable_lattice_sockets()

    # 1. Core: rolling geodesic splicer cage (verdigris/cream paint + copper bus-rings, r <= 0.98m)
    core_paint = SurfaceData("paint")
    core_copper = SurfaceData("copper")

    for axis, up_h in (
        ((0.0, 1.0, 0.0), (0.0, 0.0, 1.0)),
        ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0)),
        ((0.0, 0.7071068, 0.7071068), (1.0, 0.0, 0.0)),
        ((0.0, 0.7071068, -0.7071068), (1.0, 0.0, 0.0)),
    ):
        core_paint.add_torus((0.0, 0.0, 0.0), axis, 0.935, 0.036, 0.048, 28, 8, COL_VERDIGRIS, COL_VERDIGRIS_LIGHT, up_hint=up_h)

    for nm, pos in lattice_sockets:
        if nm.startswith("Hub."):
            n_dir = v_norm(pos)
            hub_c = v_mul(n_dir, 0.935)
            core_paint.add_lofted_tube(
                [
                    (v_add(hub_c, v_mul(n_dir, -0.022)), 0.058, 0.058, COL_COPPER),
                    (v_add(hub_c, v_mul(n_dir, 0.022)), 0.044, 0.044, COL_BRASS),
                ],
                axis_dir=n_dir,
                segs=6,
            )

    # 2. Pod: stabilized interior splicer tub & instrument cowl (y >= -0.44m, r <= 0.88m)
    pod_paint = SurfaceData("paint")
    pod_paint.add_lofted_tube(
        [
            ((0.0, -0.43, -0.04), 0.44, 0.48, COL_CHARCOAL),
            ((0.0, -0.35, -0.04), 0.68, 0.72, COL_VERDIGRIS),
            ((0.0, -0.18, -0.05), 0.78, 0.80, COL_VERDIGRIS),
            ((0.0, -0.05, -0.06), 0.76, 0.78, COL_VERDIGRIS_LIGHT),
        ],
        axis_dir=(0.0, 1.0, 0.0),
        segs=20,
    )
    # Forward splicer patch-bay console hood
    pod_paint.add_chamfered_box(
        (0.0, -0.06, -0.52),
        (0.62, 0.18, 0.24),
        0.028,
        COL_VERDIGRIS_LIGHT,
        COL_CREAM,
    )
    for sx in (-0.54, 0.54):
        pod_paint.add_chamfered_box(
            (sx, -0.12, 0.10),
            (0.18, 0.26, 0.56),
            0.026,
            COL_VERDIGRIS,
            COL_SLATE,
        )

    # 3. PilotSeat (inside Dome, rubber bucket + bolsters, y >= -0.40m)
    seat_surf = SurfaceData("rubber")
    seat_surf.add_chamfered_box((0.0, -0.34, 0.04), (0.44, 0.10, 0.42), 0.022, COL_CHARCOAL, COL_SLATE)
    seat_surf.add_chamfered_box(
        (0.0, -0.04, 0.24),
        (0.42, 0.54, 0.10),
        0.022,
        COL_CHARCOAL,
        COL_SLATE,
        axis_dir=(0.0, 0.985, 0.17),
        up_hint=(1.0, 0.0, 0.0),
    )

    # 4. Placeholder Pilot inside Dome (hidden at runtime when pilot_patch_anim.glb seats)
    standin_surf = SurfaceData("pilot")
    standin_surf.add_lofted_tube(
        [
            ((0.0, -0.28, 0.0), 0.14, 0.13, COL_VERDIGRIS),
            ((0.0, 0.08, 0.0), 0.15, 0.14, COL_FUR),
            ((0.0, 0.34, -0.04), 0.12, 0.12, COL_CREAM),
        ],
        axis_dir=(0.0, 1.0, 0.0),
        segs=10,
    )

    # 5. Gyro & GyroInner (counter-tilting gimbals driven by HeroAssets.counter_tilt; y >= -0.44m)
    # Kept above y = -0.44m via tilted/equatorial rings!
    gyro_outer = SurfaceData("bare_metal")
    gyro_outer.add_torus((0.0, 0.02, 0.0), (0.0, 1.0, 0.0), 0.855, 0.024, 0.036, 24, 8, COL_SILVER, COL_SLATE)
    for sx in (-0.855, 0.855):
        gyro_outer.add_chamfered_box((sx, 0.02, 0.0), (0.075, 0.095, 0.12), 0.014, COL_SILVER, COL_BRASS)

    gyro_inner = SurfaceData("copper")
    gyro_inner.add_torus((0.0, 0.05, 0.0), (0.0, 0.96, 0.28), 0.815, 0.020, 0.030, 24, 8, COL_COPPER, COL_BRASS)

    # 6. SpliceDish: Patch's signature wok-cut parabolic dish + quadripod copper feedhorn
    # Mounted aft-starboard at Pod child [0.34, 0.56, 0.44] (world r <= 1.18m, y >= 0.28m)
    dish_paint = SurfaceData("paint")
    dish_axis = (0.28, 0.62, 0.73)
    dish_paint.add_lofted_tube(
        [
            ((0.0, 0.0, 0.0), 0.09, 0.09, COL_VERDIGRIS),
            (v_mul(dish_axis, 0.05), 0.24, 0.24, COL_VERDIGRIS_LIGHT),
            (v_mul(dish_axis, 0.12), 0.36, 0.36, COL_CREAM),
            (v_mul(dish_axis, 0.16), 0.39, 0.39, COL_VERDIGRIS_LIGHT),
            (v_mul(dish_axis, 0.18), 0.34, 0.34, COL_CREAM),
        ],
        axis_dir=dish_axis,
        segs=16,
    )
    # Central feedhorn LNB + 3 feed struts
    feed_tip = v_mul(dish_axis, 0.36)
    dish_paint.add_lofted_tube(
        [
            (v_mul(dish_axis, 0.30), 0.048, 0.048, COL_COPPER),
            (v_mul(dish_axis, 0.40), 0.034, 0.034, COL_STICKER_PINK),
        ],
        axis_dir=dish_axis,
        segs=8,
    )
    ax_dx, ax_dy, ax_dz = basis_from_axis(dish_axis)
    for k in range(3):
        ang = 2.0 * math.pi * k / 3.0
        rim_pt = xform_point((0.0, 0.0, 0.0), ax_dx, ax_dy, ax_dz, (math.cos(ang) * 0.30, 0.15, math.sin(ang) * 0.30))
        mid_pt = v_mul(v_add(rim_pt, feed_tip), 0.5)
        strut_dir = v_sub(feed_tip, rim_pt)
        dish_paint.add_chamfered_box(
            mid_pt,
            (0.022, v_len(strut_dir), 0.022),
            0.005,
            COL_SLATE,
            COL_SILVER,
            axis_dir=strut_dir,
        )

    # 7. CableSpool: salvaged copper/fiber splice drum mounted aft-port [-0.38, 0.44, 0.42]
    spool_surf = SurfaceData("copper")
    spool_axis = (1.0, 0.18, -0.22)
    spool_surf.add_lofted_tube(
        [
            (v_mul(spool_axis, -0.13), 0.22, 0.22, COL_SLATE),
            (v_mul(spool_axis, -0.09), 0.22, 0.22, COL_BRASS),
            (v_mul(spool_axis, -0.08), 0.145, 0.145, COL_COPPER),
            (v_mul(spool_axis, 0.08), 0.145, 0.145, COL_COPPER),
            (v_mul(spool_axis, 0.09), 0.22, 0.22, COL_BRASS),
            (v_mul(spool_axis, 0.13), 0.22, 0.22, COL_SLATE),
        ],
        axis_dir=spool_axis,
        segs=16,
    )

    # 8. WeaponRing: equatorial splicer turret ring + twin signal-tapper coil prongs + forward coupler
    # Strictly y in [-0.16, +0.28] (>= -0.55m) and horizontal radius <= 1.46m (<= 1.75m)!
    ring_paint = SurfaceData("paint")
    ring_accent = SurfaceData("class_accent")

    ring_paint.add_torus((0.0, 0.04, 0.0), (0.0, 1.0, 0.0), 1.065, 0.045, 0.062, 32, 8, COL_VERDIGRIS, COL_CREAM)
    # Forward splice emitter housing
    ring_paint.add_chamfered_box((0.0, 0.05, -1.16), (0.48, 0.16, 0.24), 0.026, COL_VERDIGRIS_LIGHT, COL_CREAM)
    for side in (-1.0, 1.0):
        # Twin forward signal-tapper lances
        ring_paint.add_lofted_tube(
            [
                ((side * 0.19, 0.06, -1.12), 0.068, 0.068, COL_SLATE),
                ((side * 0.19, 0.06, -1.30), 0.052, 0.052, COL_COPPER),
                ((side * 0.19, 0.06, -1.42), 0.034, 0.034, COL_BRASS),
            ],
            axis_dir=(0.0, 0.0, -1.0),
            segs=10,
        )
        # Side cable-clamp fairings
        ring_paint.add_chamfered_box(
            (side * 1.10, 0.05, -0.18),
            (0.14, 0.15, 0.44),
            0.024,
            COL_VERDIGRIS,
            COL_SLATE,
        )
        # Glowing class_accent splice indicator coils on lances
        ring_accent.add_torus(
            (side * 0.19, 0.06, -1.26),
            (0.0, 0.0, -1.0),
            0.062,
            0.016,
            0.022,
            12,
            6,
            COL_WHITE_PAINT,
            up_hint=(0.0, 1.0, 0.0),
        )

    surfaces_all = [
        ("Core.paint", core_paint),
        ("Pod.paint", pod_paint),
        ("PilotSeat", seat_surf),
        ("Pilot", standin_surf),
        ("Gyro", gyro_outer),
        ("GyroInner", gyro_inner),
        ("SpliceDish", dish_paint),
        ("CableSpool", spool_surf),
        ("WeaponRing.paint", ring_paint),
        ("WeaponRing.accent", ring_accent),
    ]
    total_tris = 0
    for lbl, s in surfaces_all:
        info = s.verify(f"ShellPatch.{lbl}")
        total_tris += info["tris"]
    assert total_tris <= 6500, f"ShellPatch triangle budget exceeded: {total_tris} > 6500"

    m_core = writer.add_mesh("Core", [core_paint])
    m_pod = writer.add_mesh("Pod", [pod_paint])
    m_seat = writer.add_mesh("PilotSeat", [seat_surf])
    m_pilot = writer.add_mesh("Pilot", [standin_surf])
    m_gyro = writer.add_mesh("Gyro", [gyro_outer])
    m_gyro_in = writer.add_mesh("GyroInner", [gyro_inner])
    m_dish = writer.add_mesh("SpliceDish", [dish_paint])
    m_spool = writer.add_mesh("CableSpool", [spool_surf])
    m_ring = writer.add_mesh("WeaponRing", [ring_paint, ring_accent])

    core_child_ids = [writer.add_node(nm, translation=pos) for nm, pos in lattice_sockets]
    n_core = writer.add_node("Core", (0.0, 0.0, 0.0), children=core_child_ids, mesh=m_core)

    n_pilot_standin = writer.add_node("Pilot", (0.0, 0.0, 0.0), mesh=m_pilot)
    n_seat = writer.add_node("PilotSeat", (0.0, 0.0, 0.0), mesh=m_seat)
    n_dome = writer.add_node("Dome", (0.0, 0.0, 0.0), children=[n_pilot_standin, n_seat])

    n_gyro_in = writer.add_node("GyroInner", (0.0, 0.0, 0.0), mesh=m_gyro_in)
    n_gyro = writer.add_node("Gyro", (0.0, 0.0, 0.0), children=[n_gyro_in], mesh=m_gyro)

    n_dish = writer.add_node("SpliceDish", (0.34, 0.56, 0.44), mesh=m_dish)
    n_spool = writer.add_node("CableSpool", (-0.38, 0.44, 0.42), mesh=m_spool)

    n_emit_l = writer.add_node("Emitter.L", (-0.19, 0.06, -1.42))
    n_emit_r = writer.add_node("Emitter.R", (0.19, 0.06, -1.42))
    n_wmount = writer.add_node("WeaponMount", (0.0, 0.05, -1.21))
    n_ring = writer.add_node("WeaponRing", (0.0, 0.0, 0.0), children=[n_emit_l, n_emit_r, n_wmount], mesh=m_ring)

    n_rope = writer.add_node("RopeExit", (0.9522, -0.1876, -0.135))
    n_grip_l = writer.add_node("Control.Grip.L", (-0.32, 0.05, -0.40))
    n_grip_r = writer.add_node("Control.Grip.R", (0.32, 0.05, -0.40))
    n_ped_l = writer.add_node("Control.Pedal.L", (-0.13, -0.42, -0.45))
    n_ped_r = writer.add_node("Control.Pedal.R", (0.13, -0.42, -0.45))
    n_lever = writer.add_node("Control.GaugeLever", (0.48, -0.22, -0.30))
    n_trig = writer.add_node("Control.Trigger", (0.32, 0.09, -0.43))

    n_pod = writer.add_node(
        "Pod",
        (0.0, 0.0, 0.0),
        children=[
            n_dome,
            n_gyro,
            n_dish,
            n_spool,
            n_ring,
            n_rope,
            n_grip_l,
            n_grip_r,
            n_ped_l,
            n_ped_r,
            n_lever,
            n_trig,
        ],
        mesh=m_pod,
    )
    n_root = writer.add_node("ShellPatch", (0.0, 0.0, 0.0), children=[n_core, n_pod])

    # Verify Ruling en horizontal reach <= 1.75m and Pod/WeaponRing min_y >= -0.55m across all world-positioned vertices
    max_r = 0.0
    pod_min_y = 999.0
    for surf, off in (
        (core_paint, (0.0, 0.0, 0.0)),
        (pod_paint, (0.0, 0.0, 0.0)),
        (seat_surf, (0.0, 0.0, 0.0)),
        (gyro_outer, (0.0, 0.0, 0.0)),
        (gyro_inner, (0.0, 0.0, 0.0)),
        (dish_paint, (0.34, 0.56, 0.44)),
        (spool_surf, (-0.38, 0.44, 0.42)),
        (ring_paint, (0.0, 0.0, 0.0)),
        (ring_accent, (0.0, 0.0, 0.0)),
    ):
        for px, py, pz in surf.positions:
            wx, wy, wz = px + off[0], py + off[1], pz + off[2]
            max_r = max(max_r, math.hypot(wx, wz))
            if surf is not core_paint:
                pod_min_y = min(pod_min_y, wy)
    assert max_r <= 1.75, f"ShellPatch max_r={max_r:.3f} > 1.75"
    assert pod_min_y >= -0.55, f"ShellPatch pod_min_y={pod_min_y:.3f} < -0.55"

    writer.write(SHELL_GLB_PATH, [n_root])
    return {
        "shell_tris": total_tris,
        "shell_surfaces": len(surfaces_all),
        "max_r": round(max_r, 3),
        "pod_min_y": round(pod_min_y, 3),
    }


if __name__ == "__main__":
    p_stats = build_pilot_patch_glb()
    s_stats = build_shell_patch_glb()
    print("Built Patch GLBs successfully:", json.dumps({**p_stats, **s_stats}))
