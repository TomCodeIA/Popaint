"""Popaint : aperçu 3D des modèles (rendu par lancer de rayons, simplifié).

Usage : python3 tools/preview/render.py <entree.json> <sortie.png> [taille_case] [colonnes] [angle]
Chaque modèle du JSON (tools/preview/export.luau) est dessiné dans une case d'une planche.
Ce n'est pas le rendu exact de Roblox, mais formes, couleurs et proportions sont fidèles.
"""
import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SUN = np.array([-0.45, 0.8, -0.4])
SUN = SUN / np.linalg.norm(SUN)
BG_TOP = np.array([0.93, 0.90, 1.0])
BG_BOTTOM = np.array([0.99, 0.95, 0.97])


def frame(part):
    c = part["cf"]
    pos = np.array(c[0:3], dtype=float)
    rot = np.array(c[3:12], dtype=float).reshape(3, 3)  # colonnes = axes X, Y, Z locaux
    return pos, rot


def intersect(shape, o, d, half):
    """o, d : rayons en coordonnées locales (N, 3). Retourne t (N,) et normales locales (N, 3)."""
    n = o.shape[0]
    t = np.full(n, np.inf)
    normal = np.zeros((n, 3))
    with np.errstate(divide="ignore", invalid="ignore"):
        if shape in ("Ball", "Ellipsoid"):
            if shape == "Ball":
                r = min(half)
                half = np.array([r, r, r])
            oo, dd = o / half, d / half
            a = (dd * dd).sum(1)
            b = 2 * (oo * dd).sum(1)
            cc = (oo * oo).sum(1) - 1
            disc = b * b - 4 * a * cc
            hit = disc >= 0
            s = np.sqrt(np.where(hit, disc, 0))
            t0 = (-b - s) / (2 * a)
            t1 = (-b + s) / (2 * a)
            tt = np.where(t0 > 1e-4, t0, t1)
            ok = hit & (tt > 1e-4)
            t = np.where(ok, tt, np.inf)
            p = o + d * t[:, None]
            normal = p / (half * half)
        elif shape == "Cylinder":
            r = min(half[1], half[2])
            hl = half[0]
            # paroi (axe X)
            a = d[:, 1] ** 2 + d[:, 2] ** 2
            b = 2 * (o[:, 1] * d[:, 1] + o[:, 2] * d[:, 2])
            cc = o[:, 1] ** 2 + o[:, 2] ** 2 - r * r
            disc = b * b - 4 * a * cc
            hit = (disc >= 0) & (a > 1e-9)
            s = np.sqrt(np.where(hit, disc, 0))
            tw = (-b - s) / (2 * a)
            px = o[:, 0] + d[:, 0] * tw
            okw = hit & (tw > 1e-4) & (np.abs(px) <= hl)
            t = np.where(okw, tw, np.inf)
            pw = o + d * tw[:, None]
            nw = np.stack([np.zeros(n), pw[:, 1], pw[:, 2]], 1)
            normal = np.where(okw[:, None], nw, normal)
            # bouchons
            for sign in (-1, 1):
                tc = (sign * hl - o[:, 0]) / d[:, 0]
                pc = o + d * tc[:, None]
                okc = (tc > 1e-4) & (pc[:, 1] ** 2 + pc[:, 2] ** 2 <= r * r) & (tc < t)
                t = np.where(okc, tc, t)
                normal = np.where(okc[:, None], np.array([sign, 0, 0]), normal)
        else:  # Block, Wedge (approché par un bloc), CornerWedge
            t_near = np.full(n, -np.inf)
            t_far = np.full(n, np.inf)
            axis = np.zeros(n, dtype=int)
            sgn = np.ones(n)
            for k in range(3):
                t1 = (-half[k] - o[:, k]) / d[:, k]
                t2 = (half[k] - o[:, k]) / d[:, k]
                lo = np.minimum(t1, t2)
                hi = np.maximum(t1, t2)
                better = lo > t_near
                axis = np.where(better, k, axis)
                sgn = np.where(better, np.where(t1 < t2, -1.0, 1.0), sgn)
                t_near = np.maximum(t_near, lo)
                t_far = np.minimum(t_far, hi)
            ok = (t_near <= t_far) & (t_far > 1e-4)
            tt = np.where(t_near > 1e-4, t_near, t_far)
            t = np.where(ok, tt, np.inf)
            normal = np.zeros((n, 3))
            normal[np.arange(n), axis] = sgn
            if shape == "Wedge":
                # coupe en biais : on garde la moitié sous le plan y/hy + z/hz <= 0 (pente vers l'avant)
                p = o + d * t[:, None]
                inside = p[:, 1] / half[1] - p[:, 2] / half[2] <= 1e-3
                # sinon on cherche l'intersection avec le plan de la pente
                pn = np.array([1 / half[1], 0, 0])
                pn = np.array([0.0, 1 / half[1], -1 / half[2]])
                denom = (d * pn).sum(1)
                tp = -(o * pn).sum(1) / denom
                pp = o + d * tp[:, None]
                inbox = np.all(np.abs(pp) <= half + 1e-3, axis=1) & (tp > 1e-4)
                use_plane = (~inside) & inbox
                t = np.where(inside & ok, t, np.where(use_plane, tp, np.inf))
                normal = np.where(use_plane[:, None], pn, normal)
    nn = np.linalg.norm(normal, axis=1, keepdims=True)
    with np.errstate(invalid="ignore", divide="ignore"):
        normal = np.nan_to_num(normal / np.where(nn > 0, nn, 1))
    return t, normal


