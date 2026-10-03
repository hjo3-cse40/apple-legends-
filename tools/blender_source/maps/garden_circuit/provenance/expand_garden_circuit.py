"""One-time expansion of the accepted arena. Run before export_runtime_map.py."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[5]
SOURCE=ROOT/'tools/blender_source/maps/garden_circuit/GardenCircuit.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
BUILD_STAGE=0
exec(compile((Path(__file__).parent/'build_garden_circuit.py').read_text(),'build_garden_circuit.py','exec'))
s=scene();bpy.context.window.scene=s
base_coll=coll
def coll(name):
    return bpy.data.collections['03 GAMEPLAY • Spawns, Point, Pickups'] if name=='Gameplay markers' else base_coll(name)
if s.get('expanded_koth'):raise RuntimeError('Arena already expanded; do not apply twice.')
# Keep the original individually editable furniture, plants, objective and protected docks.
# Translate prop roots, never stretch the tiny robots or human furniture.
for category in ['Props','Planting','Spawn docks','Gameplay markers','Robot scale reference','Signage']:
    for o in list(coll(category).objects):
        if o.parent is not None:continue
        if o.get('role') in ['capture_zone','objective','scale_reference']:continue
        o.location.x*=1.55;o.location.y*=1.80
for o in s.objects:
    if o.parent is None and o.name.startswith('55 cm robot reference'):
        o.location.x*=1.55;o.location.y*=1.80
# Replace compact courtyard infrastructure with purpose-built wider route geometry.
for category in ['Architecture','Ground','Traversal','Skyline','Roof canopies • hide for tactical review','Collision proxies']:
    for o in list(coll(category).objects):bpy.data.objects.remove(o,do_unlink=True)
box('Courtyard foundation',(0,0,-.30),(32.5,44.5,.48),'Graphite','Ground',.20)
box('Garden court continuous walk surface',(0,0,-.115),(32,44,.18),'Paving','Ground',.04)
for x in range(-15,16,2):
    for y in range(-21,22,2):box('Campus paving • 2 m module',(x,y,.008),(1.965,1.965,.014),'Paving','Ground',.012)
for side in [-1,1]:
    accent='Cyan' if side==-1 else 'Amber';team='CYAN' if side==-1 else 'AMBER'
    # Tall courtyard rim retains open sky above the new playable tiers.
    box('Human campus boundary',(side*16,0,3.1),(.30,44,6.2),'Porcelain','Architecture',.10)
    box('Boundary charcoal sill',(side*15.82,0,.15),(.07,43.5,.24),'Graphite','Architecture',.025)
    for y in range(-18,19,6):
        box('Boundary articulated pier',(side*15.8,y,3.1),(.40,.4,6.3),'Warm shell','Architecture',.07)
        box('Boundary energy inset',(side*15.57,y,3.8),(.02,.055,2.3),accent,'Architecture',.006)
    box('Spawn campus facade',(0,side*22,2.8),(32,.36,5.6),'Porcelain','Architecture',.12)
    box('Facade canopy',(0,side*21,4.25),(15,2,.22),'Porcelain','Roof canopies • hide for tactical review',.08)
    for x in [-12,12]:
        box('Human service door',(x,side*21.8,1.1),(1.2,.08,2.2),'Graphite','Architecture',.06)
        box('Human door handle',(x+.38,side*21.74,1.05),(.035,.04,.28),'Porcelain','Architecture',.01)
    # First level: long galleries, two ground ramps each, open underpasses.
    x=side*9.5
    box('Garden gallery • walkable deck',(x,0,1.55),(4,14,.20),'Pale paving','Traversal',.045)
    box('Gallery dark underside',(x,0,1.40),(3.95,13.9,.10),'Graphite','Traversal',.025)
    for end in [-1,1]:
        ramp('Gallery access ramp',x,end*15,end*7,3,1.65)
        for y in [end*3.8,end*6.6]:box('Gallery structural foot',(side*10.6,y,.65),(.30,.30,1.3),'Porcelain','Traversal',.05)
        # Upper level ramps run outward from each end of the gallery.
        # Rotate the existing closed wedge helper so every face remains correctly wound.
        o=ramp('Upper terrace access ramp',0,0,3.5,2.2,1.675)
        pieces=[o]+[p for p in coll('Traversal').objects if p.name.startswith('Upper terrace access ramp • edge guidance')]
        angle=-side*math.pi/2
        o.location=(side*9.5,end*5.7,1.625)
        o.rotation_euler.z=angle
        # Explicitly place strips after the rotated wedge; remove originals for clarity.
        for p in pieces[1:]:bpy.data.objects.remove(p,do_unlink=True)
        for dy in [-1.01,1.01]:
            strip=box('Upper ramp • mint edge',(side*11.25,end*5.7+dy,2.48),(3.5,.035,.016),'Mint','Traversal',.005)
            strip.rotation_euler.y=-side*math.atan(1.65/3.5)
        marker(team+'_UPPER_RAMP_'+str(end),(side*11.25,end*5.7,2.46),'walkable_ramp')
    # Second level: side terraces, exposed edges for jump/drop shortcuts.
    box('Upper orchard terrace • walkable deck',(side*14.5,0,3.20),(3,14,.20),'Pale paving','Traversal',.05)
    box('Upper terrace • graphite reveal',(side*14.5,0,3.05),(2.95,13.9,.10),'Graphite','Traversal',.025)
    for y in [-4,0,4]:box('Upper terrace structural foot',(side*15.2,y,1.45),(.35,.35,2.9),'Porcelain','Traversal',.06)
    for y in [-2.8,2.8]:
        box('Upper terrace sight screen',(side*13.15,y,3.98),(.22,2.1,1.36),'Porcelain','Traversal',.07)
        box('Upper screen graphite inset',(side*13.02,y,4.0),(.025,1.7,.94),'Graphite','Traversal',.02)
        box('Upper screen status line',(side*13.0,y,4.0),(.016,.035,.75),accent,'Traversal',.005)
    for y in [-4.5,0,4.5]:box('Gallery interrupted guard',(side*7.6,y,1.9),(.18,1.25,.5),'Porcelain','Traversal',.055)
    marker(team+'_GALLERY',(x,0,1.65),'walkable_gallery',{'floor_z_m':1.65})
    marker(team+'_UPPER_TERRACE',(side*14.5,0,3.3),'walkable_gallery',{'floor_z_m':3.3})
    # Midfield islands break long sightlines without sealing any route.
    for x,y in [(side*4.6,side*12.3),(-side*5.5,side*9.5)]:
        planter(team+' midfield island',(x,y),(2.4,1.1,.85),trees=True)
    box(team+' approach • tall sight break',(side*2.8,side*12.4,1.30),(1.5,.65,2.6),'Porcelain','Props',.12)
    box(team+' approach • graphite face',(side*2.8,side*12.04,1.35),(1.16,.035,1.8),'Graphite','Props',.055)
    box(team+' approach • status light',(side*2.8,side*12.015,1.35),(.045,.014,1.25),accent,'Props',.005)
    # Shaded staging pavilions sit away from spawn exits and the climbing routes.
    box('Staging pavilion canopy',(-side*4.7,side*16,4.0),(5.5,4,.22),'Porcelain','Roof canopies • hide for tactical review',.09)
    for dx in [-2.4,2.4]:box('Pavilion structural post',(-side*4.7+dx,side*17.6,1.9),(.28,.28,3.8),'Porcelain','Architecture',.06)
    for y in [side*17.7,side*14.5,side*10.7,side*7.2,side*3.0]:
        for x in [-1.4,1.4]:box(team+' guidance dash',(x,y,.028),(.035,.70,.014),accent,'Ground',.005)
    text(team+' gallery label','01 / GALLERY',(side*9.5,-side*6,1.68),.24,'Ink',(0,0,0))
    text(team+' terrace label','02 / ORCHARD',(side*14.5,0,3.32),.23,'Ink',(0,0,0))
# Orchard pockets sit against the wall, leaving a clear upper walking lane.
for side in [-1,1]:
    for y in [-2.8,2.8]:
        before=set(coll('Planting').objects)
        planter('Upper orchard pocket',(side*15.25,y),(.9,1.3,.42),trees=True)
        for o in set(coll('Planting').objects)-before:o.location.z+=3.30
for name,outer,inner,z0,z1,material in [('Hill walk-in apron',2.5,2.05,.015,.060,'Porcelain'),('Hill inlay approach',2.05,1.87,.060,.073,'Porcelain'),('Hill inner approach',1.87,1.76,.073,.085,'Graphite')]:
 verts=[];faces=[];n=128
 for i in range(n):
  a=i*math.tau/n
  verts.extend([(math.cos(a)*outer,math.sin(a)*outer,z0),(math.cos(a)*inner,math.sin(a)*inner,z1)])
 for i in range(n):faces.append((2*i,2*((i+1)%n),2*((i+1)%n)+1,2*i+1))
 o=mesh(name,verts,faces,material,'Objective');o['walkable']=True
# Taller spawn screens protect docks against the newly raised routes.
for o in coll('Spawn docks').objects:
    if 'fire screen' in o.name:
        o.scale.x=11/3.4;o.scale.z=2.6;o.location.z=1.95
    elif 'roof lip' in o.name:o.scale.x=11.25/3.65;o.location.z=3.93
for o in coll('Gameplay markers').objects:
    if o.get('role')=='spawn_exit':o.location.x=math.copysign(6.15,o.location.x)
# Place dock details flush against the resized screens and new facades.
for o in coll('Spawn docks').objects:
    side=-1 if 'CYAN' in o.name else 1
    if 'service port accent' in o.name:o.location.y=side*21.735
    elif 'service port' in o.name:o.location.y=side*21.78
    elif 'dock title' in o.name:o.location.y=side*21.76
    elif 'graphite recess' in o.name:o.location.y=side*15.615
    elif 'status rail' in o.name:o.location.y=side*15.596
    elif 'orchard crest' in o.name:o.location.y=math.copysign(15.588,o.location.y)
for o in coll('Gameplay markers').objects:
    if o.name.startswith('Gallery landing'):o.location.z=1.65
    elif o.name=='HUMAN_HEIGHT_REFERENCE':o.location=(-12,21.8,0)
# Reposition side-wall signs to the new wall surface.
for o in coll('Signage').objects:
    if 'sector' in o.name.lower() or 'emblem' in o.name.lower():o.location.x=math.copysign(15.78,o.location.x)
# Ground the original distant trees on the surrounding terrace.
for o in coll('Planting').objects:
    if o.name.startswith('Distant orchard canopy'):o.location.z-=4.2
# Background campus dressing is outside the new walls and preserves human scale.
for x,y,h,r in [(-20,12,11,2.3),(20,-12,11,2.3),(-21,-17,8,2),(21,17,8,2),(0,28,12,2.5),(0,-28,12,2.5)]:
    cyl('Campus tower • satin shell',(x,y,h/2),r,h,'Porcelain','Skyline',48)
    for z in [h*.35,h*.68,h]:
        cyl('Campus tower • balcony',(x,y,z),r+.35,.18,'Porcelain','Skyline',48)
        cyl('Campus tower • graphite seam',(x,y,z-.15),r+.18,.08,'Graphite','Skyline',48)
    box('Tower service face',(x,y-math.copysign(r,y),h*.52),(r,.05,h*.62),'Graphite','Skyline',.07)
box('Campus surrounding terrace',(0,0,-.55),(49,62,.2),'Warm shell','Skyline',.15)
# Update review cameras to show the larger campus and new vertical routes.
for name,loc,target in [('01',(33,-43,35),(0,0,1)),('02',(0,-6,.45),(0,0,.6)),('03',(-6.3,3.1,.45),(-4.65,5.67,.6)),('04',(9.4,-4,2.08),(0,0,.5)),('05',(1.15,-19.25,.53),(3,-15,.65)),('06',(0,0,50),(0,0,0))]:
    cam=next(o for o in s.objects if o.type=='CAMERA' and o.name.startswith(name));cam.location=loc;cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    if name=='06':cam.data.ortho_scale=68
camera('07 • Upper terrace / drop routes',(14.5,-5,3.75),(6,1,1.0),23)
s['expanded_koth']=True;s['arena_footprint_m']='32 x 44';s['playable_tiers_m']='0 / 1.65 / 3.30';s['purpose']='Playable expanded KOTH-style arena; offline test duel, objective rules deferred.'
note=bpy.data.texts['START HERE • Garden Circuit review'];note.clear();note.write('Expanded Garden Circuit: 32 x 44 m courtyard; robot and furniture scale preserved. Ground, 1.65 m galleries and 3.30 m orchard terraces. Four ground ramps and four upper ramps; open underpasses and drop shortcuts. Six protected spawn markers. Runtime export through export_runtime_map.py. KOTH/team logic and advanced bot navigation remain deferred.\n')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
print('EXPANDED: 32 x 44 m, ground / 1.65 / 3.3 m tiers; preserved miniature scale')
