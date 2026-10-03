"""Make the gallery front's solid edges explicit while retaining a clear underpass portal."""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[5]
SOURCE=ROOT/'tools/blender_source/maps/garden_circuit/GardenCircuit.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
BUILD_STAGE=0
exec(compile((Path(__file__).parent/'build_garden_circuit.py').read_text(),'build_garden_circuit.py','exec'))
s=scene();bpy.context.window.scene=s
# The former thin slab invited a capsule beneath the lip before a jump hit its underside.
# These visible supports leave the authored y=+1.5 underpass open (Godot z=-1.5).
for o in list(coll('Traversal').objects):
    if o.name.startswith('Gallery front structural skirt'):bpy.data.objects.remove(o,do_unlink=True)
for side in [-1,1]:
    for lo,hi in [(-7,-2.70),(-.30,.30),(2.70,7)]:
        box('Gallery front structural skirt',(side*7.61,(lo+hi)/2,.825),(.20,hi-lo,1.65),'Porcelain','Traversal',.025)
s['lower_gallery_edge_portal_m']='Blender y=+/-1.5, 2.4 m wide; both center-facing galleries'
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
