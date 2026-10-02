"""Original Apple Legends calibration assets. Run inside Blender (live or background).

Blender Z-up; front points -Y, exported by glTF as Godot +Z.
Run from a fresh factory-startup Blender process for stable asset names.
Creates a separate scene, preserving existing scenes and objects.
"""
import bpy
import math
from pathlib import Path
from mathutils import Quaternion, Vector

OUT = Path('/Users/samjo/Apple Legends/art/calibration')
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.new('Apple Legends — Asset Workshop')
bpy.context.window.scene = scene
roots = []

def material(name, color, rough=.4, metal=0, emission=0):
    m = bpy.data.materials.new('AL_' + name)
    n = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    n.inputs['Base Color'].default_value = (*color, 1)
    n.inputs['Roughness'].default_value = rough
    n.inputs['Metallic'].default_value = metal
    n.inputs['Emission Color'].default_value = (*color, 1)
    n.inputs['Emission Strength'].default_value = emission
    m.diffuse_color = (*color, 1)
    return m

white = material('Ceramic', (.86,.89,.94), .3)
dark = material('Graphite', (.024,.034,.049), .48)
glass = material('Visor', (.004,.009,.017), .16, .25)
metal = material('Aluminum', (.34,.42,.5), .3, .7)
blue = material('Cyan', (.015,.48,.92), .24, .1, 2)
orange = material('Amber', (1,.23,.025), .3, .1, 1.6)
green = material('Leaves', (.09,.3,.15), .8)
leaf_light = material('LeavesLight', (.23,.45,.16), .8)
soil = material('Soil', (.06,.055,.045), 1)

def root(name):
    o = bpy.data.objects.new(name, None)
    scene.collection.objects.link(o)
    roots.append(o)
    return o

def finish(o, name, parent, loc, mat):
    o.name = name
    o.parent = parent
    o.location = loc
    o.data.materials.append(mat)
    for polygon in o.data.polygons: polygon.use_smooth = True
    return o

