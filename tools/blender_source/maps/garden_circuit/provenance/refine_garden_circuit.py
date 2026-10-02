import bpy, math
from pathlib import Path
from mathutils import Vector
BUILD_STAGE=0
exec(compile(open('/Users/samjo/Documents/Codex/2026-10-02/reg/work/build_garden_circuit.py').read(),'build_garden_circuit.py','exec'))
s=scene();bpy.context.window.scene=s
# Separate a saturated camera backdrop from softer environmental illumination.
nt=s.world.node_tree;nt.nodes.clear()
output=nt.nodes.new('ShaderNodeOutputWorld')
env=nt.nodes.new('ShaderNodeBackground');env.name='Soft campus illumination';env.inputs['Color'].default_value=(.62,.76,.92,1);env.inputs['Strength'].default_value=.60
sky=nt.nodes.new('ShaderNodeBackground');sky.name='Blue sky for camera';sky.inputs['Color'].default_value=(.14,.38,.90,1);sky.inputs['Strength'].default_value=1.0
lp=nt.nodes.new('ShaderNodeLightPath');mix=nt.nodes.new('ShaderNodeMixShader')
nt.links.new(lp.outputs['Is Camera Ray'],mix.inputs[0]);nt.links.new(env.outputs[0],mix.inputs[1]);nt.links.new(sky.outputs[0],mix.inputs[2]);nt.links.new(mix.outputs[0],output.inputs['Surface'])
sun=bpy.data.objects['Afternoon sun'];sun.data.energy=3.0;sun.data.color=(1,.92,.80);sun.data.angle=.045
s.view_settings.exposure=.35
# Human-scale translucent-looking clouds are original soft meshes used only in distant dressing.
cloudmat=mat('Cloud',(.89,.94,1),1)
for side in [-1,1]:
    for center in [(-8,side*30,11),(10,side*32,13),(0,side*36,14)]:
        x,y,z=center
        for dx,dz,rad in [(-2.2,0,1.4),(-.7,.6,1.9),(1.2,.4,1.7),(2.8,-.1,1.2)]:
            sphere('Distant soft cloud',(x+dx,y,z+dz),(rad,rad*.65,rad*.58),cloudmat,'Skyline',segments=24)
# Add product-design details to the architecture, kept above traversal clearance.
for side in [-1,1]:
    accent='Cyan' if side==-1 else 'Amber'
    for y in [-6,0,6]:
        box('Arcade ceiling • recessed lighting',(side*6.8,y,3.062),(.045,2.7,.018),accent,'Architecture',.006)
    # Tall interrupted panel blocks part of gallery dominance, no barrier across its walkway.
    x=side*4.86;y=-side*1.45
    box('Gallery view break • ceramic panel',(x,y,1.53),(.20,1.45,1.36),'Porcelain','Traversal',.085)
    box('Gallery view break • inset',(x-side*.107,y,1.55),(.025,1.13,.95),'Graphite','Traversal',.025)
    box('Gallery view break • energy seam',(x-side*.124,y-.48,1.55),(.014,.024,.72),accent,'Traversal',.006)
    # White, graphite, and planting rhythms along outer facade.
    for y in [-5,5]:
        box('Human facade • recessed service panel',(side*8.825,y,1.55),(.022,1.3,1.85),'Graphite','Architecture',.03)
        box('Service panel • ceramic raised bezel',(side*8.792,y,1.55),(.028,1.07,1.57),'Porcelain','Architecture',.045)
        box('Service panel • blue access slit',(side*8.772,y,1.31),(.014,.026,.46),accent,'Architecture',.006)
    # Tower cap ornaments emphasize civilian infrastructure.
    x=0;y=side*17
    cyl('Tower roof • energy socket',(x,y,10.20),.55,.12,'Graphite','Skyline')
    cyl('Tower roof • luminous core',(x,y,10.28),.36,.06,accent,'Skyline')
# Original leaf crest on the opposing spawn hub: rounded paired leaves.
for side in [-1,1]:
    y=side*8.38
    for dx in [-.16,.16]:
        o=sphere('Power dock • orchard crest',(dx,y,.90),(.16,.017,.085),'Mint','Spawn docks',16)
        o.rotation_euler.y=.45 if dx>0 else -.45
# Tactical camera avoids cropping the arena and has a corresponding roof-free review render.
s.objects['06 • Tactical overhead'].data.ortho_scale=34
# More useful opening viewport: eye-level character scene, not distant dollhouse view.
s.camera=s.objects['02 • Robot eye / hill approach']
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        sp=area.spaces.active;sp.region_3d.view_perspective='CAMERA';sp.region_3d.view_camera_zoom=5
        sp.shading.type='MATERIAL';sp.shading.use_scene_world=True;sp.shading.use_scene_lights=True
        sp.overlay.show_overlays=False
# All floors and boundaries remain available in wire proxies; reset post-review visibility.
bpy.data.collections['GC • Robot scale reference'].hide_viewport=False
s['review_passes']='Layout / bot scale / overlap / clear ground lanes / spawn shielding / lighting / gallery dominance'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Apple_Legends_Garden_Circuit.blend'))
print('REFINEMENT SAVED: blue sky, warm sun, partial gallery view screens, human details, camera framing.')
