"""Headless-Blender-Generator für alle prozeduralen Assets von "Kronen und Kriege".

Ein Aufruf rendert den kompletten Satz:
  * 17 Karten-Token (9 Gelände, 3 Gebäude, 5 Einheiten)  256x256 RGBA, isometrisch
  * 12 Charakterporträts                                 512x512, Brustbild
  * 8 Ereignisbilder                                     960x540, Szene mit Vorder-/Hintergrund
und schreibt assets/asset_manifest.json mit Dateiliste, Zielgrößen, Deckungs-
korridoren und der Zuordnung zu den Schlüsseln aus dem Spielcode.

Alle Meshes entstehen aus Primitiven — keine Fremdassets, keine CK3-Daten.

Aufruf (Blender 5.2, background):
    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" \
        --background --python tools/blender/make_tokens.py
"""

import json
import math
import os

import bpy

ROOT = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.abspath(os.path.join(ROOT, "..", "..", "assets"))
TOKEN_DIR = os.path.join(ASSETS, "ui", "tokens")
PORTRAIT_DIR = os.path.join(ASSETS, "ui", "portraits")
EVENT_DIR = os.path.join(ASSETS, "ui", "events")
MANIFEST_PATH = os.path.join(ASSETS, "asset_manifest.json")

RES_TOKEN = 256
RES_PORTRAIT = 512
EVENT_SIZE = (960, 540)

PALETTE = {
    "grass": (0.24, 0.42, 0.16),
    "grass_dark": (0.13, 0.27, 0.10),
    "soil": (0.36, 0.24, 0.12),
    "sand": (0.70, 0.60, 0.36),
    "water": (0.13, 0.40, 0.58),
    "stone": (0.38, 0.36, 0.34),
    "stone_light": (0.60, 0.58, 0.54),
    "snow": (0.95, 0.96, 0.97),
    "trunk": (0.26, 0.16, 0.09),
    "leaf": (0.11, 0.32, 0.12),
    "reed": (0.33, 0.42, 0.16),
    "heather": (0.50, 0.24, 0.56),
    "roof": (0.50, 0.19, 0.13),
    "wood": (0.36, 0.23, 0.12),
    "cloth": (0.76, 0.24, 0.18),
    "dry": (0.62, 0.52, 0.24),
    "skin_light": (0.80, 0.62, 0.46),
    "skin_mid": (0.64, 0.44, 0.30),
    "skin_dark": (0.42, 0.26, 0.17),
    "hair_black": (0.07, 0.06, 0.06),
    "hair_brown": (0.25, 0.14, 0.07),
    "hair_blond": (0.68, 0.52, 0.24),
    "hair_grey": (0.72, 0.70, 0.66),
    "eye": (0.04, 0.04, 0.05),
    "mouth": (0.32, 0.12, 0.10),
    "garment_red": (0.44, 0.11, 0.11),
    "garment_blue": (0.13, 0.21, 0.40),
    "garment_green": (0.14, 0.29, 0.17),
    "garment_purple": (0.26, 0.13, 0.32),
    "garment_white": (0.76, 0.74, 0.68),
    "linen": (0.50, 0.47, 0.41),
    "gold": (0.80, 0.62, 0.20),
    "steel": (0.55, 0.57, 0.60),
    "steel_dark": (0.28, 0.30, 0.33),
    "sky_warm": (0.72, 0.40, 0.18),
    "sky_dusk": (0.22, 0.20, 0.28),
    "sky_day": (0.56, 0.64, 0.72),
    "ground_field": (0.56, 0.43, 0.17),
    "ground_dark": (0.15, 0.13, 0.11),
    "silhouette": (0.05, 0.04, 0.04),
    "ember": (1.00, 0.62, 0.22),
    "backdrop": (0.58, 0.55, 0.50),
}


