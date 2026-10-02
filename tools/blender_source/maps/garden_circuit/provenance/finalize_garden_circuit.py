import bpy,math,json
from mathutils import Vector
from pathlib import Path
OUT=Path('/Users/samjo/Documents/Codex/2026-10-02/reg/outputs/garden-circuit')
s=bpy.data.scenes['A1 • Garden Circuit • 3v3 KOTH'];bpy.context.window.scene=s
cam=s.objects['05 • Team dock eye level'];cam.location=(.55,-10.5,.47);cam.rotation_euler=(Vector((2.5,-7,.65))-cam.location).to_track_quat('-Z','Y').to_euler()
# Preserve source geometry. Compile separate export meshes by collection with evaluated bevels.
ex=bpy.data.scenes.new('EXPORT • Garden Circuit visual map')
excluded={'GC • Robot scale reference','GC • Collision proxies','GC • Review cameras','GC • Lighting'}
bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
compiled=[]
for collection in s.collection.children:
    if collection.name in excluded:continue
    verts=[];faces=[];face_materials=[];smooth=[];materials=[]
    for o in collection.objects:
        if o.type not in {'MESH','FONT'}:continue
        ev=o.evaluated_get(deps);me=ev.to_mesh()
        if me is None:continue
        offset=len(verts);matrix=o.matrix_world
        verts.extend(tuple(matrix@v.co) for v in me.vertices)
        remap=[]
        for m in me.materials:
            if m not in materials:materials.append(m)
            remap.append(materials.index(m))
        for p in me.polygons:
            faces.append(tuple(offset+i for i in p.vertices));face_materials.append(remap[p.material_index] if remap else 0);smooth.append(p.use_smooth)
        ev.to_mesh_clear()
    if not verts:continue
    name=collection.name.replace('GC • ','MAP • ')
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    for m in materials:me.materials.append(m)
    for p,mi,sm in zip(me.polygons,face_materials,smooth):p.material_index=mi;p.use_smooth=sm
    ob=bpy.data.objects.new(name,me);ex.collection.objects.link(ob);compiled.append(ob)
for o in s.objects:
    if o.get('role') and o.get('role') not in {'scale_reference'}:
        dup=o.copy();dup.parent=None;dup.matrix_world=o.matrix_world.copy();ex.collection.objects.link(dup)
ex['purpose']='Consolidated visual-only glTF source; no collision or gameplay logic.'
ex['meters_to_accepted_game_units']=1/.31
bpy.context.window.scene=ex
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'Garden_Circuit_Visual_Map.glb'),use_selection=True,use_active_scene=True,export_apply=True,export_animations=False,export_extras=True)
bpy.context.window.scene=s;bpy.ops.object.select_all(action='DESELECT')
text=bpy.data.texts['START HERE • Garden Circuit review']
text.write('\nFINAL PASSES\n- Six spawn positions shielded in 66 sampled objective/gallery sightlines.\n- Four ground service lane centerlines clear at robot eye height.\n- Ramp face normals corrected in both travel directions.\n- Roof canopies have a separate collection; hide it to inspect the gallery layout.\n- Separate EXPORT scene contains merged visual meshes; source scene remains fully editable.\n- Camera 05 moved clear of reference robot helmet.\n- Visual GLB excludes reference robots, lighting, cameras, and collision proxies.\n- Layout and render checks are not an in-game balance or performance test.\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Apple_Legends_Garden_Circuit.blend'))
summary={'editable_scene':s.name,'editable_object_count':len(s.objects),'compiled_visual_meshes':len(compiled),'compiled_material_batches':sum(len(o.data.materials) for o in compiled),'compiled_vertices':sum(len(o.data.vertices) for o in compiled),'export_scene':ex.name}
(OUT/'asset-summary.json').write_text(json.dumps(summary,indent=2))
print('FINAL SUMMARY',json.dumps(summary))
