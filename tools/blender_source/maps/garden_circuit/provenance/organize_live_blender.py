import bpy
from pathlib import Path
s=bpy.data.scenes['A1 • Garden Circuit • 3v3 KOTH'];bpy.context.window.scene=s
base=Path('/Users/samjo/Apple Legends/tools/blender_source')
mapgroup=bpy.data.collections.new('01 MAP • Garden Circuit');s.collection.children.link(mapgroup)
char=bpy.data.collections.new('02 CHARACTERS • Scale References');s.collection.children.link(char)
setup=bpy.data.collections.new('04 REVIEW • Cameras and Lighting');s.collection.children.link(setup)
for c in list(s.collection.children):
    if not c.name.startswith('GC • '):continue
    if c.name=='GC • Robot scale reference':
        s.collection.children.unlink(c);char.children.link(c)
        player=bpy.data.collections.new('PLAYER • Cyan Robots');enemy=bpy.data.collections.new('ENEMY • Amber Robots');c.children.link(player);c.children.link(enemy)
        for root in list(c.objects):
            if root.parent is not None:continue
            try:index=int(root.name.rsplit(' ',1)[-1])
            except ValueError:continue
            parent=enemy if index in [4,5,6,8] else player
            body=bpy.data.collections.new(('Enemy' if parent==enemy else 'Player')+' '+str(index)+' • Body')
            gun=bpy.data.collections.new(('Enemy' if parent==enemy else 'Player')+' '+str(index)+' • Held Weapon')
            parent.children.link(body);parent.children.link(gun)
            for ob in [root]+list(root.children_recursive):
                dest=gun if 'BotWeapon' in ob.name else body
                if ob.name in c.objects:c.objects.unlink(ob)
                dest.objects.link(ob)
    elif c.name=='GC • Gameplay markers':c.name='03 GAMEPLAY • Spawns, Point, Pickups'
    elif c.name in ['GC • Review cameras','GC • Lighting','GC • Collision proxies']:
        s.collection.children.unlink(c);setup.children.link(c)
    else:
        s.collection.children.unlink(c);mapgroup.children.link(c)
# The original asset workshop also gets clear per-asset groups.
w=bpy.data.scenes['Apple Legends — Asset Workshop']
for root in [o for o in list(w.objects) if o.parent is None and o.type=='EMPTY']:
    collection=bpy.data.collections.new('WORKSHOP • '+root.name);w.collection.children.link(collection)
    for ob in [root]+list(root.children_recursive):
        for c in list(ob.users_collection):
            if c==w.collection:c.objects.unlink(ob)
        collection.objects.link(ob)
notes=bpy.data.texts['START HERE • Garden Circuit review']
notes.write('\nASSET ORGANIZATION\nEditable map: tools/blender_source/maps/garden_circuit/GardenCircuit.blend\nPlayer: tools/blender_source/characters/player/MiniBot_Player.blend\nEnemy: tools/blender_source/characters/enemy/MiniBot_Enemy.blend\nGun and robot hands: tools/blender_source/weapons/PulseRifle.blend\nProps: tools/blender_source/props/Campus_Props.blend\nVisual runtime export: art/maps/garden_circuit/GardenCircuit.glb\nThe map Outliner groups map, player/enemy references with separate held weapons, gameplay markers, and review setup.\n')
bpy.ops.wm.save_as_mainfile(filepath=str(base/'maps/garden_circuit/GardenCircuit.blend'))
print('Saved organized map into the repository. No geometry or gameplay changed.')