def material(name):
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    rgb = PALETTE[name]
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = 0.72
    if name == "ember":
        bsdf.inputs["Emission Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = 6.0
    m.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    return m


def _finish(obj, color):
    obj.data.materials.clear()
    obj.data.materials.append(material(color))
    return obj


def disc(color="grass", radius=1.0, z=0.08, depth=0.16, loc=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=radius, depth=depth,
                                        location=(loc[0], loc[1], z))
    return _finish(bpy.context.active_object, color)


def box(loc, size, color, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.scale = (size[0] * 0.5, size[1] * 0.5, size[2] * 0.5)
    return _finish(obj, color)


def cone(loc, r1, r2, depth, color, vertices=16, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2,
                                    depth=depth, location=loc, rotation=rot)
    return _finish(bpy.context.active_object, color)


def ball(loc, radius, color, scale=(1.0, 1.0, 1.0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=radius,
                                         location=loc)
    obj = bpy.context.active_object
    obj.scale = scale
    bpy.ops.object.shade_smooth()
    return _finish(obj, color)


def ring(loc, radius, thickness, color, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=thickness,
                                     major_segments=32, minor_segments=8,
                                     location=loc, rotation=rot)
    return _finish(bpy.context.active_object, color)


# --- Karten-Token: Gelände ----------------------------------------------

def terrain_plains():
    disc("grass")
    for x, y in ((-0.34, 0.18), (0.10, 0.34), (0.36, -0.10)):
        cone((x, y, 0.32), 0.10, 0.0, 0.30, "grass_dark", vertices=8)


def terrain_farmland():
    disc("dry")
    for i in range(5):
        box((0.0, -0.52 + i * 0.26, 0.20), (1.35, 0.10, 0.06), "soil")


def terrain_forest():
    disc("grass_dark")
    for x, y, h in ((-0.36, 0.10, 0.62), (0.06, -0.22, 0.74), (0.38, 0.26, 0.56)):
        box((x, y, 0.34), (0.09, 0.09, 0.22), "trunk")
        cone((x, y, 0.42 + h * 0.35), 0.26, 0.0, h, "leaf", vertices=10)


def terrain_hills():
    disc("grass")
    for x, y, r in ((-0.30, 0.10, 0.42), (0.20, -0.20, 0.34), (0.26, 0.34, 0.26)):
        ball((x, y, 0.18), r, "grass_dark", scale=(1.15, 1.0, 0.52))


def terrain_mountains():
    disc("stone")
    cone((-0.26, 0.06, 0.62), 0.44, 0.0, 1.00, "stone_light", vertices=7)
    cone((0.34, -0.16, 0.48), 0.34, 0.0, 0.74, "stone", vertices=7)
    cone((-0.26, 0.06, 1.00), 0.17, 0.0, 0.26, "snow", vertices=7)
    cone((0.34, -0.16, 0.76), 0.13, 0.0, 0.18, "snow", vertices=7)


def terrain_marsh():
    disc("grass_dark")
    for x, y in ((-0.26, -0.18), (0.28, 0.22)):
        disc("water", radius=0.26, z=0.19, depth=0.04, loc=(x, y, 0.0))
    for x, y, h in ((-0.44, 0.24, 0.44), (-0.26, 0.34, 0.36), (0.10, 0.40, 0.40),
                    (0.42, -0.16, 0.34), (0.20, -0.34, 0.38)):
        cone((x, y, 0.18 + h * 0.5), 0.04, 0.02, h, "reed", vertices=5)


def terrain_coast():
    disc("water", radius=1.08, z=0.05, depth=0.10)
    disc("sand", radius=0.82, z=0.14, depth=0.12, loc=(-0.16, 0.10, 0.0))
    disc("water", radius=0.30, z=0.17, depth=0.04, loc=(0.36, -0.30, 0.0))


def terrain_steppe():
    disc("dry")
    for x, y in ((-0.30, 0.22), (0.02, -0.30), (0.36, 0.12), (-0.06, 0.34)):
        cone((x, y, 0.28), 0.08, 0.0, 0.22, "grass_dark", vertices=6)


def terrain_heath():
    disc("stone")
    for x, y, r in ((-0.28, 0.14, 0.16), (0.16, 0.30, 0.12), (0.30, -0.18, 0.14)):
        ball((x, y, 0.24), r, "heather", scale=(1.0, 1.0, 0.7))


# --- Karten-Token: Gebäude ----------------------------------------------

def building_barracks():
    disc("grass")
    box((0.0, 0.0, 0.36), (1.20, 0.72, 0.40), "stone_light")
    cone((0.0, 0.0, 0.66), 0.86, 0.0, 0.34, "roof", vertices=4,
         rot=(0.0, 0.0, math.pi / 4))
    box((0.0, 0.37, 0.28), (0.30, 0.06, 0.32), "trunk")
    box((0.0, 0.0, 1.02), (0.05, 0.05, 0.46), "wood")
    box((0.17, 0.0, 1.18), (0.30, 0.03, 0.15), "cloth")


def building_walls():
    disc("grass_dark")
    box((0.0, 0.0, 0.34), (1.44, 0.34, 0.52), "stone")
    for i in range(5):
        x = -0.56 + i * 0.28
        box((x, 0.02, 0.72), (0.18, 0.38, 0.26), "stone_light")
    box((0.0, 0.0, 0.13), (1.60, 0.52, 0.10), "stone")


def building_market():
    disc("dry")
    for x, y in ((-0.46, -0.30), (0.46, -0.30), (-0.46, 0.30), (0.46, 0.30)):
        box((x, y, 0.42), (0.08, 0.08, 0.68), "wood")
    box((0.0, 0.0, 0.80), (1.16, 0.80, 0.06), "cloth", rot=(0.0, 0.0, 0.10))
    box((0.0, 0.10, 0.34), (0.90, 0.46, 0.14), "wood")
    ball((-0.20, 0.10, 0.50), 0.10, "cloth", scale=(1.0, 1.0, 0.9))
    ball((0.18, 0.10, 0.50), 0.09, "dry", scale=(1.0, 1.0, 0.9))


# --- Karten-Token: Einheiten --------------------------------------------

def _footman(x, y, body="garment_green", weapon=True, scale=1.0):
    h = 0.62 * scale
    box((x, y, 0.16 + h * 0.5), (0.16 * scale, 0.14 * scale, h), body)
    ball((x, y, 0.16 + h + 0.075 * scale), 0.085 * scale, "skin_mid")
    cone((x, y, 0.16 + h + 0.075 * scale), 0.105 * scale, 0.105 * scale,
         0.055 * scale, "steel_dark")
    if weapon:
        box((x + 0.13 * scale, y, 0.16 + h * 0.8), (0.022, 0.022, h * 1.7), "wood")
        cone((x + 0.13 * scale, y, 0.16 + h * 1.62), 0.04, 0.0, 0.14, "steel",
             vertices=6)


def unit_levy():
    disc("grass_dark")
    _footman(-0.40, 0.06, "garment_green", scale=1.05)
    _footman(0.02, -0.18, "garment_blue", scale=0.98)
    _footman(0.40, 0.12, "garment_green", scale=1.02)


def unit_knight():
    disc("grass")
    box((0.0, 0.0, 0.40), (0.72, 0.26, 0.26), "hair_brown")
    box((0.30, 0.0, 0.52), (0.22, 0.20, 0.30), "hair_brown", rot=(0.0, 0.35, 0.0))
    box((0.44, 0.0, 0.60), (0.20, 0.15, 0.13), "hair_brown")
    for dx in (-0.26, -0.10, 0.14, 0.30):
        box((dx, 0.0, 0.22), (0.07, 0.07, 0.36), "hair_black")
    box((0.0, 0.0, 0.68), (0.28, 0.24, 0.38), "steel")
    ball((0.0, 0.0, 0.94), 0.11, "steel")
    box((0.02, 0.0, 0.96), (0.03, 0.07, 0.11), "steel_dark")
    box((0.32, 0.0, 0.76), (0.44, 0.02, 0.02), "wood")
    cone((0.56, 0.0, 0.76), 0.03, 0.0, 0.12, "steel", vertices=6,
         rot=(0.0, math.radians(90), 0.0))


def unit_archer():
    disc("grass_dark")
    _footman(-0.06, 0.02, "garment_blue", weapon=False, scale=1.05)
    # Bogen: kleiner Halbkreis vor der Brust, Sehne als dünner Faden
    ring((-0.06, -0.20, 0.72), 0.135, 0.014, "wood",
         rot=(math.radians(90), 0.0, 0.0))
    box((-0.06, -0.20, 0.72), (0.008, 0.008, 0.27), "cloth")
    # Köcher am Rücken
    box((0.13, 0.13, 0.72), (0.10, 0.10, 0.30), "wood")
    for i in range(3):
        cone((0.13, 0.13, 0.90), 0.018, 0.0, 0.14, "steel", vertices=5)


def unit_siege():
    disc("dry")
    box((0.0, 0.0, 0.28), (0.90, 0.50, 0.20), "wood")
    for x in (-0.42, 0.42):
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.20, depth=0.10,
                                            location=(x, 0.0, 0.18),
                                            rotation=(math.radians(90), 0.0, 0.0))
        _finish(bpy.context.active_object, "hair_black")
    box((0.0, 0.0, 0.54), (0.14, 0.14, 0.42), "wood", rot=(0.0, 0.22, 0.0))
    box((-0.28, 0.0, 0.74), (0.62, 0.10, 0.10), "wood", rot=(0.0, 0.50, 0.0))
    box((-0.52, 0.0, 0.86), (0.16, 0.18, 0.16), "stone")
    ball((0.34, 0.0, 0.40), 0.09, "stone_light")


def unit_fleet():
    disc("water")
    box((0.0, 0.0, 0.26), (0.92, 0.30, 0.18), "wood")
    cone((0.50, 0.0, 0.30), 0.15, 0.0, 0.26, "wood", vertices=6,
         rot=(0.0, math.radians(90), 0.0))
    box((0.0, 0.0, 0.62), (0.05, 0.05, 0.70), "trunk")
    box((0.16, 0.0, 0.74), (0.30, 0.02, 0.34), "cloth")
    box((-0.14, 0.0, 0.58), (0.16, 0.02, 0.14), "cloth")


TOKENS = [
    ("terrain_plains", terrain_plains),
    ("terrain_farmland", terrain_farmland),
    ("terrain_forest", terrain_forest),
    ("terrain_hills", terrain_hills),
    ("terrain_mountains", terrain_mountains),
    ("terrain_marsh", terrain_marsh),
    ("terrain_coast", terrain_coast),
    ("terrain_steppe", terrain_steppe),
    ("terrain_heath", terrain_heath),
    ("building_barracks", building_barracks),
    ("building_walls", building_walls),
    ("building_market", building_market),
    ("unit_levy", unit_levy),
    ("unit_knight", unit_knight),
    ("unit_archer", unit_archer),
    ("unit_siege", unit_siege),
    ("unit_fleet", unit_fleet),
]


# --- Charakterporträts ---------------------------------------------------

def portrait(cfg):
    skin = cfg.get("skin", "skin_mid")
    hair = cfg.get("hair", "hair_brown")
    beard = cfg.get("beard", "none")
    garment = cfg.get("garment", "garment_blue")
    accent = cfg.get("accent", "gold")
    headwear = cfg.get("headwear", "none")
    hairstyle = cfg.get("hair_style", "short")
    child = cfg.get("child", False)
    s = 0.92 if child else 1.0
    hr = (0.315 if child else 0.30) * s
    head_z = (1.34 if child else 1.42) * s

    # Rumpf: schmale Schultern, konischer Mantel, kein Kugel-Schulterpaar
    cone((0.0, 0.0, 0.68 * s), 0.42 * s, 0.25 * s, 0.70 * s, garment, vertices=32)
    box((0.0, -0.04 * s, 0.86 * s), (0.50 * s, 0.30 * s, 0.52 * s), garment)
    for side in (-1.0, 1.0):
        cone((side * 0.27 * s, 0.0, 0.72 * s), 0.105 * s, 0.075 * s, 0.46 * s,
             garment, vertices=14, rot=(0.0, side * math.radians(12), 0.0))
    ring((0.0, 0.0, 1.06 * s), 0.205 * s, 0.028 * s, accent)
    box((0.0, -0.235 * s, 0.78 * s), (0.085, 0.03, 0.46 * s), accent)
    # Hals und Kopf
    cone((0.0, 0.0, 1.13 * s), 0.10 * s, 0.10 * s, 0.18 * s, skin)
    ball((0.0, 0.0, head_z), hr, skin, scale=(0.92, 1.0, 1.08))
    ball((0.0, -hr * 0.32, head_z - hr * 0.66), hr * 0.52, skin,
         scale=(1.0, 0.78, 0.58))
    for side in (-1.0, 1.0):
        ball((side * hr * 0.93, 0.02, head_z - 0.02), hr * 0.20, skin,
             scale=(0.55, 1.0, 1.25))
    # Augen mit Lichtpunkt, Brauen, Nase, Mund
    for side in (-1.0, 1.0):
        ball((side * hr * 0.36, -hr * 0.86, head_z + 0.02), hr * 0.16, "eye",
             scale=(1.0, 0.62, 1.0))
        ball((side * hr * 0.33, -hr * 0.96, head_z + 0.06), hr * 0.05,
             "garment_white", scale=(1.0, 0.5, 1.0))
        box((side * hr * 0.37, -hr * 0.90, head_z + 0.17),
            (hr * 0.46, hr * 0.10, hr * 0.075), hair)
    cone((0.0, -hr * 0.99, head_z - 0.05), hr * 0.13, 0.0, hr * 0.42, skin,
         vertices=10, rot=(math.radians(-96), 0.0, 0.0))
    box((0.0, -hr * 0.95, head_z - hr * 0.54),
        (hr * 0.34, hr * 0.10, hr * 0.07), "mouth")
    # Haare
    if hairstyle == "short":
        ball((0.0, 0.05 * s, head_z + hr * 0.15), hr * 1.04, hair,
             scale=(0.99, 1.0, 0.74))
    elif hairstyle == "long":
        ball((0.0, 0.04 * s, head_z + hr * 0.15), hr * 1.05, hair,
             scale=(0.99, 1.0, 0.76))
        for side in (-1.0, 1.0):
            ball((side * hr * 0.86, 0.10, head_z - hr * 0.58), hr * 0.56, hair,
                 scale=(0.48, 0.72, 1.45))
    elif hairstyle == "bald":
        ball((0.0, 0.09 * s, head_z + hr * 0.17), hr * 1.02, hair,
             scale=(0.95, 0.85, 0.32))
    # Bart
    if beard == "full":
        ball((0.0, -hr * 0.50, head_z - hr * 0.60), hr * 0.70, hair,
             scale=(1.0, 0.68, 0.85))
    elif beard == "short":
        ball((0.0, -hr * 0.58, head_z - hr * 0.66), hr * 0.50, hair,
             scale=(1.05, 0.58, 0.70))
    elif beard == "long":
        cone((0.0, -hr * 0.40, head_z - hr * 0.92), hr * 0.42, hr * 0.10,
             hr * 1.05, hair, vertices=14)
    # Kopfbedeckung
    if headwear == "crown":
        cone((0.0, 0.0, head_z + hr * 0.96), hr * 0.78, hr * 0.78, hr * 0.24,
             accent, vertices=24)
        for i in range(5):
            ang = math.radians(-60 + i * 30)
            box((math.sin(ang) * hr * 0.66, math.cos(ang) * hr * 0.66,
                 head_z + hr * 1.20), (hr * 0.15, hr * 0.15, hr * 0.30), accent,
                rot=(0.0, 0.0, ang))
    elif headwear == "circlet":
        ring((0.0, 0.0, head_z + hr * 0.64), hr * 0.99, hr * 0.055, accent)
    elif headwear == "helmet":
        ball((0.0, 0.10 * s, head_z + hr * 0.20), hr * 1.06, "steel",
             scale=(1.0, 0.78, 0.92))
        box((0.0, -hr * 0.86, head_z + hr * 0.50),
            (hr * 1.30, hr * 0.55, hr * 0.14), "steel")
        box((0.0, -hr * 0.92, head_z - hr * 0.05),
            (hr * 0.13, hr * 0.09, hr * 0.90), "steel")
    elif headwear == "hood":
        ball((0.0, 0.28 * s, head_z + hr * 0.02), hr * 1.16, "linen",
             scale=(1.08, 0.88, 1.10))
        for side in (-1.0, 1.0):
            box((side * hr * 1.02, 0.16, head_z - hr * 0.68),
                (hr * 0.22, hr * 0.66, hr * 1.30), "linen")
    elif headwear == "veil":
        for side in (-1.0, 1.0):
            box((side * hr * 1.02, 0.30, head_z - hr * 0.46),
                (hr * 0.16, hr * 0.52, hr * 1.36), "linen",
                rot=(0.0, 0.0, side * math.radians(6)))
        ball((0.0, 0.20, head_z + hr * 0.10), hr * 1.06, "linen",
             scale=(1.02, 0.88, 0.90))
    elif headwear == "headwrap":
        ring((0.0, 0.0, head_z + hr * 0.52), hr * 0.96, hr * 0.14, accent)
        ball((0.0, 0.06, head_z + hr * 0.30), hr * 1.00, accent,
             scale=(1.0, 0.95, 0.48))


PORTRAITS = [
    {"name": "portrait_ruler_male_adult", "skin": "skin_mid", "hair": "hair_brown",
     "hair_style": "short", "beard": "full", "garment": "garment_red",
     "accent": "gold", "headwear": "crown"},
    {"name": "portrait_ruler_female_adult", "skin": "skin_light", "hair": "hair_black",
     "hair_style": "long", "garment": "garment_purple", "accent": "gold",
     "headwear": "circlet"},
    {"name": "portrait_council_male_mid", "skin": "skin_mid", "hair": "hair_brown",
     "hair_style": "short", "beard": "short", "garment": "garment_blue",
     "accent": "gold"},
    {"name": "portrait_council_female_mid", "skin": "skin_light",
     "hair": "hair_brown", "hair_style": "long", "garment": "garment_green",
     "accent": "gold"},
    {"name": "portrait_clergy_male_old", "skin": "skin_light", "hair": "hair_grey",
     "hair_style": "bald", "beard": "long", "garment": "linen",
     "accent": "gold", "headwear": "hood"},
    {"name": "portrait_clergy_female_mid", "skin": "skin_light",
     "hair": "hair_brown", "hair_style": "long", "garment": "linen",
     "accent": "gold", "headwear": "veil"},
    {"name": "portrait_child_boy", "skin": "skin_light", "hair": "hair_blond",
     "hair_style": "short", "garment": "garment_green", "accent": "gold",
     "child": True},
    {"name": "portrait_child_girl", "skin": "skin_light", "hair": "hair_blond",
     "hair_style": "long", "garment": "garment_blue", "accent": "gold",
     "child": True},
    {"name": "portrait_knight_male_adult", "skin": "skin_mid", "hair": "hair_black",
     "hair_style": "short", "beard": "short", "garment": "garment_red",
     "accent": "steel", "headwear": "helmet"},
    {"name": "portrait_matron_female_old", "skin": "skin_light", "hair": "hair_grey",
     "hair_style": "long", "garment": "garment_purple", "accent": "gold",
     "headwear": "veil"},
    {"name": "portrait_steward_male_young", "skin": "skin_light",
     "hair": "hair_brown", "hair_style": "short", "garment": "garment_green",
     "accent": "gold"},
    {"name": "portrait_envoy_female_young", "skin": "skin_mid",
     "hair": "hair_black", "hair_style": "long", "garment": "garment_blue",
     "accent": "cloth", "headwear": "headwrap"},
]


# --- Ereignisbilder ------------------------------------------------------

def _floor(color, size=60.0):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0.0, 0.0, 0.0))
    _finish(bpy.context.active_object, color)


