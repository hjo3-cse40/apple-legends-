"""Move upper ramps off the gallery lane and notch the matching upper landings."""
import bpy, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[5]
SOURCE=ROOT/'tools/blender_source/maps/garden_circuit/GardenCircuit.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
BUILD_STAGE=0
exec(compile((Path(__file__).parent/'build_garden_circuit.py').read_text(),'build_garden_circuit.py','exec'))
s=scene();bpy.context.window.scene=s
if s.get('clear_gallery_junctions'):raise RuntimeError('Junctions already cleared.')
for o in list(coll('Traversal').objects):
    if o.name.startswith('Upper terrace access ramp') or o.name.startswith('Upper ramp • mint edge'):
        o.location.x+=math.copysign(1.8,o.location.x)
    elif o.name.startswith('Upper orchard terrace • walkable deck') or o.name.startswith('Upper terrace • graphite reveal'):
        bpy.data.objects.remove(o,do_unlink=True)
# 0.2 m overlap joins gallery to ramp; the 3.5 m run retains its accepted slope.
# The high deck no longer blocks a ramp that now ends at x +/-14.8 m.
for side in [-1,1]:
    for prefix,z,depth,material in [('Upper orchard terrace • walkable deck',3.2,.2,'Pale paving'),('Upper terrace • graphite reveal',3.05,.1,'Graphite')]:
        box(prefix+' • central landing',(side*14.5,0,z),(3,9.2,depth),material,'Traversal',.015)
        box(prefix+' • outer link',(side*15.4,0,z),(1.2,14,depth),material,'Traversal',.015)
        for end in [-1,1]:box(prefix+' • end link',(side*13.9,end*6.9,z),(1.8,.2,depth),material,'Traversal',.01)
for o in s.objects:
    if o.get('role')=='walkable_ramp' and 'UPPER_RAMP' in o.name:o.location.x+=math.copysign(1.8,o.location.x)
s['clear_gallery_junctions']=True
s['upper_ramp_x_m']='11.3 to 14.8 (mirrored); outer terrace notches'
s['decorative_branches']=True
for note in bpy.data.texts:
    if note.name.startswith('START HERE • Garden Circuit review'):
        note.clear();note.write((SOURCE.parent/'Review_Notes.md').read_text())
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
