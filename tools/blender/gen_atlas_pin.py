"""Render the original Banger Queens reference-map pin in Blender."""

from pathlib import Path
import sys
import bpy
from mathutils import Vector

out = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def material(name, color, metallic=0.0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1.0)
    result.use_nodes = True
    shader = result.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Roughness"].default_value = 0.48
    shader.inputs["Metallic"].default_value = metallic
    return result

brass = material("Messing", (0.92, 0.57, 0.20), 0.35)
enamel = material("Dunkelblaues Email", (0.020, 0.104, 0.14))
ivory = material("Elfenbeinfarbene Markierung", (0.98, 0.88, 0.65))
dark = material("Dunkle Kontur", (0.033, 0.021, 0.013))

def disc(name, location, radius, depth, surface):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=depth,
                                       location=location, rotation=(1.5707963, 0.0, 0.0))
    item = bpy.context.object
    item.name = name
    item.data.materials.append(surface)

def silhouette(name, outline, depth, center_y, surface):
    front, back = center_y - depth / 2, center_y + depth / 2
    n = len(outline)
    verts = [(x, y, z) for y in (back, front) for x, z in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
    faces.extend((i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    item = bpy.data.objects.new(name, mesh)
    item.data.materials.append(surface)
    scene.collection.objects.link(item)
    return item

silhouette("Standspitze", [(-.23, .61), (0, -.44), (.23, .61)], .15, .01, dark)
silhouette("Messingeinlage", [(-.166, .61), (0, -.36), (.166, .61)], .04, -.08, brass)
disc("Kontur des Kartenzeichens", (0,0,.58), .425, .16, dark)
disc("Messingring", (0,-.093,.58), .377, .048, brass)
disc("Emailfläche", (0,-.127,.58), .306, .036, enamel)
silhouette("Kompassrose", [(0,.83), (-.058,.64), (-.204,.58), (-.058,.525), (0,.33),
                            (.058,.525), (.204,.58), (.058,.64)], .035, -.158, ivory)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(out / "atlas_pin.glb"), export_format="GLB", use_selection=True)
focus = Vector((0, 0, .31))
for name, xyz, power, width in [("Schlüssellicht",(2.5,-4,5),450,4), ("Aufhellung",(-3,-2,1),145,3)]:
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.size = power, width
    lamp = bpy.data.objects.new(name, data)
    scene.collection.objects.link(lamp)
    lamp.location = xyz
    lamp.rotation_euler = (focus - lamp.location).to_track_quat("-Z","Y").to_euler()
camera = bpy.data.objects.new("Kamera", bpy.data.cameras.new("Atlaspin"))
scene.collection.objects.link(camera)
camera.data.type = "ORTHO"
camera.data.ortho_scale = 1.7
camera.location = (0.63, -5.7, 1.55)
camera.rotation_euler = (focus - camera.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = camera
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 16
scene.render.threads_mode = "FIXED"
scene.render.threads = 4
scene.render.resolution_x = scene.render.resolution_y = 96
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.color_mode = "RGBA"
scene.render.filepath = str(out / "atlas_pin.png")
bpy.ops.render.render(write_still=True)