def _backdrop(color, y=14.0):
    bpy.ops.mesh.primitive_plane_add(size=60.0, location=(0.0, y, 7.0),
                                     rotation=(math.radians(90), 0.0, 0.0))
    _finish(bpy.context.active_object, color)


def _figure(x, y, height=1.0, color="silhouette", lean=0.0):
    body = height * 0.66
    cone((x, y, body * 0.5), height * 0.17, height * 0.11, body, color, vertices=12,
         rot=(0.0, lean, 0.0))
    ball((x + lean * height * 0.55, y, body + height * 0.09), height * 0.125, color,
         scale=(0.95, 0.95, 1.05))
    box((x, y, body * 1.00), (height * 0.34, height * 0.15, height * 0.09), color)


def event_court_reception():
    _floor("stone")
    _backdrop("sky_dusk", y=12.0)
    # Läufer zum Thron
    box((0.0, 3.9, 0.02), (1.5, 7.5, 0.04), "garment_red")
    for side in (-1.0, 1.0):
        cone((side * 2.0, 5.2, 2.0), 0.22, 0.26, 4.0, "stone_light", vertices=12)
        box((side * 2.0, 4.9, 2.3), (0.07, 0.07, 0.6), "trunk")
        ball((side * 2.0, 4.9, 2.66), 0.10, "ember")
    # Thron, groß und mittig im Hintergrund
    box((0.0, 7.4, 0.42), (1.7, 1.1, 0.84), "stone_light")
    box((0.0, 8.1, 1.75), (1.7, 0.25, 2.4), "stone_light")
    box((0.0, 7.6, 1.05), (1.3, 0.9, 0.24), "garment_red")
    # Herrscher sitzend
    box((0.0, 7.3, 1.46), (0.82, 0.55, 0.92), "garment_red")
    ball((0.0, 7.25, 2.12), 0.26, "skin_mid")
    cone((0.0, 7.25, 2.36), 0.24, 0.24, 0.12, "gold", vertices=16)
    for side in (-1.0, 1.0):
        box((side * 0.46, 7.25, 1.50), (0.16, 0.42, 0.62), "garment_red")
    # Bittsteller und Wachen
    _figure(-0.9, 4.4, 1.55, "garment_blue")
    _figure(1.6, 3.6, 1.75, "silhouette")
    _figure(-1.9, 3.1, 1.75, "silhouette")


