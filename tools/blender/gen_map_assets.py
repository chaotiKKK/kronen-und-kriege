#!/usr/bin/env python3
"""Erzeugt Kartenrelief und Marker-Meshes headless mit Blender 5.x.

Aufruf (von tools/gen_map_assets.py):
    blender --background --factory-startup --python tools/blender/gen_map_assets.py -- \
        --height build/map_asset_work/heightmap.png --work build/map_asset_work

Alle Geometrien entstehen in diesem Skript aus Primitiven bzw. dem aus den
Projektprovinzen erzeugten Höhenfeld. Es werden keine CK3- oder Fremdassets
geladen.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

MAP_W = 12.0
MAP_H = 7.6
RELIEF_Z = 1.25
RELIEF_RES_X = 400
RELIEF_RES_Y = 253
MARKER_SIZE = 256

PALETTE = {
    "stone": (0.47, 0.42, 0.34, 1.0),
    "stone_light": (0.63, 0.56, 0.43, 1.0),
    "stone_dark": (0.29, 0.25, 0.20, 1.0),
    "roof": (0.43, 0.12, 0.075, 1.0),
    "roof_light": (0.55, 0.19, 0.10, 1.0),
    "wood": (0.20, 0.12, 0.065, 1.0),
    "gold": (0.86, 0.60, 0.16, 1.0),
    "cloth": (0.55, 0.075, 0.055, 1.0),
    "cloth_dark": (0.33, 0.035, 0.030, 1.0),
    "shadow": (0.10, 0.075, 0.050, 1.0),
    "relief": (0.56, 0.54, 0.50, 1.0),
}


def parse_args() -> argparse.Namespace:
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--height", required=True)
    parser.add_argument("--work", required=True)
    return parser.parse_args(raw)


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.02
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 4
    scene.cycles.seed = 7319
    scene.cycles.use_animated_seed = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 70
    scene.render.film_transparent = True
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0


def load_height(path: Path) -> np.ndarray:
    image = bpy.data.images.load(str(path), check_existing=False)
    image.colorspace_settings.name = "Non-Color"
    width, height = image.size
    raw = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(raw)
    pixels = raw.reshape(height, width, 4)
    # Blender speichert die unterste Bildzeile zuerst; das Höhenfeld ist oben.
    return np.flipud(pixels[..., 0]).copy()


def make_material(name: str, color: tuple[float, float, float, float], *,
                  metallic: float = 0.0, roughness: float = 0.82) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def make_relief_material() -> bpy.types.Material:
    return make_material("map_relief_stone", PALETTE["relief"], roughness=0.96)


def add_sun(name: str, location: tuple[float, float, float], target: tuple[float, float, float],
            energy: float, angle: float = 5.0) -> bpy.types.Object:
    data = bpy.data.lights.new(name, type="SUN")
    data.energy = energy
    data.angle = math.radians(angle)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return obj


def add_camera() -> bpy.types.Object:
    data = bpy.data.cameras.new("MapCamera")
    data.type = "ORTHO"
    data.ortho_scale = MAP_W
    obj = bpy.data.objects.new("MapCamera", data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = (0.0, 0.0, 11.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.scene.camera = obj
    return obj


def build_relief(height: np.ndarray) -> bpy.types.Object:
    rows, cols = height.shape
    nx = RELIEF_RES_X
    ny = RELIEF_RES_Y
    xs = np.linspace(0.0, cols - 1.0, nx)
    ys = np.linspace(0.0, rows - 1.0, ny)
    sample = height[np.rint(ys).astype(int)[:, None], np.rint(xs).astype(int)[None, :]]
    verts = []
    for iy in range(ny):
        y = MAP_H * 0.5 - (iy / float(ny - 1)) * MAP_H
        for ix in range(nx):
            x = -MAP_W * 0.5 + (ix / float(nx - 1)) * MAP_W
            verts.append((x, y, float(sample[iy, ix]) * RELIEF_Z))
    faces = []
    for iy in range(ny - 1):
        for ix in range(nx - 1):
            a = iy * nx + ix
            b = a + 1
            c = a + nx
            d = c + 1
            faces.append((a, c, d, b))
    mesh = bpy.data.meshes.new("MapReliefMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new("MapRelief", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(make_relief_material())
    return obj


def configure_relief_render(scene: bpy.types.Scene, work: Path) -> None:
    scene.render.resolution_x = 2400
    scene.render.resolution_y = 1520
    scene.cycles.samples = 40
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.filepath = str(work / "relief_shaded_raw.png")


def finished(obj: bpy.types.Object, material: bpy.types.Material) -> bpy.types.Object:
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj


def cube(name: str, location, scale, material: bpy.types.Material, rotation=(0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    return finished(obj, material)


def cylinder(name: str, location, radius: float, depth: float,
             material: bpy.types.Material, vertices: int = 10, rotation=(0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                        location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    return finished(obj, material)


def cone(name: str, location, radius: float, depth: float,
         material: bpy.types.Material, vertices: int = 8, rotation=(0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=0.0,
                                    depth=depth, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    return finished(obj, material)


def sphere(name: str, location, radius: float, material: bpy.types.Material,
           segments: int = 16, rings: int = 8) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings,
                                         radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    return finished(obj, material)


def tri_pennant(name: str, base: Vector, width: float, length: float,
                material: bpy.types.Material) -> bpy.types.Object:
    verts = [
        (base.x, base.y, base.z),
        (base.x + width, base.y, base.z - length * 0.42),
        (base.x, base.y, base.z - length),
    ]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], [(0, 1, 2)])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def build_castle() -> list[bpy.types.Object]:
    mats = {
        "stone": make_material("castle_stone", PALETTE["stone"]),
        "stone_light": make_material("castle_stone_light", PALETTE["stone_light"]),
        "stone_dark": make_material("castle_stone_dark", PALETTE["stone_dark"]),
        "roof": make_material("castle_roof", PALETTE["roof"], roughness=0.72),
        "wood": make_material("castle_wood", PALETTE["wood"]),
        "gold": make_material("castle_gold", PALETTE["gold"], metallic=0.75, roughness=0.28),
        "cloth": make_material("castle_cloth", PALETTE["cloth"], roughness=0.8),
        "shadow": make_material("castle_shadow", PALETTE["shadow"], roughness=1.0),
    }
    out: list[bpy.types.Object] = []
    out.append(cylinder("Castle_Base", (0, 0, 0.10), 0.92, 0.20, mats["shadow"], vertices=12))
    out.append(cylinder("Castle_Rock", (0, 0, 0.22), 0.80, 0.18, mats["stone_dark"], vertices=9))
    out.append(cube("Castle_Courtyard", (0, 0, 0.38), (1.38, 1.10, 0.25), mats["stone"]))
    # Vier Ecktürme mit Zinnen und flachen Kegeldächern.
    for index, (x, y) in enumerate(((-0.58, -0.45), (0.58, -0.45), (-0.58, 0.45), (0.58, 0.45))):
        out.append(cylinder("Castle_Tower_%d" % index, (x, y, 0.82), 0.17, 0.95, mats["stone_light"], vertices=8))
        out.append(cone("Castle_TowerRoof_%d" % index, (x, y, 1.44), 0.25, 0.32, mats["roof"], vertices=8))
        for mx, my in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
            out.append(cube("Castle_Merlon_%d_%d_%d" % (index, mx, my),
                            (x + mx * 0.12, y + my * 0.12, 1.28),
                            (0.08, 0.08, 0.15), mats["stone_light"]))
    # Zentraler Bergfried und Tor.
    out.append(cube("Castle_Keep", (0, 0, 0.92), (0.52, 0.52, 1.02), mats["stone_light"]))
    out.append(cube("Castle_KeepBand", (0, 0, 1.16), (0.58, 0.58, 0.10), mats["stone_dark"]))
    out.append(cone("Castle_KeepRoof", (0, 0, 1.62), 0.42, 0.42, mats["roof"], vertices=8))
    out.append(cube("Castle_Gate", (0, -0.565, 0.42), (0.30, 0.055, 0.36), mats["wood"]))
    out.append(cube("Castle_GateTrim", (0, -0.595, 0.42), (0.34, 0.035, 0.07), mats["gold"]))
    # Fahne auf dem Bergfried.
    out.append(cylinder("Castle_Flagpole", (0, 0, 2.02), 0.018, 0.66, mats["wood"], vertices=6))
    out.append(sphere("Castle_FlagFinial", (0, 0, 2.36), 0.045, mats["gold"], segments=10, rings=6))
    out.append(tri_pennant("Castle_Pennant", Vector((0.02, 0, 2.31)), 0.42, 0.30, mats["cloth"]))
    return out


def build_banner() -> list[bpy.types.Object]:
    mats = {
        "stone": make_material("banner_stone", PALETTE["stone"]),
        "stone_dark": make_material("banner_stone_dark", PALETTE["stone_dark"]),
        "wood": make_material("banner_wood", PALETTE["wood"]),
        "gold": make_material("banner_gold", PALETTE["gold"], metallic=0.78, roughness=0.25),
        "cloth": make_material("banner_cloth", PALETTE["cloth"], roughness=0.78),
        "cloth_dark": make_material("banner_cloth_dark", PALETTE["cloth_dark"], roughness=0.82),
    }
    out: list[bpy.types.Object] = []
    out.append(cylinder("Banner_Base", (0, 0, 0.09), 0.56, 0.18, mats["stone_dark"], vertices=10))
    out.append(cylinder("Banner_Plinth", (0, 0, 0.20), 0.43, 0.12, mats["stone"], vertices=10))
    out.append(cylinder("Banner_Pole", (0, 0, 1.30), 0.035, 2.40, mats["wood"], vertices=8))
    out.append(cylinder("Banner_Collar", (0, 0, 2.30), 0.07, 0.10, mats["gold"], vertices=8))
    out.append(sphere("Banner_Finial", (0, 0, 2.47), 0.10, mats["gold"], segments=12, rings=7))
    out.append(cube("Banner_Crossbar", (0, 0, 2.18), (0.94, 0.045, 0.045), mats["wood"]))
    for side in (-1.0, 1.0):
        out.append(sphere("Banner_CrossTip_%d" % int(side), (side * 0.48, 0, 2.18), 0.07,
                          mats["gold"], segments=10, rings=6))
    # Leicht gewelltes Tuch mit Schwalbenschwanz.
    verts = []
    faces = []
    cols = 10
    rows = 7
    for iy in range(rows):
        t = iy / float(rows - 1)
        z = 2.12 - t * 0.70
        for ix in range(cols):
            u = ix / float(cols - 1)
            x = -0.44 + u * 0.88
            y = -0.07 + math.sin(u * math.pi * 3.0) * 0.025 * (0.4 + t)
            if iy == rows - 1:
                z = 1.42 if abs(u - 0.5) < 0.22 else 1.49
            verts.append((x, y, z))
    for iy in range(rows - 1):
        for ix in range(cols - 1):
            a = iy * cols + ix
            b = a + 1
            c = a + cols
            d = c + 1
            faces.append((a, b, d, c))
    mesh = bpy.data.meshes.new("Banner_ClothMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    cloth = bpy.data.objects.new("Banner_Cloth", mesh)
    bpy.context.scene.collection.objects.link(cloth)
    cloth.data.materials.append(mats["cloth"])
    solidify = cloth.modifiers.new("ClothThickness", "SOLIDIFY")
    solidify.thickness = 0.018
    solidify.offset = 0.0
    out.append(cloth)
    # Goldener Ring als eigenständiges Zeichen auf dem Tuch.
    bpy.ops.mesh.primitive_torus_add(major_radius=0.125, minor_radius=0.022,
                                      major_segments=20, minor_segments=6,
                                      location=(0, -0.105, 1.81),
                                      rotation=(math.radians(90), 0, 0))
    ring = bpy.context.active_object
    ring.name = "Banner_Ring"
    out.append(finished(ring, mats["gold"]))
    # Drei Stoffstreifen am unteren Rand geben dem Banner Tiefe.
    for index, x in enumerate((-0.31, 0.0, 0.31)):
        out.append(cube("Banner_Tail_%d" % index, (x, -0.02, 1.44),
                        (0.16, 0.012, 0.12), mats["cloth_dark"],
                        rotation=(0, 0, 0.16 if index == 0 else (-0.16 if index == 2 else 0.0))))
    return out


def export_marker(objects: list[bpy.types.Object], path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )
    print("MAPASSETS GLB", path, path.stat().st_size)


def point_camera(camera: bpy.types.Object, location, target=(0, 0, 1.0), ortho=3.15) -> None:
    camera.location = location
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.ortho_scale = ortho


def render_marker(objects: list[bpy.types.Object], path: Path, camera: bpy.types.Object,
                  scene: bpy.types.Scene, target_z: float) -> None:
    for obj in bpy.data.objects:
        if obj.type == "MESH" and obj not in objects:
            obj.hide_render = True
    for obj in objects:
        obj.hide_render = False
    scene.render.resolution_x = MARKER_SIZE
    scene.render.resolution_y = MARKER_SIZE
    scene.cycles.samples = 64
    scene.render.film_transparent = True
    scene.render.filepath = str(path)
    point_camera(camera, (3.1, -4.6, 2.9), target=(0, 0, target_z), ortho=3.05)
    bpy.ops.render.render(write_still=True)
    print("MAPASSETS SPRITE", path, path.stat().st_size)


def purge_meshes() -> None:
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)


def main() -> None:
    args = parse_args()
    height_path = Path(args.height).resolve()
    work = Path(args.work).resolve()
    work.mkdir(parents=True, exist_ok=True)
    if not height_path.exists():
        raise SystemExit("Höhenkarte fehlt: %s" % height_path)

    reset_scene()
    scene = bpy.context.scene
    height = load_height(height_path)
    print("MAPASSETS HEIGHT", height_path, height.shape, float(height.min()), float(height.max()))

    bpy.context.scene.world = bpy.data.worlds.new("MapWorld")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.42, 0.43, 0.45, 1.0)
    background.inputs["Strength"].default_value = 0.30
    add_sun("ReliefKey", (-6.0, 5.0, 8.0), (0.0, 0.0, 0.0), 2.1, angle=6.0)
    add_sun("ReliefFill", (5.0, -4.0, 7.0), (0.0, 0.0, 0.0), 0.22, angle=12.0)
    camera = add_camera()
    relief = build_relief(height)
    configure_relief_render(scene, work)
    bpy.ops.render.render(write_still=True)
    print("MAPASSETS RELIEF", work / "relief_shaded_raw.png")

    # Marker: gleiche Kamera, aber neutraleres Licht und transparenter Grund.
    relief.hide_render = True
    point_camera(camera, (3.1, -4.6, 2.9), target=(0, 0, 1.1), ortho=3.15)
    scene.cycles.samples = 64

    purge_meshes()
    castle = build_castle()
    export_marker(castle, work / "marker_castle.glb")
    render_marker(castle, work / "marker_castle_raw.png", camera, scene, 1.05)

    purge_meshes()
    banner = build_banner()
    export_marker(banner, work / "marker_banner.glb")
    render_marker(banner, work / "marker_banner_raw.png", camera, scene, 1.15)

    print("MAPASSETS BLENDER OK")


if __name__ == "__main__":
    main()