def box(name, parent, loc, size, mat, bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new('Soft product edges', 'BEVEL')
        mod.width = min(bevel, min(size)*.45)
        mod.segments = 3
        norm = o.modifiers.new('Surface normals', 'WEIGHTED_NORMAL')
        norm.keep_sharp = True
    return finish(o,name,parent,loc,mat)

def ellipsoid(name,parent,loc,size,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1)
    o = bpy.context.object
    o.scale = size
    for p in o.data.polygons: p.use_smooth=True
    return finish(o,name,parent,loc,mat)

def cylinder(name,parent,loc,radius,depth,mat,axis=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=depth)
    o=bpy.context.object
    if axis: o.rotation_euler=axis
    mod=o.modifiers.new('Edge radius','BEVEL'); mod.width=min(.025,radius*.15); mod.segments=3
    o.modifiers.new('Surface normals','WEIGHTED_NORMAL')
    return finish(o,name,parent,loc,mat)

bot=root('MiniBot')
ellipsoid('Helmet',bot,(0,0,1.34),(.46,.36,.43),white)
ellipsoid('FaceGlass',bot,(0,-.275,1.34),(.365,.135,.29),glass)
for x in [-.14,.14]: ellipsoid('Eye',bot,(x,-.399,1.35),(.053,.022,.069),orange)
for x in [-.445,.445]:
    cylinder('EarHousing',bot,(x,0,1.34),.15,.07,metal,(0,math.pi/2,0))
    cylinder('EarCap',bot,(x*1.055,0,1.34),.115,.045,white,(0,math.pi/2,0))
box('TorsoCore',bot,(0,0,.76),(.47,.31,.43),dark,.09)
box('ChestShell',bot,(0,-.12,.81),(.5,.19,.35),white,.09)
box('ChestIndicator',bot,(0,-.221,.82),(.14,.017,.037),orange,.012)
for side in [-1,1]:
    ellipsoid('Shoulder',bot,(side*.32,0,.91),(.14,.14,.16),white)
    box('Forearm',bot,(side*.34,-.2,.68),(.18,.23,.2),white,.07)
    ellipsoid('Hand',bot,(side*.32,-.35,.63),(.105,.09,.09),dark)
    cylinder('HipJoint',bot,(side*.15,0,.5),.1,.17,dark)
    box('Shin',bot,(side*.16,0,.33),(.2,.21,.24),white,.07)
    box('BootSole',bot,(side*.18,-.055,.095),(.25,.34,.12),dark,.04)
    box('Boot',bot,(side*.18,-.06,.18),(.24,.33,.17),white,.06)
box('Backpack',bot,(0,.19,.79),(.32,.19,.32),metal,.06)
box('BotWeapon',bot,(.05,-.4,.72),(.53,.23,.21),white,.06)
box('BotWeaponSpine',bot,(.05,-.49,.73),(.46,.075,.10),dark,.02)
box('BotWeaponPower',bot,(.05,-.534,.74),(.25,.02,.04),orange,.01)

rifle=root('PulseRifle')
box('MechanicalSpine',rifle,(0,-.18,0),(.18,.65,.16),dark,.03)
box('UpperShell',rifle,(0,-.17,.06),(.21,.58,.13),white,.045)
box('RearShell',rifle,(0,.21,-.02),(.18,.26,.18),white,.055)
box('SideInset',rifle,(.108,-.19,0),(.016,.39,.075),dark,.008)
box('PowerWindow',rifle,(.12,-.19,.005),(.013,.30,.032),blue,.008)
box('OppositeWindow',rifle,(-.115,-.19,.005),(.013,.30,.032),blue,.008)
for y in [-.07,-.14,-.21,-.28]: box('ChargeCell',rifle,(.132,y,.01),(.01,.012,.042),white,.003)
cylinder('FrontHousing',rifle,(0,-.55,0),.115,.23,white,(math.pi/2,0,0))
cylinder('MuzzleInsert',rifle,(0,-.677,0),.087,.027,dark,(math.pi/2,0,0))
cylinder('MuzzleEnergy',rifle,(0,-.693,0),.058,.012,blue,(math.pi/2,0,0))
cylinder('Bore',rifle,(0,-.701,0),.04,.015,glass,(math.pi/2,0,0))
box('Grip',rifle,(0,.07,-.15),(.12,.13,.25),dark,.035)
box('PowerCartridge',rifle,(0,-.16,-.17),(.12,.17,.21),white,.03)
box('CartridgeStripe',rifle,(.064,-.16,-.17),(.012,.11,.045),blue,.007)
box('SightBase',rifle,(0,-.04,.149),(.12,.19,.042),dark,.018)
for x in [-.045,.045]: box('SightFrame',rifle,(x,-.04,.20),(.02,.14,.085),white,.008)
box('SightTop',rifle,(0,-.04,.24),(.10,.14,.018),white,.007)
box('SightDot',rifle,(0,-.111,.182),(.012,.012,.012),blue,.004)
box('FrontPost',rifle,(0,-.56,.16),(.025,.026,.075),dark,.008)
for side,y in [(1,.06),(-1,-.36)]:
    ellipsoid('Palm',rifle,(side*.09,y,-.16),(.085,.1,.095),dark)
    box('HandShell',rifle,(side*.11,y,-.15),(.13,.13,.12),white,.04)
    for dy in [-.045,0,.045]: box('Finger',rifle,(side*.055,y+dy,-.13),(.07,.028,.075),dark,.012)
    arm=box('ForearmShell',rifle,(side*.21,y+.18,-.23),(.16,.36,.16),white,.065)
    arm.rotation_euler.z=side*-.4
    box('WristSeal',rifle,(side*.13,y+.10,-.19),(.14,.065,.14),dark,.025)

crate=root('CargoPod')
box('CargoBody',crate,(0,0,.7),(1.2,1.1,1.4),white,.12)
box('CargoPanel',crate,(0,-.559,.7),(.91,.05,1.03),dark,.08)
box('CargoInset',crate,(0,-.59,.7),(.77,.015,.9),metal,.06)
for x in [-.5,.5]: box('CargoStrip',crate,(x,-.577,.7),(.035,.025,.94),orange,.012)
box('CargoHandle',crate,(0,-.625,1.01),(.24,.04,.07),dark,.022)

charger=root('ChargeColumn')
box('Base',charger,(0,0,.13),(1.0,.85,.26),dark,.09)
box('Housing',charger,(0,0,1.35),(.86,.66,2.5),white,.15)
box('BlackInset',charger,(0,-.34,1.37),(.48,.025,1.88),dark,.07)
box('EnergyCore',charger,(0,-.359,1.38),(.13,.025,1.48),blue,.04)
for z in [.63,2.16]: box('CoreSocket',charger,(0,-.38,z),(.32,.06,.13),metal,.035)
box('Status',charger,(0,-.36,2.48),(.26,.025,.04),orange,.01)

bench=root('CampusBench')
box('Seat',bench,(0,0,1.15),(3.8,1.0,.27),white,.12)
box('SeatUnderlay',bench,(0,0,.99),(3.6,.87,.13),dark,.06)
for x in [-1.25,1.25]: box('Support',bench,(x,0,.5),(.3,.7,1.0),metal,.06)
box('Back',bench,(0,.39,1.62),(3.8,.24,.91),white,.11)

planter=root('GardenPlanter')
box('PlanterShell',planter,(0,0,.73),(3.2,1.8,1.46),white,.18)
box('SoilInset',planter,(0,0,1.45),(2.91,1.5,.06),soil,.12)
for i in range(12):
    x=math.sin(i*2.4)*1.12; y=math.cos(i*2.4)*.5
    ellipsoid('Foliage',planter,(x,y,1.64+(i%3)*.1),(.42,.37,.34),green if i%2 else leaf_light)
box('PlanterStripe',planter,(0,-.907,.38),(2.65,.025,.035),metal,.012)

wall=root('ShellWall')
box('Wall',wall,(0,0,2),(6,.55,4),white,.18)
box('Skirting',wall,(0,-.29,.34),(5.8,.04,.24),dark,.045)
box('LightStrip',wall,(0,-.315,.50),(5.3,.015,.045),blue,.01)

# Export each asset independently; collections and Blender source remain editable.
for r in roots:
    for o in bpy.data.objects: o.select_set(False)
    r.select_set(True)
    for child in r.children_recursive: child.select_set(True)
    bpy.context.view_layer.objects.active=r
    bpy.ops.export_scene.gltf(filepath=str(OUT/(r.name+'.glb')), use_selection=True, use_active_scene=True,
                              export_apply=True, export_animations=False)

# Arrange only after exporting so Godot assets retain an origin at floor level.
for i,r in enumerate(roots): r.location=(i*4,0,0)
rifle.location=(4,0,1.0)
bpy.ops.object.select_all(action='DESELECT')
bot.select_set(True)
bpy.context.view_layer.objects.active=bot
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=7
        area.spaces.active.region_3d.view_location=(1,0,.9)
        area.spaces.active.region_3d.view_rotation=Quaternion((.85,.42,.12,.26)).normalized()
source = OUT.parents[1] / 'tools' / 'blender_source'
source.mkdir(exist_ok=True)
(source / '.gdignore').touch()
bpy.ops.wm.save_as_mainfile(filepath=str(source/'calibration_assets.blend'))
print('Exported',len(roots),'original calibration assets to',OUT)