def event_battle():
    _floor("ground_dark")
    _backdrop("sky_warm", y=16.0)
    ball((3.4, 14.5, 3.4), 1.25, "ember")
    # Hintergrundreihe: heller, kleiner, weiter weg
    for i, x in enumerate((-3.0, -1.6, 0.9, 2.6)):
        _figure(x, 7.0, 1.25 + i * 0.05, "stone")
        box((x + 0.24, 7.0, 1.25), (0.035, 0.035, 2.3), "trunk")
    # Vordergrundreihe als dunkle Silhouette, größer
    for i, x in enumerate((-2.4, -1.0, 0.4, 1.8)):
        _figure(x, 3.0, 2.15 + (i % 2) * 0.20, "silhouette")
        box((x + 0.30, 3.0, 1.75), (0.04, 0.04, 3.2), "trunk")
    # Banner seitlich im Vordergrund
    box((-3.15, 4.2, 2.6), (0.05, 0.05, 4.0), "trunk")
    box((-2.75, 4.2, 4.1), (0.75, 0.03, 0.62), "garment_red")


def event_harvest():
    _floor("ground_field")
    _backdrop("sky_day", y=20.0)
    ball((-3.4, 18.0, 4.0), 1.0, "ember")
    for i in range(7):
        box((0.0, 1.4 + i * 0.9, 0.03), (20.0, 0.22, 0.06), "soil")
    # Garben im Mittelgrund
    for x in (-3.0, -2.3, 2.4, 3.1):
        cone((x, 5.4, 0.62), 0.36, 0.18, 0.72, "dry", vertices=10)
    # Zwei Schnitter, aufrecht mit Sichel
    for x, y, h in ((-1.5, 3.4, 1.55), (0.5, 4.2, 1.45)):
        _figure(x, y, h, "garment_green")
        box((x + 0.34, y - 0.14, h * 0.62), (0.08, 0.46, 0.05), "steel",
            rot=(0.0, 0.0, math.radians(-22)))
    # Karren rechts
    box((2.3, 3.0, 0.46), (1.2, 0.7, 0.26), "wood")
    for x in (1.9, 2.7):
        bpy.ops.mesh.primitive_cylinder_add(vertices=18, radius=0.26, depth=0.08,
                                            location=(x, 3.35, 0.26),
                                            rotation=(math.radians(90), 0.0, 0.0))
        _finish(bpy.context.active_object, "trunk")


