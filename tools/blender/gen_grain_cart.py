"""Generate the original grain-cart mesh and its in-map sprite."""
from pathlib import Path
import math
import sys

import bpy
from mathutils import Vector

output = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
output.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def material(name, rgb):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*rgb, 1.0)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1.0)
    shader.inputs["Roughness"].default_value = .8
    return result


wood = material("Wagenplanken", (.36, .16, .048))
iron = material("Dunkle Radreifen", (.11, .087, .072))
linseed = material("Jutesäcke", (.83, .61, .31))
wheat = material("Helle Kornsäcke", (.96, .74, .33))
fiber = material("Bindfaden", (.24, .14, .045))


def finish(name, surface):
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(surface)
    return obj


def plank(name, center, size, surface=wood):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = finish(name, surface)
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Gerundete Kante", "BEVEL")
    bevel.width = .018
    bevel.segments = 1
    obj.modifiers.new("Flächennormalen", "WEIGHTED_NORMAL")
    return obj


plank("Dielenboden", (0, 0, .55), (1.36, .84, .14))
for sign in [-1, 1]:
    plank("Geländer", (0, sign*.45, .73), (1.34, .09, .25))
    plank("Fuhrstange", (.81, sign*.24, .48), (1.20, .065, .07))
    bpy.ops.mesh.primitive_torus_add(major_segments=16, minor_segments=6,
                                    major_radius=.33, minor_radius=.043,
                                    location=(-.10, sign*.54, .38),
                                    rotation=(math.pi/2, 0, 0))
    finish("Radreifen", iron)
    for spoke in range(6):
        obj = plank("Radspeiche", (-.10, sign*.54, .38), (.05, .07, .60))
        obj.rotation_euler.y = spoke*math.pi/6
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=.095, depth=.13,
                                      location=(-.10, sign*.56, .38),
                                      rotation=(math.pi/2, 0, 0))
    finish("Radnabe", iron)

for index, (x, y, z) in enumerate([(-.40, -.20, .83), (-.38,.20,.85), (.03,-.18,.85),
                                  (.05,.22,.87), (.29, .01, .88), (-.18, 0, 1.12)]):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, location=(x,y,z))
    sack = finish("Getreidesack", wheat if index % 2 else linseed)
    sack.scale = (.27,.21,.29)
    sack.rotation_euler.y = (-.22 if index % 2 else .20)
    bpy.ops.mesh.primitive_torus_add(major_segments=12, minor_segments=5,
                                    major_radius=.105, minor_radius=.020,
                                    location=(x,y,z+.215))
    finish("Sackbindung", fiber)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(output/"grain_cart.glb"),
                          export_format="GLB", use_selection=True, export_apply=True)

world = bpy.data.worlds.new("Atelier")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (.58,.57,.50,1)
world.node_tree.nodes["Background"].inputs[1].default_value = .65
scene.world = world
focus = Vector((.24,0,.56))

for name, location, watts, size in [
    ("Warme Fläche", (2,-4,5), 530, 4.0), ("Aufhellung", (-3,2,4), 370, 3.0),
]:
    light = bpy.data.lights.new(name, "AREA")
    light.energy, light.size = watts, size
    obj = bpy.data.objects.new(name, light)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (focus-obj.location).to_track_quat("-Z","Y").to_euler()

camera = bpy.data.objects.new("Kartensprite", bpy.data.cameras.new("Kartensprite"))
scene.collection.objects.link(camera)
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.65
camera.location = (3.1, -4.4, 3.45)
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
scene.render.filepath = str(output/"grain_cart.png")
bpy.ops.render.render(write_still=True)
