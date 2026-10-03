"""One-time original miniature-world dressing; preserves gameplay tiers and robots."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[5]
SOURCE=ROOT/'tools/blender_source/maps/garden_circuit/GardenCircuit.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
BUILD_STAGE=0
exec(compile((Path(__file__).parent/'build_garden_circuit.py').read_text(),'build_garden_circuit.py','exec'))
s=scene();bpy.context.window.scene=s
if s.get('miniature_world_scale'):raise RuntimeError('Already enlarged; do not apply twice.')
def stretch(o,anchor,factors):
    a=Vector(anchor);o.matrix_world=Matrix.Translation(a) @ Matrix.Diagonal((*factors,1)) @ Matrix.Translation(-a) @ o.matrix_world
# Parented original furniture retains its editable parts.
for o in list(s.objects):
    if o.parent is None and 'human bench' in o.name:o.scale*=3
for side in [-1,1]:
    team='CYAN' if side==-1 else 'AMBER'
    asset('CampusBench',team+' monumental spawn bench',(-side*5.7,side*18.4,0),.3913*3,0 if side==1 else math.pi)
    x,y=-side*8,side*20
    cyl(team+' human cafe table top',(x,y,2.25),1.55,.16,'Porcelain','Props',64)
    cyl(team+' cafe table pedestal',(x,y,1.08),.24,2.16,'Graphite','Props',32)
    cyl(team+' cafe table foot',(x,y,.08),.70,.16,'Graphite','Props',48)
    # Original cup, with hollow rim and handle, gives a familiar human-scale reference.
    cyl(team+' giant cup',(x+.3,y,2.61),.25,.56,'Mint','Props',40)
    cyl(team+' cup coffee',(x+.3,y,2.895),.215,.014,'Soil','Props',40)
    bpy.ops.mesh.primitive_torus_add(major_radius=.18,minor_radius=.045,major_segments=24,minor_segments=8,location=(x+.61,y,2.65),rotation=(math.pi/2,0,0))
    finish(bpy.context.object,team+' cup handle','Props','Mint')
# Door proportions enlarge independently of wall height.
for o in list(coll('Architecture').objects):
    if 'Human service door' in o.name:stretch(o,(o.location.x,o.location.y,0),(3,1,3))
    elif 'Human door handle' in o.name:
        o.location.x+=.76;stretch(o,(o.location.x,o.location.y,0),(3,1,3))
    elif any(v in o.name for v in ['campus boundary','articulated pier','energy inset','campus facade','Pavilion structural post']):stretch(o,(0,0,0),(1,1,1.8))
for o in list(coll('Roof canopies • hide for tactical review').objects):stretch(o,(0,0,0),(1,1,1.8))
# Assign botanical parts to the nearest original basin before modifying any geometry.
plants=list(coll('Planting').objects)
basins=[o for o in plants if 'ceramic basin' in o.name]
anchors={o:(o.location.x,o.location.y,min((o.matrix_world@Vector(c)).z for c in o.bound_box)) for o in basins}
assign={o:min(basins,key=lambda b:(o.location.x-b.location.x)**2+(o.location.y-b.location.y)**2) for o in plants if not o.name.startswith('Distant orchard')}
for o,b in assign.items():
    stretch(o,anchors[b],(1.10,1.10,2.1))
    if 'orchard tree' in o.name:stretch(o,anchors[b],(1.7,1.7,1))
# Distant trees grouped by their closest trunk.
distant=[o for o in plants if o.name.startswith('Distant orchard')]
trunks=[o for o in distant if 'trunk' in o.name]
for o in distant:
    t=min(trunks,key=lambda t:(t.location.x-o.location.x)**2+(t.location.y-o.location.y)**2)
    stretch(o,(t.location.x,t.location.y,-.45),(1.8,1.8,2.1))
centers=[(-20,12),(20,-12),(-21,-17),(21,17),(0,28),(0,-28)]
for o in list(coll('Skyline').objects):
    if o.name.startswith('Campus surrounding terrace'):stretch(o,(0,0,-.45),(68/49,82/62,1));continue
    x,y=min(centers,key=lambda p:(o.location.x-p[0])**2+(o.location.y-p[1])**2)
    stretch(o,(x,y,0),(2.1,2.1,2.1))
    if x:o.location.x+=math.copysign(4,x)
# Original white garden arches: large human architecture, beyond the ground routes.
for side in [-1,1]:
    y=side*17;verts=[];faces=[];n=96
    for i in range(n+1):
        a=math.pi*i/n
        for depth,r in [(-.3,15),(-.3,14.4),(.3,15),(.3,14.4)]:verts.append((r*math.cos(a),y+depth,4.5+r*math.sin(a)))
    for i in range(n):
        a=4*i;b=a+4
        faces.extend([(a,b,b+1,a+1),(a+2,a+3,b+3,b+2),(a,a+2,b+2,b),(a+1,b+1,b+3,a+3)])
    faces.extend([(0,1,3,2),(4*n,4*n+2,4*n+3,4*n+1)])
    mesh('Monumental garden arch',verts,faces,'Porcelain','Roof canopies • hide for tactical review')
    for x in [-14.7,14.7]:box('Garden arch column',(x,y,2.25),(.6,.6,4.5),'Porcelain','Architecture',.09)
for name,loc,target in [('01',(40,-52,39),(0,0,4)),('03',(-7.8,3.6,.50),(-4.65,5.67,1.2)),('05',(1.15,-19.25,.53),(5.7,-18.4,1.4))]:
    cam=next(o for o in s.objects if o.type=='CAMERA' and o.name.startswith(name+' •'));cam.location=loc;cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
s['miniature_world_scale']=True;s['bench_scale_multiplier']=3.0;s['robot_reference_height_m']=.55
s['human_bench_seat_m']=1.35;s['human_door_height_m']=6.6
for note in bpy.data.texts:
    if 'APPLE LEGENDS / A1 GARDEN CIRCUIT' in note.as_string():
        note.clear();note.write((SOURCE.parent/'Review_Notes.md').read_text())
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
print('Miniature world saved; robots, routes and movement unchanged.')