def _wheel(x, y, z, radius=0.32, depth=0.14, color="trunk"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=radius, depth=depth,
                                        location=(x, y, z),
                                        rotation=(math.radians(90), 0.0, 0.0))
    _finish(bpy.context.active_object, color)


def event_wedding():
    _floor("stone")
    _backdrop("sky_warm", y=14.0)
    ball((3.5, 13.3, 3.6), 1.15, "ember")
    # Blumenbogen über dem Paar
    for side in (-1.0, 1.0):
        box((side * 1.8, 6.2, 1.75), (0.34, 0.34, 3.5), "stone_light")
        box((side * 1.8, 6.2, 3.58), (0.42, 0.42, 0.16), "gold")
        for z in (2.25, 2.65, 3.05):
            ball((side * 1.8, 6.02, z), 0.13, "leaf")
    box((0.0, 6.2, 3.55), (3.9, 0.36, 0.30), "stone_light")
    for i in range(7):
        ball((-1.5 + i * 0.5, 6.02, 3.70 + 0.12 * math.sin(i)), 0.12, "leaf")
    # Banner rechts und links
    for side, color in ((-1.0, "garment_red"), (1.0, "garment_blue")):
        box((side * 3.0, 5.7, 2.0), (0.06, 0.06, 4.0), "trunk")
        box((side * 3.0, 5.66, 3.6), (0.65, 0.04, 0.60), color)
    # Brautpaar, Hände verbunden
    _figure(-0.55, 4.15, 1.70, "garment_blue")
    _figure(0.55, 4.15, 1.60, "linen")
    cone((0.55, 4.05, 0.58), 0.38, 0.18, 1.15, "garment_white", vertices=14)
    box((0.0, 4.05, 1.22), (0.60, 0.14, 0.09), "skin_light")
    cone((0.55, 4.15, 1.43), 0.20, 0.20, 0.10, "gold", vertices=14)
    box((-0.55, 4.30, 1.00), (0.50, 0.10, 0.90), "garment_red")
    # Gäste
    for x, y, h, color in ((-2.7, 3.2, 1.50, "garment_green"),
                           (-2.2, 4.8, 1.45, "garment_purple"),
                           (2.4, 3.1, 1.55, "garment_red"),
                           (2.9, 4.5, 1.40, "garment_green")):
        _figure(x, y, h, color)
    # Gabentisch links
    box((-2.9, 5.7, 0.65), (1.4, 0.65, 0.14), "wood")
    for x in (-3.3, -2.5):
        box((x, 5.7, 0.32), (0.10, 0.10, 0.65), "trunk")
    for x in (-3.2, -2.9, -2.6):
        cone((x, 5.65, 0.82), 0.07, 0.05, 0.16, "steel", vertices=12)
    # Geschenke rechts
    box((2.8, 3.0, 0.30), (0.70, 0.60, 0.60), "wood")
    box((2.8, 3.0, 0.62), (0.50, 0.40, 0.06), "gold")
    # Blüten auf dem Boden
    for x, y in ((-1.4, 2.7), (-0.9, 3.1), (1.2, 2.8), (1.7, 3.2),
                 (-2.0, 2.2), (2.0, 2.4)):
        box((x, y, 0.05), (0.12, 0.12, 0.03), "ember")


def event_monastery():
    _floor("ground_field")
    _backdrop("sky_day", y=18.0)
    ball((-3.4, 16.5, 4.1), 1.0, "ember")
    # Fundament und Stufen des werdenden Tempels
    box((0.0, 7.2, 0.14), (7.2, 3.2, 0.28), "stone")
    for i in range(3):
        box((0.0, 5.35 + i * 0.35, 0.10 + i * 0.10),
            (5.2 - i * 0.5, 0.4, 0.20), "stone_light")
    # Säulen und Architrav
    for x in (-2.5, -0.9, 0.9, 2.5):
        box((x, 7.2, 1.85), (0.32, 0.32, 3.30), "stone_light")
        box((x, 7.2, 0.35), (0.55, 0.55, 0.18), "stone")
    box((0.0, 7.2, 3.65), (6.0, 0.55, 0.40), "stone_light")
    box((0.0, 7.2, 4.05), (6.2, 2.2, 0.28), "roof")
    box((0.0, 6.05, 4.02), (0.65, 0.08, 0.65), "gold")
    box((0.0, 7.05, 1.55), (1.15, 0.12, 2.60), "wood")
    # Baugerüst links
    for z in (1.2, 2.4, 3.6):
        box((-4.0, 5.3, z), (0.08, 2.0, 0.08), "wood")
    for x in (-4.4, -3.6):
        box((x, 5.3, 1.8), (0.08, 0.08, 3.6), "wood")
    box((-4.0, 5.3, 2.4), (0.70, 2.2, 0.08), "wood")
    # Priester, Bauleute, Werkzeug und Steinvorrat
    _figure(1.6, 4.2, 1.70, "linen")
    box((1.95, 4.2, 1.05), (0.08, 0.50, 0.28), "garment_white")
    _figure(-1.3, 3.1, 1.55, "garment_green")
    box((-1.0, 3.0, 0.20), (0.55, 0.40, 0.40), "stone")
    _figure(-2.2, 4.0, 1.45, "garment_blue")
    for i in range(4):
        box((2.0 + i * 0.35, 2.5, 0.16 + i * 0.10),
            (0.35, 0.35, 0.30), "stone_light")
    box((1.55, 2.2, 0.06), (2.2, 0.10, 0.04), "wood")


