"""Dedicated source review camera for structural skirts and the two open portals."""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[5]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'tools/blender_source/maps/garden_circuit/GardenCircuit.blend'))
s=bpy.data.scenes['A1 • Garden Circuit • 3v3 KOTH'];bpy.context.window.scene=s
s.render.resolution_x=1440;s.render.resolution_y=960;s.render.resolution_percentage=100
if hasattr(s,'eevee'):s.eevee.taa_render_samples=32
data=bpy.data.cameras.new('Gallery lower edge review')
cam=bpy.data.objects.new('08 • Gallery lower edge review',data);s.collection.objects.link(cam)
cam.location=(4.2,-4.4,.9)
cam.rotation_euler=(Vector((7.55,1.5,1.2))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.lens=24;s.camera=cam
s.render.filepath=str(ROOT/'tools/blender_source/maps/garden_circuit/previews/08-lower-edge.png')
bpy.ops.render.render(write_still=True)
# Review camera is temporary; authoring source and gameplay markers remain untouched.
