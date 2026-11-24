"""Original Banger Queens atlas miniatures, Blender 5.2 background generator."""
from pathlib import Path
import math
import sys
import bpy
from mathutils import Vector

OUT = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def material(name, color, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = 0.67
    return mat

stone = material("Kalkstein", (.55, .49, .37))
shadow = material("Dunkler Schiefer", (.16, .19, .21))
wood = material("Räuchereiche", (.28, .13, .055))
copper = material("Kupfer", (.59, .31, .13), .17)
gold = material("Messing", (.86, .54, .18), .26)
teal = material("Glasiertes Blaugrün", (.10, .37, .34))
red = material("Krapprot", (.58, .12, .085))
linen = material("Leinen", (.79, .69, .45))
forest = material("Tanne", (.15, .31, .20))
snow = material("Kalk und Schnee", (.76, .82, .80))

def finish(name, mat):
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj

def box(name, pos, size, mat, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = finish(name, mat)
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Kanten", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        obj.modifiers.new("Flächennormalen", "WEIGHTED_NORMAL")
    return obj

def cone(name, pos, radius, height, mat, sides=8, top=0):
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, radius2=top,
                                   depth=height, location=pos)
    return finish(name, mat)

def beam(name, a, b, width, mat):
    delta = Vector(b) - Vector(a)
    obj = box(name, (Vector(a)+Vector(b))/2, (width, width, delta.length), mat, 0)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return obj

def wheel(name, pos, radius, mat):
    obj = cone(name, pos, radius, .10, mat, 12, radius)
    obj.rotation_euler.y = math.pi/2
    return obj

def base(mat=shadow):
    cone("Sockel", (0,0,.09), 1.08, .18, mat, 8, 1.03)
    cone("Fassung", (0,0,.19), 1.0, .06, copper, 8, 1.0)

def keep():
    base()
    box("Saal", (0,.1,.60),(1.13,.82,.76),stone)
    box("Portal", (0,-.324,.44),(.28,.05,.42),wood)
    cone("Satteldach", (0,.10,1.08),.76,.39,teal,4).rotation_euler.z=math.pi/4
    for x,y in [(-.65,-.24),(.65,-.24),(.60,.43)]:
        cone("Turm", (x,y,.64),.23,.87,stone,8,.20)
        cone("Turmdach", (x,y,1.19),.26,.38,teal)
        box("Schießscharte", (x,y-.21,.76),(.052,.04,.16),shadow,0)
    beam("Standarte",(-.46,.36,1.05),(-.46,.36,1.85),.045,gold)
    box("Wimpel",(-.25,.36,1.67),(.39,.045,.25),teal)

def ridge():
    base()
    for x,y,h,r in [(-.37,.10,1.27,.52),(.25,.29,1.57,.58),(.45,-.23,.82,.39)]:
        cone("Grat",(x,y,.21+h/2),r,h,shadow,5,.035)
        cone("Helle Gipfelkante",(x,y,.21+h*.87),r*.29,h*.26,snow,5,.035)
    for x,y,k in [(-.52,-.51,1),(-.17,-.68,.75),(.26,-.57,.9),(.67,.16,.75)]:
        cone("Stamm",(x,y,.34),.053,.26,wood,5,.05)
        cone("Tanne unten",(x,y,.49),.21*k,.38*k,forest,6)
        cone("Tanne oben",(x,y,.66),.16*k,.36*k,teal,6)

def crown():
    base()
    cone("Steinpostament",(0,0,.40),.68,.41,stone,8,.57)
    cone("Kronenreif",(0,0,.68),.65,.24,gold,12,.69)
    for i in range(8):
        theta = i * math.tau / 8
        x,y = .65*math.cos(theta),.65*math.sin(theta)
        cone("Kronenzacke",(x,y,.91),.135,.36,gold,4,.018)
        cone("Edelstein",(x,y,.73),.075,.17,red if i%2==0 else teal,4,.013)
    cone("Insignie",(0,0,1.07),.25,.58,copper,6,.09)
    cone("Spitze",(0,0,1.42),.14,.25,gold,4)

def market():
    base()
    for x in (-.4,.4):
        for y in (-.43,.40):
            box("Pfosten",(x,y,.68),(.08,.08,.94),wood)
    box("Markttisch",(0,-.23,.52),(1.04,.58,.17),wood)
    for index in range(7):
        x = -.57 + index*.19
        bar = box("Markise",(x,-.03,1.18),(.187,1.14,.065),linen if index%2==0 else teal,.01)
        bar.rotation_euler.x = -.19
        box("Volant",(x,-.58,1.04),(.182,.045,.18),linen if index%2==0 else teal,.008)
    for x,y in [(-.57,-.61),(.57,-.58),(.54,.20)]:
        cone("Handelsfass",(x,y,.36),.16,.27,wood,8,.145)
        cone("Fassreif",(x,y,.42),.166,.045,gold,8,.164)
    for x in (-.28,0,.29):
        cone("Ware",(x,-.28,.65),.12,.17,copper,7,.075)

def siege():
    base()
    box("Turmrahmen", (0,.06,.74),(.95,.84,1.05),wood)
    for x in (-.435,.435):
        for y in (-.32,.44):
            box("Verstärkung",(x,y,.83),(.105,.10,1.30),copper)
    for z in (.53,.84,1.17):
        box("Eisenband",(0,-.37,z),(.99,.09,.07),shadow,0)
    for x in (-.53,.53):
        for y in (-.30,.42):
            wheel("Rad",(x,y,.37),.23,shadow)
            wheel("Nabe",(x*1.11,y,.37),.074,gold)
    roof = box("Wetterschutz",(0,.07,1.40),(1.05,.92,.12),red)
    roof.rotation_euler.x = .1
    bridge = box("Fallbrücke",(0,-.68,1.08),(.68,.64,.075),wood)
    bridge.rotation_euler.x = .27
    for x in (-.31,.31):
        beam("Zugstange",(x,-.37,1.39),(x,-.94,1.03),.035,gold)
    beam("Fahnenmast",(.22,.12,1.39),(.22,.12,1.84),.045,wood)
    box("Feldzeichen",(.43,.12,1.70),(.42,.04,.21),red)

world = bpy.data.worlds.new("Atelier")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (.43,.52,.62,1)
world.node_tree.nodes["Background"].inputs[1].default_value = .43

def area(name, pos, power, color, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.shape, data.size = power, color, "DISK", size
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = pos
    obj.rotation_euler = (Vector((0,0,.72))-obj.location).to_track_quat("-Z","Y").to_euler()

area("Warmes Hauptlicht", (3,-4,6), 460,(1,.82,.62),4.5)
area("Kühles Kantenlicht", (-3,3,4), 300,(.67,.81,1),3.5)
cam = bpy.data.objects.new("Atlas-Kamera", bpy.data.cameras.new("Atlas-Kamera"))
scene.collection.objects.link(cam)
cam.location = (3.2,-4.8,3.7)
cam.rotation_euler = (Vector((0,0,.79))-cam.location).to_track_quat("-Z","Y").to_euler()
cam.data.type = "ORTHO"
cam.data.ortho_scale = 2.64
scene.camera = cam
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.render.threads_mode = "FIXED"
scene.render.threads = 4
scene.render.resolution_x = scene.render.resolution_y = 160
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"

previous = []
for key, builder in [("political",keep),("terrain",ridge),("titles",crown),
                     ("economy",market),("war",siege)]:
    for obj in previous:
        obj.hide_render = True
        obj.hide_set(True)
    before = set(bpy.data.objects)
    builder()
    current = [obj for obj in bpy.data.objects if obj not in before]
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    for obj in current:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = current[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{key}.glb"), export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True)
    scene.render.filepath = str(OUT / f"{key}.png")
    bpy.ops.render.render(write_still=True)
    previous = current
    print("ATLAS_MODEL", key, len(current), flush=True)
