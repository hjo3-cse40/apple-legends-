"""Rebuild the authoritative source's runtime export; run with Blender --background --python."""
import bpy,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[5]
SOURCE=ROOT/'tools/blender_source/maps/garden_circuit/GardenCircuit.blend'
OUT=ROOT/'art/maps/garden_circuit/GardenCircuit.glb'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
s=bpy.data.scenes['A1 • Garden Circuit • 3v3 KOTH'];bpy.context.window.scene=s
# Foundation and continuous slab previously shared their top plane at z=0.
bpy.data.objects['Courtyard foundation'].location.z=-.30
bpy.data.objects['Garden court continuous walk surface'].location.z=-.115
bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
ex=bpy.data.scenes.get('EXPORT • Garden Circuit visual map')
if ex:
 for o in list(ex.objects):bpy.data.objects.remove(o,do_unlink=True)
else:ex=bpy.data.scenes.new('EXPORT • Garden Circuit visual map')
def compile_batch(name,objects,collision_only=False):
 verts=[];faces=[];indices=[];smooth=[];materials=[]
 for o in objects:
  if o.type not in {'MESH','FONT'}:continue
  ev=o.evaluated_get(deps);me=ev.to_mesh()
  if me is None:continue
  offset=len(verts);matrix=o.matrix_world
  verts.extend(tuple(matrix@v.co) for v in me.vertices)
  remap=[]
  for m in me.materials:
   if m not in materials:materials.append(m)
   remap.append(materials.index(m))
  reverse=matrix.determinant()<0
  for p in me.polygons:
   face=tuple(offset+i for i in p.vertices)
   faces.append(tuple(reversed(face)) if reverse else face)
   indices.append(remap[p.material_index] if remap else 0);smooth.append(p.use_smooth)
  ev.to_mesh_clear()
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
 for m in materials:
  m.use_backface_culling=False
  me.materials.append(m)
 for p,mi,sm in zip(me.polygons,indices,smooth):p.material_index=mi;p.use_smooth=sm
 ob=bpy.data.objects.new(name,me);ex.collection.objects.link(ob)
 if collision_only:ob['collision_only']=True
 return ob
categories=['Architecture','Ground','Objective','Planting','Props','Roof canopies • hide for tactical review','Signage','Skyline','Spawn docks','Traversal']
for category in categories:compile_batch('MAP • '+category,bpy.data.collections['GC • '+category].objects)
solid_plants=[o for o in bpy.data.collections['GC • Planting'].objects if any(token in o.name for token in ['ceramic basin','soil','base reveal','trunk'])]
compile_batch('COLLISION • Planting solids',solid_plants,True)
def bounds(o):
 points=[o.matrix_world @ Vector(corner) for corner in o.bound_box]
 return {'min':[min(p[i] for p in points) for i in range(3)],'max':[max(p[i] for p in points) for i in range(3)]}
# Sample actual authored obstacle faces, retaining source names for regression reports.
audit=[]
for category in categories:
 if category in {'Ground','Signage','Planting'}:continue
 for o in bpy.data.collections['GC • '+category].objects:
  if o.type!='MESH':continue
  # Tiny trim/flat light decals are backed by the parent obstacle, not independent barriers.
  if any(token in o.name for token in ['CargoHandle','CargoStrip','gadget socket','dock ready light']):continue
  ev=o.evaluated_get(deps);me=ev.to_mesh();me.calc_loop_triangles()
  if not me.loop_triangles:ev.to_mesh_clear();continue
  triangle=max(me.loop_triangles,key=lambda t:t.area)
  points=[o.matrix_world @ me.vertices[index].co for index in triangle.vertices]
  center=sum(points,Vector())/3;normal=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
  audit.append({'source':o.name,'batch':'MAP • '+category,'point':list(center),'normal':list(normal),'bounds':bounds(o)})
  ev.to_mesh_clear()
for o in solid_plants:
 ev=o.evaluated_get(deps);me=ev.to_mesh();me.calc_loop_triangles()
 triangle=max(me.loop_triangles,key=lambda t:t.area)
 points=[o.matrix_world @ me.vertices[index].co for index in triangle.vertices]
 center=sum(points,Vector())/3;normal=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
 audit.append({'source':o.name,'batch':'COLLISION • Planting solids','point':list(center),'normal':list(normal),'bounds':bounds(o)})
 ev.to_mesh_clear()
(OUT.parent/'obstacle-audit.json').write_text(json.dumps({'ground_top_planes_m':[-.06,-.025,.015],'decorative_accents_excluded':['CargoHandle','CargoStrip','gadget socket','dock ready light'],'obstacles':audit},indent=2)+'\n')
# Preserve named gameplay markers without the reference robots.
for o in s.objects:
 if o.get('role') and o.get('role')!='scale_reference':
  dup=o.copy();dup.parent=None;dup.matrix_world=o.matrix_world.copy();ex.collection.objects.link(dup)
ex['purpose']='Runtime map with hidden solid-plant collision mesh; decorative leaves and branches remain non-solid.'
bpy.context.window.scene=ex
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT),use_selection=True,use_active_scene=True,export_apply=True,export_animations=False,export_extras=True)
bpy.context.window.scene=s
visuals=[o for o in ex.objects if o.type=='MESH' and not o.get('collision_only')]
summary={'editable_scene':s.name,'editable_object_count':len(s.objects),'compiled_visual_meshes':len(visuals),'compiled_material_batches':sum(len(o.data.materials) for o in visuals),'compiled_vertices':sum(len(o.data.vertices) for o in visuals),'export_scene':ex.name,'arena_footprint_m':s.get('arena_footprint_m'),'playable_tiers_m':s.get('playable_tiers_m'),'solid_plant_components':len(solid_plants),'obstacle_samples':len(audit),'miniature_world_scale':s.get('miniature_world_scale',False),'bench_scale_multiplier':s.get('bench_scale_multiplier',1.0),'robot_reference_height_m':s.get('robot_reference_height_m',.55),'human_door_height_m':s.get('human_door_height_m',2.2)}
(SOURCE.parent/'asset-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
print('RUNTIME EXPORT:',len(solid_plants),'plant solids; ground planes separated; two-sided materials')
