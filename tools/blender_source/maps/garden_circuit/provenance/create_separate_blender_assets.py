import bpy,math
from pathlib import Path
from mathutils import Vector
BASE=Path('/Users/samjo/Apple Legends/tools/blender_source')
ORIGINAL=BASE/'calibration_assets.blend'
STAGING=Path('/Users/samjo/Documents/Codex/2026-10-02/reg/work')

specs=[('Player Robot','MiniBot','characters/player/MiniBot_Player.blend','AL_Cyan'),('Enemy Robot','MiniBot','characters/enemy/MiniBot_Enemy.blend','AL_Amber'),('Pulse Rifle','PulseRifle','weapons/PulseRifle.blend',None),('Campus Props',None,'props/Campus_Props.blend',None)]
for title,source,rel,accent in specs:
    bpy.ops.wm.read_homefile(use_empty=True)
    with bpy.data.libraries.load(str(ORIGINAL),link=False) as (available,loaded):loaded.scenes=['Apple Legends — Asset Workshop']
    scene=bpy.data.scenes.new(title+' • Editable Asset');bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=.31
    scene['coordinate_convention']='Original Godot authoring units; displayed meter scale = 0.31. No mesh size or runtime export change.'
    groups={}
    def group(name):
        if name not in groups:
            c=bpy.data.collections.new(title+' / '+name);scene.collection.children.link(c);groups[name]=c
        return groups[name]
    def duplicate(rootname,loc):
        src=bpy.data.objects[rootname];r=src.copy();r.name=title+' / '+rootname;r.parent=None;r.location=loc;r.rotation_euler=(0,0,0);r.scale=(1,1,1);group('00 Root').objects.link(r);mapping={src:r}
        def depth(o):
            n=0
            while o.parent:n+=1;o=o.parent
            return n
        for child in sorted(src.children_recursive,key=depth):
            d=child.copy();d.name=title+' / '+child.name;d.parent=mapping[child.parent];mapping[child]=d
            n=child.name
            if source=='MiniBot':
                category='06 Attached Weapon' if n.startswith('BotWeapon') else '01 Head and Face' if any(k in n for k in ['Helmet','FaceGlass','Eye','Ear']) else '02 Torso' if any(k in n for k in ['Torso','Chest']) else '03 Arms and Hands' if any(k in n for k in ['Shoulder','Forearm','Hand']) else '04 Legs and Feet' if any(k in n for k in ['Hip','Shin','Boot']) else '05 Backpack'
            elif source=='PulseRifle':
                category='05 Robot Hands and Arms' if any(k in n for k in ['Palm','HandShell','Finger','ForearmShell','WristSeal']) else '02 Muzzle' if any(k in n for k in ['Muzzle','Bore','FrontHousing']) else '03 Sights' if any(k in n for k in ['Sight','FrontPost']) else '04 Energy and Magazine' if any(k in n for k in ['Power','Window','ChargeCell','Cartridge']) else '01 Rifle Body and Grip'
            else:category='01 '+rootname
            group(category).objects.link(d)
            if accent and any(k in n for k in ['Eye','ChestIndicator','BotWeaponPower']):
                d.data=child.data.copy();d.data.materials.clear();d.data.materials.append(bpy.data.materials[accent])
        return r
    if source:duplicate(source,(0,0,0))
    else:
        for i,name in enumerate(['CargoPod','ChargeColumn','CampusBench','GardenPlanter','ShellWall']):duplicate(name,((i%3)*5,(i//3)*5,0))
    note=bpy.data.texts.new('START HERE • '+title)
    note.write(title+' editable source.\nBody parts and held weapon / robot hands are separate named collections.\nPlayer and enemy share the chassis; cyan versus amber is a presentation variant, not a new gameplay class.\nGeometry uses the accepted original authoring units, with 0.31 meters per displayed Blender unit. Existing Godot GLBs are unchanged.\n')
    staging=STAGING/(title.replace(' ','_')+'_isolated.blend')
    bpy.data.libraries.write(str(staging),{scene,note},fake_user=True)
    # Reopen only this asset, then save a properly framed full Blender document.
    bpy.ops.wm.open_mainfile(filepath=str(staging))
    scene=next(s for s in bpy.data.scenes if s.name.startswith(title));bpy.context.window.scene=scene
    target=Vector((0,0,.85)) if source else Vector((5,2.5,1.2))
    eye=target+Vector((3.0,-4.5,2.5));rotation=(target-eye).to_track_quat('-Z','Y')
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                sp=area.spaces.active;sp.shading.type='MATERIAL';sp.overlay.show_overlays=False
                sp.region_3d.view_location=target;sp.region_3d.view_distance=4.0 if source else 17.0;sp.region_3d.view_rotation=rotation;sp.region_3d.view_perspective='PERSP'
    bpy.ops.wm.save_as_mainfile(filepath=str(BASE/rel))
    print('SAVED ASSET',str(BASE/rel),len(scene.objects),flush=True)
