"""Model the original irrigation works and render its transparent map icon."""
from pathlib import Path
import sys

import bpy
from mathutils import Vector

output=Path(sys.argv[sys.argv.index("--")+1]).resolve()
output.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene


def surface(name, color, roughness=.76, metal=0.0):
    result=bpy.data.materials.new(name)
    result.diffuse_color=(*color,1)
    result.use_nodes=True
    shader=result.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value=(*color,1)
    shader.inputs["Roughness"].default_value=roughness
    shader.inputs["Metallic"].default_value=metal
    return result


ground=surface("Feuchte Erde",(.21,.13,.055))
stone=surface("Helle Sandsteinkante",(.65,.51,.29))
shadows=surface("Dunkles Bruchsteinmauerwerk",(.31,.23,.135))
wood=surface("Lärchenholz",(.36,.145,.06))
water=surface("Tiefer Hauptkanal",(.014,.31,.43),.27,.12)
branch=surface("Heller Feldzufluss",(.035,.49,.47),.36)
reeds=surface("Schilf und Triebe",(.30,.51,.10))
leaves=surface("Helle Feldreihen",(.56,.49,.11))


def block(name, location, size, material, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    obj=bpy.context.object
    obj.name=name
    obj.dimensions=size
    obj.data.materials.append(material)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    rounding=obj.modifiers.new("Kanten", "BEVEL")
    rounding.width=bevel
    rounding.segments=1
    obj.modifiers.new("Flächennormalen", "WEIGHTED_NORMAL")
    return obj


block("Acker und Fundament",(0,0,.091),(1.94,1.56,.18),ground,.065)
block("Gerades Kanalbett",(-.47,0,.202),(.35,1.51,.035),water,.018)
for x in (-.70,-.24):
    block("Sandsteinufer",(x,0,.233),(.13,1.51,.105),stone)
for y in (-.47,.08,.56):
    block("Abzweig ins Feld",(.26,y,.198),(1.26,.108,.032),branch,.013)
    block("Einlass über der Rinne",(-.26,y,.265),(.20,.21,.093),shadows)
for y in (-.51,-.16,.20,.52):
    for x in (.01,.22,.44,.67):
        stem=block("Beetreihe",(x,y,.28),(.103,.31,.17),leaves if x>.43 else reeds,.034)
        stem.rotation_euler.z=(-.11 if y>.0 else .13)
for x in (-.68,-.26):
    block("Schleusenpfeiler",(x,-.34,.48),(.11,.11,.55),wood,.018)
block("Schleusenjoch",(-.47,-.34,.73),(.64,.12,.105),wood)
block("Senkbares Tor",(-.47,-.34,.42),(.40,.065,.29),shadows)
block("Hebel",(-.31,-.35,.81),(.36,.08,.066),stone).rotation_euler.y=.24
for x,y in [(-.81,.43),(-.79,.56),(-.84,.64),(.82,.65)]:
    block("Busch",(x,y,.30),(.16,.17,.21),reeds,.065)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(output/"irrigation_works.glb"),
                         export_format="GLB",use_selection=True,export_apply=True)
look=Vector((0,0,.23))
for name,point,watts,width in [
    ("Sonne",(2,-3,5),620,3.3),("Reflexion",(-3,2,4),430,3.8),
]:
    light=bpy.data.lights.new(name,"AREA")
    light.energy,light.size=watts,width
    obj=bpy.data.objects.new(name,light)
    scene.collection.objects.link(obj)
    obj.location=point
    obj.rotation_euler=(look-obj.location).to_track_quat("-Z","Y").to_euler()

camera=bpy.data.objects.new("Kartensymbol",bpy.data.cameras.new("Kartensymbol"))
scene.collection.objects.link(camera)
camera.data.type="ORTHO"
camera.data.ortho_scale=2.78
camera.location=(2.4,-3.7,3.9)
camera.rotation_euler=(look-camera.location).to_track_quat("-Z","Y").to_euler()
scene.camera=camera
scene.render.engine="CYCLES"
scene.cycles.device="CPU"
scene.cycles.samples=12
scene.cycles.use_denoising=True
scene.render.threads_mode="FIXED"
scene.render.threads=4
scene.render.resolution_x=scene.render.resolution_y=160
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.color_mode="RGBA"
scene.render.filepath=str(output/"irrigation_works.png")
bpy.ops.render.render(write_still=True)