def render(parts, size=360, yaw=35, pitch=28):
    if not parts:
        return Image.new("RGB", (size, size), (240, 235, 250))
    # boîte englobante pour cadrer
    pts = []
    for p in parts:
        pos, _ = frame(p)
        h = max(p["size"]) / 2
        pts.append(pos - h)
        pts.append(pos + h)
    pts = np.array(pts)
    lo, hi = pts.min(0), pts.max(0)
    center = (lo + hi) / 2
    radius = np.linalg.norm(hi - lo) / 2 + 0.5
    yr, pr = math.radians(yaw), math.radians(pitch)
    fwd = -np.array([math.cos(pr) * math.sin(yr), math.sin(pr), math.cos(pr) * math.cos(yr)])
    eye = center - fwd * radius * 3.2
    right = np.cross(fwd, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    fov = math.radians(36)
    xs = (np.arange(size) + 0.5) / size * 2 - 1
    ys = 1 - (np.arange(size) + 0.5) / size * 2
    gx, gy = np.meshgrid(xs, ys)
    tanf = math.tan(fov / 2)
    dirs = fwd[None, None, :] + gx[..., None] * tanf * right + gy[..., None] * tanf * up
    dirs = dirs.reshape(-1, 3)
    dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
    n = dirs.shape[0]
    origin = np.broadcast_to(eye, (n, 3))

    best_t = np.full(n, np.inf)
    color = np.zeros((n, 3))
    # fond
    v = (gy.reshape(-1) + 1) / 2
    bg = BG_BOTTOM[None] * (1 - v[:, None]) + BG_TOP[None] * v[:, None]
    # sol
    ground_y = lo[1] - 0.05
    tg = (ground_y - origin[:, 1]) / dirs[:, 1]
    gok = (tg > 0) & (dirs[:, 1] < 0)
    best_t = np.where(gok, tg, best_t)
    gp = origin + dirs * tg[:, None]
    gd = np.linalg.norm((gp - center)[:, [0, 2]], axis=1) / (radius * 1.6)
    ground_col = np.array([0.97, 0.93, 0.98])[None] * (1 - np.clip(gd, 0, 1)[:, None] * 0.25)
    color = np.where(gok[:, None], ground_col, bg)
    hit_normal = np.zeros((n, 3))
    hit_part = np.full(n, -1)

    for idx, p in enumerate(parts):
        pos, rot = frame(p)
        half = np.array(p["size"]) / 2
        lo_ = origin - pos
        o_local = lo_ @ rot
        d_local = dirs @ rot
        t, nl = intersect(p["shape"], o_local, d_local, half)
        closer = t < best_t
        if not closer.any():
            continue
        best_t = np.where(closer, t, best_t)
        hit_part = np.where(closer, idx, hit_part)
        hit_normal = np.where(closer[:, None], nl @ rot.T, hit_normal)

    hit = hit_part >= 0
    # ombre portée simple sur le sol (rayon vers le soleil)
    shade = np.ones(n)
    if gok.any():
        g_idx = np.where(gok & ~hit)[0]
        if len(g_idx):
            so = gp[g_idx] + SUN * 0.05
            sd = np.broadcast_to(SUN, (len(g_idx), 3))
            blocked = np.zeros(len(g_idx), dtype=bool)
            for p in parts:
                pos, rot = frame(p)
                half = np.array(p["size"]) / 2
                t, _ = intersect(p["shape"], (so - pos) @ rot, sd @ rot, half)
                blocked |= np.isfinite(t)
            shade[g_idx] = np.where(blocked, 0.78, 1.0)
    color = color * shade[:, None]

    for idx, p in enumerate(parts):
        sel = hit_part == idx
        if not sel.any():
            continue
        base = np.array(p["color"])
        nrm = hit_normal[sel]
        lam = np.clip((nrm * SUN).sum(1), 0, 1)
        sky = 0.5 + 0.5 * nrm[:, 1]
        light = 0.55 + 0.42 * lam + 0.12 * sky
        view = -dirs[sel]
        half_v = SUN[None] + view
        half_v /= np.linalg.norm(half_v, axis=1, keepdims=True)
        spec = np.clip((nrm * half_v).sum(1), 0, 1) ** 40
        mat = p["material"]
        if mat == "Neon":
            col = np.minimum(base * 1.15 + 0.1, 1)[None].repeat(sel.sum(), 0)
        else:
            gloss = 0.35 if mat in ("SmoothPlastic", "Glass", "ForceField") else 0.15
            col = base[None] * light[:, None] + spec[:, None] * gloss
            # studs : petits points clairs sur les faces du dessus
            if p["studs"]:
                pts_hit = origin[sel] + dirs[sel] * best_t[sel][:, None]
                pos, rot = frame(p)
                loc = (pts_hit - pos) @ rot
                top = nrm[:, 1] > 0.9
                fx = np.mod(loc[:, 0] + 0.5, 1.0) - 0.5
                fz = np.mod(loc[:, 2] + 0.5, 1.0) - 0.5
                dot = top & (fx * fx + fz * fz < 0.09)
                col = np.where(dot[:, None], np.minimum(col * 1.12 + 0.02, 1), col)
        tr = p["transparency"]
        if mat == "ForceField":
            tr = max(tr, 0.55)
        if mat == "Glass":
            tr = max(tr, 0.2)
        if tr > 0:
            col = col * (1 - tr) + color[sel] * tr
        color[sel] = col
    # contour léger (style jouet)
    img = np.clip(color, 0, 1).reshape(size, size, 3)
    hp = hit_part.reshape(size, size)
    edge = np.zeros((size, size), dtype=bool)
    edge[1:, :] |= hp[1:, :] != hp[:-1, :]
    edge[:, 1:] |= hp[:, 1:] != hp[:, :-1]
    img[edge] *= 0.72
    return Image.fromarray((img * 255).astype(np.uint8))


def main():
    src, out = sys.argv[1], sys.argv[2]
    cell = int(sys.argv[3]) if len(sys.argv) > 3 else 300
    cols = int(sys.argv[4]) if len(sys.argv) > 4 else 6
    yaw = float(sys.argv[5]) if len(sys.argv) > 5 else 35
    scenes = json.load(open(src))
    rows = math.ceil(len(scenes) / cols)
    sheet = Image.new("RGB", (cols * cell, rows * (cell + 26)), (250, 246, 252))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    for k, s in enumerate(scenes):
        im = render(s["parts"], cell, yaw)
        x, y = (k % cols) * cell, (k // cols) * (cell + 26)
        sheet.paste(im, (x, y))
        draw.text((x + 8, y + cell + 4), f'{s["name"]} ({len(s["parts"])})', fill=(70, 50, 100), font=font)
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
