"""Create the original field pennant and its map sprite in Blender."""
from pathlib import Path
import math
import sys

import bpy
from mathutils import Vector

output = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
output.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def material(name, rgb, metal=0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*rgb, 1.0)
    result.use_nodes = True
    shader = result.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*rgb, 1.0)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = .59
    return result


wood = material("Dunkles Eschenholz", (.21, .091, .036))
brass = material("Messingbeschläge", (.87, .52, .16), .45)
canvas = material("Helles Feldtuch", (.80, .62, .29))
seam = material("Dunkle Saumnaht", (.13, .25, .21))


def surface(name, substance):
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(substance)


def collar(name, substance, height, radius, width):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=width,
                                       location=(-.54, 0, height))
    surface(name, substance)


collar("Eschenstange", wood, .73, .042, 1.47)
collar("Beschlag oben", brass, 1.42, .076, .094)
collar("Schuh", brass, .095, .065, .16)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=.082,
                                   location=(-.54, 0, 1.53))
surface("Knauf", brass)

# Warp a narrow, tapered cloth as it leaves the pole. The outer bands read
# as a contrasting seam even after scaling the captured sprite down.
columns, rows = 12, 8
vertices = []
faces = []
for x in range(columns+1):
    u = x/columns
    for row in range(rows+1):
        v = row/rows
        width = .68*(1 - u*.83)
        z = 1.18 + u*.11 + (v-.5)*width
        y = .15*math.sin(6.5*u-.35)*(1-math.exp(-10*u)) + (v-.5)*.13*u
        vertices.append((-.51 + u*1.35, y, z))
for x in range(columns):
    for row in range(rows):
        i = x*(rows+1)+row
        faces.append((i, i+1, i+rows+2, i+rows+1))
mesh = bpy.data.meshes.new("Gefaltetes Tuch")
mesh.from_pydata(vertices, [], faces)
mesh.materials.append(canvas)
mesh.materials.append(seam)
for polygon in mesh.polygons:
    polygon.material_index = int(polygon.index % rows in (0, rows-1))
    polygon.use_smooth = True
cloth = bpy.data.objects.new("Feldwimpel", mesh)
scene.collection.objects.link(cloth)
fabric = cloth.modifiers.new("Doppelseitiger Stoff", "SOLIDIFY")
fabric.thickness = .026

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(output/"march_pennant.glb"),
                          export_format="GLB", use_selection=True, export_apply=True)

focus = Vector((.11, 0, .84))
for name, position, watts, size in [
    ("Hauptlicht", (2,-4,5), 530, 3.6),
    ("Aufhellung", (-3,-2,2), 280, 3.0),
]:
    lamp = bpy.data.lights.new(name, "AREA")
    lamp.energy, lamp.size = watts, size
    light = bpy.data.objects.new(name, lamp)
    scene.collection.objects.link(light)
    light.location = position
    light.rotation_euler = (focus-light.location).to_track_quat("-Z","Y").to_euler()

camera = bpy.data.objects.new("Kartensprite", bpy.data.cameras.new("Kartensprite"))
scene.collection.objects.link(camera)
camera.data.type = "ORTHO"
camera.data.ortho_scale = 1.84
camera.location = (1.28, -5, 2.10)
camera.rotation_euler = (focus-camera.location).to_track_quat("-Z","Y").to_euler()
scene.camera = camera
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 12
scene.cycles.use_denoising = True
scene.render.threads_mode = "FIXED"
scene.render.threads = 4
scene.render.resolution_x = scene.render.resolution_y = 128
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.color_mode = "RGBA"
scene.render.filepath = str(output/"march_pennant.png")
bpy.ops.render.render(write_still=True)