def event_tithe():
    _floor("stone")
    _backdrop("sky_dusk", y=10.0)
    # Tempelbanner hinter dem Altar
    box((0.0, 9.35, 3.20), (3.4, 0.08, 3.0), "garment_red")
    box((0.0, 9.30, 4.70), (3.6, 0.06, 0.16), "gold")
    # Säulen und Fackeln
    for x in (-2.8, -1.7, 1.7, 2.8):
        cone((x, 6.9, 2.0), 0.22, 0.26, 4.0, "stone_light", vertices=12)
    for side in (-1.0, 1.0):
        cone((side * 2.35, 4.6, 0.85), 0.24, 0.17, 1.70, "stone")
        ball((side * 2.35, 4.6, 1.78), 0.10, "ember")
    # Altar mit Gabe
    box((0.0, 6.4, 0.50), (3.0, 1.3, 1.0), "stone_light")
    box((0.0, 6.4, 1.08), (3.2, 1.5, 0.18), "stone")
    cone((0.0, 6.35, 1.30), 0.48, 0.30, 0.28, "gold", vertices=16)
    for x in (-0.30, -0.10, 0.10, 0.30):
        disc("gold", radius=0.065, z=1.23, depth=0.025, loc=(x, 6.28, 0.0))
    cone((-0.90, 6.35, 1.38), 0.20, 0.05, 0.36, "dry", vertices=8)
    cone((0.90, 6.35, 1.38), 0.20, 0.05, 0.36, "dry", vertices=8)
    # Priester rechts vor dem Altar, mit erhobenen Armen
    _figure(1.30, 5.55, 1.85, "garment_white")
    cone((1.30, 5.45, 1.59), 0.20, 0.20, 0.10, "gold", vertices=14)
    box((0.88, 5.45, 1.46), (0.55, 0.12, 0.12), "garment_white",
        rot=(0.0, 0.0, math.radians(35)))
    box((1.72, 5.45, 1.46), (0.55, 0.12, 0.12), "garment_white",
        rot=(0.0, 0.0, math.radians(-35)))
    # Gläubiger mit Korn- und Goldsack
    _figure(-1.7, 3.8, 1.40, "garment_green")
    for x in (-2.35, 2.35):
        cone((x, 4.0, 0.48), 0.52, 0.26, 0.95, "dry", vertices=10)
        ball((x, 4.0, 0.98), 0.08, "gold")
    box((-1.25, 3.4, 0.22), (0.50, 0.40, 0.44), "wood")


def event_merchant():
    _floor("sand")
    _backdrop("sky_day", y=20.0)
    ball((3.2, 18.0, 4.2), 1.10, "ember")
    # Weg und Stadttor
    box((0.0, 5.2, 0.02), (3.4, 12.0, 0.04), "ground_field")
    for side in (-1.0, 1.0):
        box((side * 3.3, 9.0, 2.40), (1.3, 1.4, 4.8), "stone")
        box((side * 3.3, 9.0, 5.05), (1.6, 1.6, 0.22), "stone_light")
        box((side * 3.3, 8.2, 4.50), (1.5, 0.10, 0.55), "garment_blue")
        for i in range(3):
            box((side * 3.3, 8.30, 4.95 + i * 0.12),
                (1.4, 0.12, 0.18), "stone_light")
    box((0.0, 9.0, 4.90), (5.4, 1.4, 0.90), "stone")
    box((0.0, 8.45, 4.55), (2.0, 0.10, 0.22), "gold")
    # Handelsbanner im Tor
    box((-1.0, 8.6, 3.05), (0.55, 0.06, 0.90), "garment_red")
    box((1.0, 8.6, 3.05), (0.55, 0.06, 0.90), "garment_purple")
    # Flacher Planwagen links, ohne hohes Zeltdach
    box((-0.75, 4.0, 0.62), (1.9, 1.1, 0.28), "wood")
    box((-0.75, 4.0, 0.83), (1.6, 0.95, 0.22), "trunk")
    for x in (-1.45, -0.05):
        _wheel(x, 4.0, 0.42, radius=0.40, depth=0.12)
    # Ladung auf dem Wagen
    box((-0.95, 4.0, 1.08), (0.70, 0.75, 0.70), "garment_blue")
    box((-0.35, 4.0, 1.02), (0.55, 0.65, 0.58), "garment_red")
    # Waren vorne rechts
    box((1.75, 3.1, 0.42), (0.85, 0.75, 0.84), "garment_blue")
    box((2.45, 3.1, 0.30), (0.60, 0.60, 0.60), "garment_red")
    box((1.65, 2.25, 0.18), (0.70, 0.40, 0.36), "garment_purple")
    # Fass und Kisten links
    _wheel(-2.25, 3.3, 0.38, radius=0.34, depth=0.68, color="wood")
    box((-2.65, 3.3, 0.30), (0.35, 0.70, 0.60), "wood")
    # Händler, zentral und sichtbar
    _figure(0.75, 3.8, 1.65, "garment_purple")
    _figure(1.55, 4.4, 1.55, "garment_blue")
    # Waage auf einer Kiste
    box((0.85, 2.7, 0.35), (0.55, 0.45, 0.70), "wood")
    box((0.85, 2.7, 0.86), (0.05, 0.05, 0.70), "gold")
    box((0.85, 2.7, 1.20), (0.75, 0.04, 0.04), "gold")
    for side in (-1.0, 1.0):
        box((0.85 + side * 0.34, 2.7, 1.04), (0.03, 0.03, 0.32), "trunk")
        cone((0.85 + side * 0.34, 2.7, 0.90), 0.12, 0.08, 0.06, "steel", vertices=12)


def event_betrayal():
    _floor("ground_dark")
    _backdrop("sky_dusk", y=10.0)
    # Vorhang links als Trennung zum Hintergrund
    box((-2.2, 6.2, 2.2), (1.6, 0.12, 4.4), "garment_red")
    # Tisch
    box((0.4, 3.2, 0.72), (2.4, 0.9, 0.14), "wood")
    for x in (-0.6, 1.4):
        box((x, 3.2, 0.36), (0.12, 0.12, 0.72), "trunk")
    # Kerze: einzige warme Lichtquelle der Szene
    box((0.95, 3.05, 0.90), (0.06, 0.06, 0.22), "garment_white")
    ball((0.95, 3.05, 1.06), 0.055, "ember")
    # Zwei Figuren, eine mit erhobenem Dolch
    _figure(-0.6, 2.2, 1.75, "silhouette")
    _figure(1.5, 2.35, 1.70, "silhouette")
    box((0.45, 2.10, 1.30), (0.62, 0.09, 0.09), "steel",
        rot=(0.0, 0.0, math.radians(-30)))
    cone((0.10, 2.10, 1.30), 0.05, 0.0, 0.30, "steel", vertices=6,
         rot=(0.0, 0.0, math.radians(-120)))
    # Becher und Teller als Requisiten
    cone((0.15, 3.15, 0.86), 0.09, 0.07, 0.16, "steel", vertices=14)
    box((1.25, 3.2, 0.80), (0.34, 0.34, 0.03), "steel")


