"""Create Banger Queens' original carved undertaking marker."""
from pathlib import Path
import sys

import bpy
from mathutils import Vector

out=Path(sys.argv[sys.argv.index("--")+1]).resolve()
out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene


def material(name, rgb, roughness=.72, metallic=0):
    mat=bpy.data.materials.new(name)
    mat.diffuse_color=(*rgb,1)
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value=(*rgb,1)
    bsdf.inputs["Roughness"].default_value=roughness
    bsdf.inputs["Metallic"].default_value=metallic
    return mat


lime=material("Heller Kalkstein",(.57,.48,.29))
terracotta=material("Dunkler Sockel",(.24,.16,.085))
gold=material("Messing und Gold",(.95,.60,.13),.43,.55)
pigment=material("Keramik aus tiefblauem Pigment",(.035,.27,.37),.42)
maple=material("Geräucherter Ahorn",(.29,.11,.04))


def facet(name, xyz, size, surface, radius=.04):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz)
    item=bpy.context.object
    item.name=name
    item.dimensions=size
    item.data.materials.append(surface)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel=item.modifiers.new("Kanten","BEVEL")
    bevel.width=radius
    bevel.segments=1
    item.modifiers.new("Flächennormalen","WEIGHTED_NORMAL")
    return item


facet("Steinsockel",(0,0,.11),(1.10,.72,.20),terracotta)
facet("Sandsteinstufe",(0,0,.25),(.89,.59,.13),lime)
facet("Urkundenpfeiler",(0,0,.75),(.67,.44,.94),lime,.075)
facet("Gerahmte Einlassplatte",(0,-.232,.83),(.56,.077,.63),gold,.045)
facet("Blauer Stempelgrund",(0,-.275,.83),(.45,.044,.52),pigment,.048)
emblem=facet("Raute des Rats",(0,-.305,.87),(.24,.036,.24),gold,.025)
emblem.rotation_euler.y=.785398
facet("Schriftzeichen",(0,-.305,.66),(.235,.035,.058),gold,.014)
facet("Abschlussgesims",(0,0,1.26),(.79,.56,.14),maple,.047)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=.087,location=(0,0,1.39))
bpy.context.object.name="Messingkugel"
bpy.context.object.data.materials.append(gold)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(out/"undertaking_marker.glb"),
                         export_format="GLB",use_selection=True,export_apply=True)
focus=Vector((0,0,.72))
for name,position,power,width in [("Sonne",(3,-4,6),570,4),("Reflexion",(-3,-2,2),260,3)]:
    source=bpy.data.lights.new(name,"AREA")
    source.energy,source.size=power,width
    lamp=bpy.data.objects.new(name,source)
    scene.collection.objects.link(lamp)
    lamp.location=position
    lamp.rotation_euler=(focus-lamp.location).to_track_quat("-Z","Y").to_euler()

camera=bpy.data.objects.new("Karte",bpy.data.cameras.new("Karte"))
scene.collection.objects.link(camera)
camera.data.type="ORTHO"
camera.data.ortho_scale=1.96
camera.location=(1.75,-6,3.2)
camera.rotation_euler=(focus-camera.location).to_track_quat("-Z","Y").to_euler()
scene.camera=camera
scene.render.engine="CYCLES"
scene.cycles.device="CPU"
scene.cycles.samples=12
scene.cycles.use_denoising=True
scene.render.threads_mode="FIXED"
scene.render.threads=4
scene.render.resolution_x=scene.render.resolution_y=128
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.color_mode="RGBA"
scene.render.filepath=str(out/"undertaking_marker.png")
bpy.ops.render.render(write_still=True)