def event_fever():
    _floor("ground_dark")
    _backdrop("wood", y=12.0)
    # Deckenbalken und Fenster mit Dämmerlicht
    for x in (-3.3, -1.65, 0.0, 1.65, 3.3):
        box((x, 11.82, 2.5), (0.10, 0.12, 4.8), "trunk")
    box((0.0, 11.78, 4.85), (7.5, 0.12, 0.18), "trunk")
    box((2.25, 11.72, 3.15), (1.45, 0.06, 1.55), "sky_dusk")
    box((2.25, 11.66, 2.32), (1.70, 0.05, 0.12), "stone")
    box((2.25, 11.66, 3.98), (1.70, 0.05, 0.12), "stone")
    box((1.45, 11.66, 3.15), (0.12, 0.05, 1.78), "stone")
    box((3.05, 11.66, 3.15), (0.12, 0.05, 1.78), "stone")
    box((2.25, 11.64, 3.15), (0.08, 0.04, 1.55), "stone")
    # Bett mit Kranken und Decke
    box((-0.8, 4.5, 0.52), (2.9, 1.3, 0.22), "wood")
    for x in (-2.15, 0.55):
        for y in (3.95, 5.05):
            box((x, y, 0.25), (0.12, 0.12, 0.5), "trunk")
    box((-0.8, 4.5, 0.72), (2.7, 1.1, 0.18), "linen")
    box((-0.8, 4.5, 0.94), (2.55, 1.0, 0.28), "garment_blue")
    box((-1.65, 4.45, 1.07), (0.55, 0.72, 0.20), "garment_white")
    # Fieberkranker mit Tuch auf der Stirn
    ball((-1.55, 4.45, 1.27), 0.26, "skin_light", scale=(1.0, 1.1, 0.9))
    ball((-1.62, 4.58, 1.30), 0.23, "hair_brown", scale=(1.0, 0.55, 0.85))
    box((-1.55, 4.22, 1.40), (0.44, 0.06, 0.08), "garment_white")
    for ex in (-1.64, -1.46):
        box((ex, 4.19, 1.29), (0.055, 0.025, 0.018), "hair_black")
    box((-0.5, 4.5, 1.10), (1.6, 1.05, 0.16), "garment_blue")
    # Heiler mit Schale
    _figure(1.25, 4.0, 1.8, "garment_white")
    cone((1.25, 3.92, 1.57), 0.24, 0.10, 0.16, "garment_blue", vertices=12)
    for ex in (1.18, 1.32):
        box((ex, 3.77, 1.35), (0.035, 0.02, 0.02), "hair_black")
    box((1.65, 3.85, 1.24), (0.62, 0.12, 0.10), "garment_white",
        rot=(0.0, 0.0, math.radians(-28)))
    ball((1.91, 3.78, 1.22), 0.07, "skin_light")
    cone((1.95, 3.8, 1.12), 0.18, 0.10, 0.10, "steel", vertices=14)
    # Beistelltisch mit Arzneien
    box((1.8, 2.85, 0.62), (1.35, 0.65, 0.12), "wood")
    for x in (1.3, 2.3):
        box((x, 2.85, 0.31), (0.10, 0.10, 0.62), "trunk")
    cone((1.45, 2.8, 0.82), 0.09, 0.06, 0.24, "steel", vertices=10)
    cone((1.75, 2.8, 0.78), 0.08, 0.05, 0.20, "garment_green", vertices=10)
    ball((2.25, 2.8, 0.82), 0.08, "ember")
    # Kräuter und Feuerstelle
    for x in (-2.8, -2.4):
        box((x, 11.7, 3.9), (0.03, 0.03, 0.9), "trunk")
        ball((x, 11.7, 3.45), 0.13, "leaf")
    cone((-2.8, 3.2, 0.65), 0.45, 0.30, 1.2, "stone", vertices=10)
    ball((-2.8, 3.2, 1.33), 0.10, "ember")


EVENTS = [
    ("event_court_reception", event_court_reception, "sky_dusk"),
    ("event_battle", event_battle, "sky_warm"),
    ("event_harvest", event_harvest, "sky_day"),
    ("event_fever", event_fever, "sky_dusk"),
    ("event_wedding", event_wedding, "sky_warm"),
    ("event_monastery", event_monastery, "sky_day"),
    ("event_tithe", event_tithe, "sky_dusk"),
    ("event_merchant", event_merchant, "sky_day"),
]


# --- Szenen und Rendern --------------------------------------------------

def _base_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.use_denoising = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = 0.0
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.compression = 60
    return scene


def _world(scene, color, strength):
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (color[0], color[1], color[2], 1.0)
    bg.inputs[1].default_value = strength
    scene.world = world


def _sun(scene, energy=2.1, rot=(34.0, 8.0, -38.0)):
    data = bpy.data.lights.new("Sun", type="SUN")
    data.energy = energy
    data.angle = math.radians(10.0)
    obj = bpy.data.objects.new("Sun", data)
    obj.rotation_euler = tuple(math.radians(v) for v in rot)
    scene.collection.objects.link(obj)


def _area(scene, energy=90.0, loc=(-3.0, -2.4, 2.6), rot=(58.0, 0.0, -52.0),
          size=5.0):
    data = bpy.data.lights.new("Fill", type="AREA")
    data.energy = energy
    data.size = size
    obj = bpy.data.objects.new("Fill", data)
    obj.location = loc
    obj.rotation_euler = tuple(math.radians(v) for v in rot)
    scene.collection.objects.link(obj)


def _camera(scene, loc, rot, lens=None, ortho=None):
    data = bpy.data.cameras.new("Cam")
    if ortho is not None:
        data.type = "ORTHO"
        data.ortho_scale = ortho
    else:
        data.lens = lens or 50.0
    obj = bpy.data.objects.new("Cam", data)
    obj.location = loc
    obj.rotation_euler = tuple(math.radians(v) for v in rot)
    scene.collection.objects.link(obj)
    scene.camera = obj


def token_scene():
    scene = _base_scene()
    scene.cycles.samples = 24
    scene.render.resolution_x = RES_TOKEN
    scene.render.resolution_y = RES_TOKEN
    scene.render.film_transparent = True
    _world(scene, (0.55, 0.55, 0.58), 0.30)
    _camera(scene, (3.4, -3.4, 3.2), (57.0, 0.0, 45.0), ortho=2.55)
    _sun(scene, 2.1)
    _area(scene, 90.0)
    return scene


def portrait_scene():
    scene = _base_scene()
    scene.cycles.samples = 32
    scene.render.resolution_x = RES_PORTRAIT
    scene.render.resolution_y = RES_PORTRAIT
    scene.render.film_transparent = False
    _world(scene, (0.60, 0.57, 0.52), 1.0)
    _camera(scene, (0.0, -3.05, 1.20), (90.0, 0.0, 0.0), lens=85.0)
    _sun(scene, 2.4, (52.0, 10.0, -32.0))
    _area(scene, 150.0, (-2.0, -2.0, 1.9), (64.0, 0.0, -38.0), 4.0)
    return scene


def event_scene(world_color):
    scene = _base_scene()
    scene.cycles.samples = 40
    scene.render.resolution_x = EVENT_SIZE[0]
    scene.render.resolution_y = EVENT_SIZE[1]
    scene.render.film_transparent = False
    _world(scene, PALETTE[world_color], 0.42)
    _camera(scene, (0.0, -8.0, 2.30), (84.0, 0.0, 0.0), lens=38.0)
    _sun(scene, 2.7, (56.0, 8.0, -28.0))
    _area(scene, 260.0, (-3.5, -2.5, 3.6), (66.0, 0.0, -38.0), 7.0)
    return scene


def clear_meshes():
    for obj in list(bpy.data.objects):
        if obj.type in ("MESH", "LIGHT", "CAMERA"):
            bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)


def render_to(scene, path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    for d in (TOKEN_DIR, PORTRAIT_DIR, EVENT_DIR):
        os.makedirs(d, exist_ok=True)

    tokens = []
    scene = token_scene()
    for name, builder in TOKENS:
        clear_meshes()
        _world(scene, (0.55, 0.55, 0.58), 0.30)
        _camera(scene, (3.4, -3.4, 3.2), (57.0, 0.0, 45.0), ortho=2.55)
        _sun(scene, 2.1)
        _area(scene, 90.0)
        builder()
        path = os.path.join(TOKEN_DIR, name + ".png")
        render_to(scene, path)
        tokens.append(name)
        print("TOKEN %s" % name, flush=True)

    portraits = []
    scene = portrait_scene()
    for cfg in PORTRAITS:
        clear_meshes()
        _world(scene, (0.60, 0.57, 0.52), 1.0)
        _camera(scene, (0.0, -3.05, 1.20), (90.0, 0.0, 0.0), lens=85.0)
        _sun(scene, 2.4, (52.0, 10.0, -32.0))
        _area(scene, 150.0, (-2.0, -2.0, 1.9), (64.0, 0.0, -38.0), 4.0)
        portrait(cfg)
        path = os.path.join(PORTRAIT_DIR, cfg["name"] + ".png")
        render_to(scene, path)
        portraits.append(cfg["name"])
        print("PORTRAIT %s" % cfg["name"], flush=True)

    events = []
    scene = event_scene("sky_dusk")
    for name, builder, world_color in EVENTS:
        clear_meshes()
        _world(scene, PALETTE[world_color], 0.42)
        _camera(scene, (0.0, -8.0, 2.30), (84.0, 0.0, 0.0), lens=38.0)
        _sun(scene, 2.7, (56.0, 8.0, -28.0))
        _area(scene, 260.0, (-3.5, -2.5, 3.6), (66.0, 0.0, -38.0), 7.0)
        builder()
        path = os.path.join(EVENT_DIR, name + ".png")
        render_to(scene, path)
        events.append(name)
        print("EVENT %s" % name, flush=True)

    manifest = {
        "generated_by": "tools/blender/make_tokens.py",
        "blender": "5.2.1 LTS",
        "families": {
            "tokens": {
                "dir": "assets/ui/tokens",
                "size": [RES_TOKEN, RES_TOKEN],
                "coverage": [0.15, 0.55],
                "files": ["assets/ui/tokens/%s.png" % n for n in tokens],
            },
            "portraits": {
                "dir": "assets/ui/portraits",
                "size": [RES_PORTRAIT, RES_PORTRAIT],
                "coverage": [0.97, 1.0],
                "files": ["assets/ui/portraits/%s.png" % n for n in portraits],
            },
            "events": {
                "dir": "assets/ui/events",
                "size": [EVENT_SIZE[0], EVENT_SIZE[1]],
                "coverage": [0.97, 1.0],
                "files": ["assets/ui/events/%s.png" % n for n in events],
            },
        },
        "key_map": [
            *[{"code": "terrain.%s" % k, "asset": "assets/ui/tokens/terrain_%s.png" % k}
              for k in ("plains", "farmland", "forest", "hills", "mountains",
                        "marsh", "coast", "steppe", "heath")],
            *[{"code": "building.%s" % k, "asset": "assets/ui/tokens/building_%s.png" % k}
              for k in ("barracks", "walls", "market")],
            {"code": "unit.levy", "asset": "assets/ui/tokens/unit_levy.png"},
            {"code": "unit.archer", "asset": "assets/ui/tokens/unit_archer.png"},
            {"code": "unit.knight", "asset": "assets/ui/tokens/unit_knight.png"},
            {"code": "unit.siege", "asset": "assets/ui/tokens/unit_siege.png"},
            {"code": "unit.fleet", "asset": "assets/ui/tokens/unit_fleet.png"},
            {"code": "event.hoftag", "asset": "assets/ui/events/event_court_reception.png"},
            {"code": "event.hochzeit", "asset": "assets/ui/events/event_wedding.png"},
            {"code": "event.kloster", "asset": "assets/ui/events/event_monastery.png"},
            {"code": "event.zehnt", "asset": "assets/ui/events/event_tithe.png"},
            {"code": "event.ernte", "asset": "assets/ui/events/event_harvest.png"},
            {"code": "event.haendler", "asset": "assets/ui/events/event_merchant.png"},
            {"code": "event.grenzstreit", "asset": "assets/ui/events/event_battle.png"},
            {"code": "event.krankheit", "asset": "assets/ui/events/event_fever.png"},
        ],
        "open": [],
        "existing": [
            {"code": "characters.portrait_%d" % i,
             "asset": "assets/portraits/portrait_%d.png" % i}
            for i in range(12)
        ],
    }
    with open(MANIFEST_PATH, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    print("ASSETS OK: %d Token, %d Porträts, %d Ereignisse" %
          (len(tokens), len(portraits), len(events)), flush=True)


if __name__ == "__main__":
    main()
