import bpy, math, random, json
from pathlib import Path
from mathutils import Vector, Quaternion
OUT=Path('/Users/samjo/Documents/Codex/2026-10-02/reg/outputs/garden-circuit')
SCENE='A1 • Garden Circuit • 3v3 KOTH'
random.seed(21)

def scene(): return bpy.data.scenes[SCENE]
def coll(name): return bpy.data.collections.get('GC • '+name)
def link(o,group):
    for c in list(o.users_collection): c.objects.unlink(o)
    coll(group).objects.link(o)
    return o

def mat(name,color,rough=.5,metal=0,emit=0):
    m=bpy.data.materials.get('GC • '+name)
    if m:return m
    m=bpy.data.materials.new('GC • '+name)
    n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    n.inputs['Base Color'].default_value=(*color,1)
    n.inputs['Roughness'].default_value=rough
    n.inputs['Metallic'].default_value=metal
    n.inputs['Emission Color'].default_value=(*color,1)
    n.inputs['Emission Strength'].default_value=emit
    m.diffuse_color=(*color,1)
    return m

def mats():
    return {k:mat(k,*v) for k,v in {
    'Porcelain':((.81,.86,.88),.32,0,0),'Warm shell':((.78,.77,.70),.44,0,0),
    'Paving':((.51,.60,.65),.7,0,0),'Pale paving':((.70,.74,.72),.72,0,0),
    'Graphite':((.028,.045,.063),.45,.3,0),'Metal':((.29,.39,.43),.33,.65,0),
    'Cyan':((.015,.57,.95),.3,.1,1.5),'Amber':((1,.31,.035),.3,.1,1.5),
    'Mint':((.18,.74,.55),.4,0,.5),'Soil':((.06,.045,.027),.98,0,0),
    'Grass':((.12,.23,.045),.85,0,0),'Leaf dark':((.035,.17,.08),.8,0,0),
    'Leaf lime':((.23,.42,.075),.72,0,0),'Leaf mid':((.09,.30,.075),.8,0,0),
    'Bark':((.18,.12,.065),.85,0,0),'Ink':((.08,.13,.16),.5,0,0),
    'Glass':((.04,.15,.21),.17,.55,0),'White label':((.83,.93,1),.4,0,0)
    }.items()}
M=mats()

def finish(o,name,group,material,loc=None):
    o.name=name
    link(o,group)
    if loc is not None:o.location=loc
    if material:o.data.materials.append(M[material] if isinstance(material,str) else material)
    return o

def box(name,loc,size,material='Porcelain',group='Architecture',bevel=.08):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        b=o.modifiers.new('Machined soft edge','BEVEL');b.width=min(bevel,min(size)*.42);b.segments=3
        o.modifiers.new('Face-weighted normals','WEIGHTED_NORMAL')
    return finish(o,name,group,material,loc)

def cyl(name,loc,r,depth,material='Porcelain',group='Architecture',vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth)
    o=bpy.context.object
    b=o.modifiers.new('Rim radius','BEVEL');b.width=min(.045,depth*.23,r*.15);b.segments=3
    o.modifiers.new('Face-weighted normals','WEIGHTED_NORMAL')
    return finish(o,name,group,material,loc)

def sphere(name,loc,scale,material='Leaf mid',group='Planting',segments=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=8,radius=1)
    o=bpy.context.object;o.scale=scale
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,group,material,loc)

def mesh(name,verts,faces,material,group):
    d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update()
    o=bpy.data.objects.new(name,d);coll(group).objects.link(o)
    d.materials.append(M[material]);return o

def ring(name,loc,r,width,material='Cyan',group='Objective',a=0,b=2*math.pi):
    # Flat annular ribbon, not a climbable torus.
    n=max(8,int(96*(b-a)/(2*math.pi)))
    verts=[]
    for i in range(n+1):
        t=a+(b-a)*i/n
        verts.extend([(loc[0]+math.cos(t)*(r-width/2),loc[1]+math.sin(t)*(r-width/2),loc[2]),(loc[0]+math.cos(t)*(r+width/2),loc[1]+math.sin(t)*(r+width/2),loc[2])])
    return mesh(name,verts,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(n)],material,group)

def text(name,body,loc,size=.2,material='Ink',rot=(math.pi/2,0,0),group='Signage'):
    d=bpy.data.curves.new(name,'FONT');d.body=body;d.size=size;d.align_x='CENTER';d.extrude=.001;d.space_character=1.1
    o=bpy.data.objects.new(name,d);coll(group).objects.link(o);o.location=loc;o.rotation_euler=rot;d.materials.append(M[material]);return o

def marker(name,loc,kind,props=None):
    o=bpy.data.objects.new(name,None);coll('Gameplay markers').objects.link(o);o.location=loc;o.empty_display_size=.22
    o['role']=kind
    for k,v in (props or {}).items():o[k]=v
    return o

def segment(name,start,end,r,material,group='Planting'):
    d=Vector(end)-Vector(start);o=cyl(name,(Vector(start)+Vector(end))/2,r,d.length,material,group,12)
    o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o

def ramp(name,x,y0,y1,width,height):
    # y0 is low end, y1 is upper landing; underside at ground.
    verts=[(x-width/2,y0,0),(x+width/2,y0,0),(x+width/2,y1,0),(x-width/2,y1,0),
           (x-width/2,y0,.025),(x+width/2,y0,.025),(x+width/2,y1,height),(x-width/2,y1,height)]
    o=mesh(name,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'Pale paving','Traversal')
    b=o.modifiers.new('Ramp edge finish','BEVEL');b.width=.012;b.segments=2
    o['walkable']=True;o['rise_m']=height;o['slope_degrees']=round(math.degrees(math.atan(height/abs(y1-y0))),2)
    # Edge strips follow the slope, flush enough for small feet.
    for dx in [-width/2+.09,width/2-.09]:
        strip=box(name+' • edge guidance',(x+dx,(y0+y1)/2,height/2+.023),(.035,abs(y1-y0),.016),'Mint','Traversal',.005)
        strip.rotation_euler.x=math.atan((height-.025)/(y1-y0))
    return o

def asset(source,name,loc,scale,yaw=0,group='Props',accent=None):
    src=bpy.data.objects.get(source)
    if not src:raise ValueError('Required project asset missing: '+source)
    root=src.copy();root.name=name;root.parent=None;coll(group).objects.link(root)
    root.location=loc;root.rotation_euler=(0,0,yaw);root.scale=(scale,)*3
    mapping={src:root}
    def depth(o):
        n=0
        while o.parent is not None:
            n+=1;o=o.parent
        return n
    for child in sorted(src.children_recursive,key=depth):
        dup=child.copy();dup.name=name+' • '+child.name;dup.parent=mapping[child.parent];coll(group).objects.link(dup);mapping[child]=dup
        if accent and child.type=='MESH' and any(s in child.name for s in ['Eye','ChestIndicator','BotWeaponPower']):
            dup.data=child.data.copy();dup.data.materials.clear();dup.data.materials.append(M[accent])
    root['source_asset']=source
    return root

def planter(name,at,size=(2.3,1.2,.78),trees=False):
    x,y=at;w,d,h=size
    box(name+' • ceramic basin',(x,y,h/2),(w,d,h),'Porcelain','Planting',.16)
    box(name+' • soil',(x,y,h+.006),(w-.18,d-.18,.06),'Soil','Planting',.04)
    box(name+' • base reveal',(x,y,.07),(w-.1,d-.1,.14),'Graphite','Planting',.04)
    for i in range(7):
        xx=x+random.uniform(-w*.34,w*.34);yy=y+random.uniform(-d*.30,d*.30)
        sphere(name+' • shrub',(xx,yy,h+.16),(.29,.25,.22),'Leaf dark' if i%3==0 else 'Leaf mid')
    if trees:tree(name+' • orchard tree',(x,y,h+.035),2.7)

def tree(name,at,height):
    x,y,z=at
    segment(name+' • trunk',(x,y,z),(x+.08,y,z+height*.64),.075,'Bark')
    centers=[]
    for i in range(6):
        a=i*math.tau/6;tip=(x+math.cos(a)*.54,y+math.sin(a)*.54,z+height*.70+(i%2)*.25)
        segment(name+' • branch',(x+.04,y,z+height*.40),tip,.027,'Bark');centers.append(tip)
    for i,(xx,yy,zz) in enumerate(centers+[(x,y,z+height*.93)]):
        sphere(name+' • crown',(xx,yy,zz),(.70,.64,.53),'Leaf dark' if i%3==0 else 'Leaf mid',segments=20)
        for j in range(15):
            a=random.random()*math.tau;t=random.uniform(-.8,.8); rr=math.sqrt(1-t*t)
            loc=(xx+math.cos(a)*rr*.65,yy+math.sin(a)*rr*.60,zz+t*.48)
            leaf=sphere(name+' • leaf cluster',loc,(.17,.10,.075),'Leaf lime' if j%3==0 else 'Leaf mid',segments=8)
            leaf.rotation_euler=(random.random(),random.random(),a)


def stage1():
    if bpy.data.scenes.get(SCENE):raise RuntimeError('Arena scene already exists; refusing duplicate build.')
    s=bpy.data.scenes.new(SCENE);bpy.context.window.scene=s
    for name in ['Ground','Architecture','Traversal','Objective','Spawn docks','Props','Planting','Signage','Skyline','Robot scale reference','Gameplay markers','Collision proxies','Review cameras','Lighting']:
        c=bpy.data.collections.new('GC • '+name);s.collection.children.link(c)
    s.unit_settings.system='METRIC';s.unit_settings.scale_length=1
    s['robot_height_m']=.55;s['game_units_per_meter']=1/.31;s['purpose']='Blender review arena; KOTH gameplay not implemented.'
    s['arena_footprint_m']='18 x 24';s['visual_direction']='White ceramic / graphite / cyan / amber / orchard greenery'
    box('Courtyard foundation',(0,0,-.24),(18.5,24.5,.48),'Graphite','Ground',.25)
    box('Garden court continuous walk surface',(0,0,-.09),(18,24,.18),'Paving','Ground',.06)
    # Large human-size pavers with seams, kept flat for prototype collision.
    for x in range(-8,9,2):
        for y in range(-11,12,2):
            box('Campus paving • 2 m module',(x,y,.008),(1.965,1.965,.014),'Pale paving' if (x+y)%4==1 else 'Paving','Ground',.013)
    # Rounded perimeter plinths and tall outer walls, with layered human doors.
    for side in [-1,1]:
        x=side*9
        box('Human campus boundary',(x,0,1.6),(.3,24,3.2),'Porcelain','Architecture',.13)
        box('Boundary charcoal sill',(x-side*.16,0,.16),(.08,23.6,.22),'Graphite','Architecture',.03)
        for y in [-8,-2,4,10]:
            box('Boundary articulated pier',(x-side*.09,y,1.6),(.28,.25,3.3),'Warm shell','Architecture',.05)
        # Raised ribbon roof leaves sky open and gives robot-level sense of scale.
        box('Garden arcade eave',(side*7.15,0,3.25),(3.65,18,.22),'Porcelain','Architecture',.11)
        box('Arcade underside shadow',(side*7.15,0,3.10),(3.15,17.5,.06),'Warm shell','Architecture',.025)
        for y in [-7.6,7.6]:
            box('Human arcade support',(side*7.95,y,1.55),(.36,.36,3.1),'Porcelain','Architecture',.13)
    for side in [-1,1]:
        y=side*12
        box('Spawn campus facade',(0,y,1.55),(18,.36,3.1),'Porcelain','Architecture',.14)
        box('Facade canopy',(0,side*11.25,3.18),(12.5,1.9,.25),'Porcelain','Architecture',.11)
        box('Facade graphite fascia',(0,side*11.17,3.06),(11.8,1.9,.045),'Graphite','Architecture',.018)
        # Human door is scenery, contrast to the tiny service ports.
        box('Human service door',(side*6.8,y-side*.205,1.10),(1.20,.07,2.2),'Graphite','Architecture',.08)
        box('Human door recessed face',(side*6.8,y-side*.26,1.12),(1.03,.04,2.02),'Metal','Architecture',.05)
        box('Human door handle',(side*6.8-.36,y-side*.30,1.04),(.035,.035,.28),'Porcelain','Architecture',.012)
    # Galleries are opposite mirror copies, do not span the hill.
    for side in [-1,1]:
        x=side*6.1
        box('Garden gallery • walkable deck',(x,0,.75),(2.7,6,.20),'Pale paving','Traversal',.055)
        box('Gallery dark underside',(x,0,.60),(2.65,5.9,.12),'Graphite','Traversal',.045)
        for end in [-1,1]:ramp('Gallery access ramp',x,end*7.5,end*3,2.7,.85)
        # Segmented low combat cover, openings preserve sight and expose occupants.
        for y in [-2,2]:
            box('Gallery low ceramic guard',(x-side*1.25,y,1.02),(.18,1.2,.34),'Porcelain','Traversal',.05)
        for y in [-2.3,2.3]:
            box('Gallery structural foot',(x,y,.30),(.35,.35,.6),'Porcelain','Traversal',.08)
        marker('Gallery landing '+str(side),(x,0,.85),'walkable_gallery',{'two_ramp_access':True})
    # Walk surface objective: no tall central obstruction, cover at edges instead.
    cyl('Power garden • flush capture platform',(0,0,.034),2.05,.05,'Porcelain','Objective',96)
    cyl('Power garden • graphite inlay',(0,0,.065),1.87,.014,'Graphite','Objective',96)
    cyl('Power garden • inner paving',(0,0,.077),1.76,.014,'Pale paving','Objective',96)
    ring('CAPTURE • neutral mint perimeter',(0,0,.087),1.80,.05,'Mint')
    for i in range(12):
        a=i*math.tau/12;ring('Power circuit • segmented indicator',(0,0,.087),1.95,.065,'Cyan' if i%2==0 else 'Amber',a=a+.05,b=a+.38)
    # 180-degree symmetric edge cover leaves clear entrance quadrants.
    for side in [-1,1]:
        cover=box('Hill edge • split ceramic cover',(side*2.12,side*.72,.18),(1.18,.55,.36),'Porcelain','Objective',.11)
        cover.rotation_euler.z=side*-.28
        box('Hill cover • graphite foot',(side*2.12,side*.72,.07),(1.12,.49,.14),'Graphite','Objective',.035)
    marker('KOTH_CAPTURE_VOLUME',(0,0,.35),'capture_zone',{'radius_m':1.8,'floor_z_m':.08,'height_m':.7,'gallery_counts':False})
    marker('KOTH_POINT_ORIGIN',(0,0,.08),'objective')
    text('Hill identification','POWER / 01',(0,0,.092),.25,'Ink',(0,0,0),'Objective')
    print('STAGE 1: courtyard, human architecture, four ramps, two galleries, central objective created.')


def stage2():
    bpy.context.window.scene=scene()
    for side in [-1,1]:
        team='CYAN' if side==-1 else 'AMBER';accent='Cyan' if side==-1 else 'Amber';y=side*10.7
        # Tall hub between docks and point blocks immediate spawn fire; exits on both sides.
        box(team+' dock • fire screen',(0,side*9.0,.75),(3.4,1.15,1.5),'Porcelain','Spawn docks',.20)
        box(team+' dock • graphite recess',(0,side*8.415,.78),(2.95,.035,1.15),'Graphite','Spawn docks',.10)
        for x in [-1.25,1.25]:box(team+' dock • status rail',(x,side*8.386,.78),(.07,.025,.97),accent,'Spawn docks',.02)
        box(team+' dock • roof lip',(0,side*8.97,1.53),(3.65,1.38,.18),'Porcelain','Spawn docks',.085)
        for i,x in enumerate([-1.1,0,1.1]):
            cyl(team+' boot dock',(x,y,.055),.41,.08,'Graphite','Spawn docks')
            ring(team+' dock ready light',(x,y,.102),.35,.028,accent,'Spawn docks')
            marker(team+'_SPAWN_'+str(i+1),(x,y,.105),'team_spawn',{'team':team,'facing_blender_y':-side})
            # Miniature ports in a human facade.
            box(team+' service port',(x,side*11.78,.33),(.67,.05,.65),'Graphite','Spawn docks',.12)
            box(team+' service port accent',(x,side*11.735,.65),(.42,.015,.026),accent,'Spawn docks',.008)
        text(team+' dock title','A1 / '+team+' DOCK',(0,side*11.76,2.28),.34,'Ink',(math.pi/2 if side==1 else math.pi/2,0,0 if side==1 else math.pi))
        # Full-height staggered planters force a dogleg before seeing the point.
        planter(team+' approach planter',(-side*2.65,side*6.4),(2.3,1.1,.80),trees=True)
        planter(team+' garden flank',(side*3.0,side*3.85),(2.5,1.15,.72),trees=False)
        # Human bench, bot-readable size comparison. Seat at .45 m.
        asset('CampusBench',team+' human bench',(-side*3.0,side*3.15,0),.3913,0 if side==1 else math.pi)
        # Semi-height cargo pod gives cover without duplicating large human furniture everywhere.
        asset('CargoPod',team+' utility pod',(side*2.9,side*6.8,.02),.35,0,'Props')
        asset('ChargeColumn',team+' charging cabinet',(side*7.7,side*10.3,0),.75,0 if side==1 else math.pi,'Props')
        # Optional pickup in an exposed branch between main approach and gallery ramp.
        gx=-side*4.1;gy=side*5.0
        cyl(team+' gadget station',(gx,gy,.10),.34,.18,'Graphite','Props')
        ring(team+' gadget socket',(gx,gy,.195),.27,.025,accent,'Props')
        cap=box(team+' utility capsule',(gx,gy,.39),(.30,.26,.30),'Porcelain','Props',.095)
        box(team+' capsule face',(gx,gy-.135,.39),(.21,.022,.18),accent,'Props',.04)
        text(team+' capsule glyph','+',(gx,gy-.151,.33),.15,'White label',group='Props')
        marker(team+'_PICKUP',(gx,gy,.4),'utility_pickup',{'team_access':'symmetric','effect':'placeholder; unimplemented'})
        # Directional floor lanes. Robot-scale marks over human-scale paving.
        for yy in [side*7.7,side*5.8,side*2.75]:
            for xx in [-1.45,1.45]:
                o=box(team+' guidance dash',(xx,yy,.028),(.035,.52,.014),accent,'Ground',.005)
        for x in [-2.35,2.35]:marker(team+'_EXIT_'+str(x),(x,side*9,.04),'spawn_exit')
    # Human-scale planted edges frame cover; no foliage across the main objective.
    for side in [-1,1]:
        planter('Arcade tree island',(side*8.02,0),(1.45,2.0,.70),trees=True)
        for y in [-4.7,4.7]:planter('Arcade low green island',(side*8.04,y),(1.3,1.7,.60))
    # Review-only robots: separate collection, excluded from map export.
    specs=[(-1.1,-10.7,0,'Cyan'),(0,-10.7,0,'Cyan'),(1.1,-10.7,0,'Cyan'),(-1.1,10.7,math.pi,'Amber'),(0,10.7,math.pi,'Amber'),(1.1,10.7,math.pi,'Amber'),(-2,-.7,-.9,'Cyan'),(2,.7,2.2,'Amber'),(-3.1,3.0,0,'Cyan')]
    for i,(x,y,yaw,accent) in enumerate(specs):
        asset('MiniBot','55 cm robot reference '+str(i+1),(x,y,.11 if abs(y)>10 else .02),.31,yaw,'Robot scale reference',accent)
    marker('ROBOT_EYE_HEIGHT',(0,-2,.42),'scale_reference',{'robot_height_m':.55,'eye_height_m':.42})
    marker('HUMAN_HEIGHT_REFERENCE',(-6.8,11.8,0),'scale_reference',{'height_m':1.75})
    print('STAGE 2: protected docks, six spawn markers, cover, human benches, nine reference bots, two gadget sockets.')


def stage3():
    bpy.context.window.scene=scene()
    # Human campus beyond the game boundary: towers and curved balcony belts.
    for x,y,h,r in [(-12,9,8,2.0),(12,-9,8,2.0),(-11,-10,5.5,1.7),(11,10,5.5,1.7),(0,17,10,2.35),(0,-17,10,2.35)]:
        cyl('Campus tower • satin shell',(x,y,h/2),r,h,'Porcelain','Skyline',64)
        cyl('Campus tower • roof seam',(x,y,h-.22),r+.12,.16,'Graphite','Skyline',64)
        cyl('Campus tower • floating cap',(x,y,h+.05),r+.32,.20,'Porcelain','Skyline',64)
        for z in [h*.3,h*.65]:
            cyl('Campus tower • balcony',(x,y,z),r+.42,.16,'Porcelain','Skyline',64)
            cyl('Campus tower • balcony dark reveal',(x,y,z-.12),r+.30,.08,'Graphite','Skyline',64)
        # Deep graphite face and colored energy stripe.
        angle=-math.pi/2 if y>0 else math.pi/2
        xx=x+math.cos(angle)*(r+.015);yy=y+math.sin(angle)*(r+.015)
        box('Tower service face',(xx,yy,h*.53),(r*1.15,.05,h*.67),'Graphite','Skyline',.12)
        box('Tower status seam',(xx+r*.49,yy-.04 if y>0 else yy+.04,h*.53),(.055,.015,h*.54),'Cyan','Skyline',.015)
        text('Tower identification','A1',(xx,yy-.035 if y>0 else yy+.035,h*.67),.68,'White label',(math.pi/2,0,0 if y>0 else math.pi),'Skyline')
    # Broad background structures suggest campus continuity without adding playable acres.
    for side in [-1,1]:
        box('Distant garden terrace',(side*13,side*3,3.6),(5.5,7,.24),'Porcelain','Skyline',.12)
        for i in [-1,1]:
            box('Terrace support',(side*13+i*1.8,side*3,1.75),(.4,.5,3.5),'Porcelain','Skyline',.12)
        for yy in [-2,1,4]:
            tree('Distant orchard canopy',(side*13,side*3+yy,3.75),2.9)
    # Low skyline podium pads avoid floating architecture outside the courtyard.
    box('Campus surrounding terrace',(0,0,-.52),(35,42,.18),'Warm shell','Skyline',.25)
    # Center landmark is tall but at the edge of capture volume, not in its middle.
    # Two opposite pylons keep objective visually balanced and break gallery diagonal views.
    for side in [-1,1]:
        x=side*3.28;y=side*1.40
        cyl('Power hub • ceramic pylon',(x,y,1.02),.38,2.04,'Porcelain','Objective',48)
        box('Power hub • recessed panel',(x,y-.37,1.09),(.37,.035,1.45),'Graphite','Objective',.07)
        box('Power hub • neutral core',(x,y-.396,1.09),(.075,.02,1.12),'Mint','Objective',.02)
        cyl('Power hub • graphite collar',(x,y,1.89),.43,.13,'Graphite','Objective')
        cyl('Power hub • shell cap',(x,y,2.01),.44,.10,'Porcelain','Objective')
    # Original leaf insignia: two offset teardrop ellipses, no corporate logo.
    for side in [-1,1]:
        x=side*8.80;y=-side*4.0
        # Wall plaque faces courtyard; leaf symbols are subtle physical inlays.
        plaque=box('Garden sector • wall plaque',(x,y,1.7),(.035,1.5,1.05),'Warm shell','Signage',.06)
        for i in [-1,1]:
            leaf=sphere('Orchard emblem • abstract leaf',(x-side*.03,y+i*.13,1.90+i*.06),(.022,.15,.075),'Mint','Signage',12)
            leaf.rotation_euler.x=i*.45
        # Text on side wall rotated to face inward.
        text('Garden sector marker','GARDEN\nCIRCUIT',(x-side*.035,y,1.58),.17,'Ink',(math.pi/2,0,math.pi/2 if side==-1 else -math.pi/2))
    # Low guide fins at split entries reinforce routes without closing them.
    for side in [-1,1]:
        for x in [-4.25,4.25]:
            box('Route split • low cover fin',(x,side*8.0,.17),(.30,1.5,.34),'Porcelain','Props',.10)
    print('STAGE 3: layered skyline, orchard trees, original signage, hub landmarks, route split cover.')


def camera(name,loc,target,lens=28,ortho=None):
    d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);coll('Review cameras').objects.link(o)
    o.location=loc;o.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_end=300;d.clip_start=.02
    if ortho:d.type='ORTHO';d.ortho_scale=ortho
    return o

def stage4():
    bpy.context.window.scene=scene();s=scene()
    world=bpy.data.worlds.new('Garden Circuit • clear afternoon');world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.48,.68,.9,1);bg.inputs['Strength'].default_value=.45;s.world=world
    ld=bpy.data.lights.new('Afternoon sun','SUN');lo=bpy.data.objects.new('Afternoon sun',ld);coll('Lighting').objects.link(lo);ld.energy=2.2;ld.angle=.08
    lo.rotation_euler=(math.radians(28),math.radians(-25),math.radians(-28))
    ld=bpy.data.lights.new('Courtyard skylight','AREA');lo=bpy.data.objects.new('Courtyard skylight',ld);coll('Lighting').objects.link(lo);lo.location=(0,0,11);ld.energy=1900;ld.shape='DISK';ld.size=18
    cams=[camera('01 • Arena overview',(19,-24,19),(0,0,1.0),32),camera('02 • Robot eye / hill approach',(0,-5.0,.45),(0,1,.7),20),camera('03 • Tiny bot beside human bench',(-4.5,1.1,.45),(-2.3,3.5,.6),24),camera('04 • Gallery flank',(6.2,-5.5,1.28),(0,0,.35),23),camera('05 • Team dock eye level',(1.15,-10.7,.53),(2.5,-7,.65),22),camera('06 • Tactical overhead',(0,0,30),(0,0,0),40,28)]
    s.camera=cams[0];s.render.engine=bpy.data.scenes['Apple Legends — Asset Workshop'].render.engine
    s.render.resolution_x=1400;s.render.resolution_y=1050;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG'
    s.render.film_transparent=False
    # Use the actual installed color transform rather than guessing its identifier.
    s.view_settings.view_transform=bpy.data.scenes['Apple Legends — Asset Workshop'].view_settings.view_transform
    # Simple hidden collision source kit. Gameplay scene integration is intentionally later.
    cp=coll('Collision proxies');cp.hide_render=True;cp.hide_viewport=True
    for o in list(s.objects):
        if o.type=='MESH' and (o.name.startswith(('Garden court continuous','Gallery access ramp','Garden gallery • walkable','Human campus boundary','Spawn campus facade'))):
            dup=o.copy();dup.name='COLLISION • '+o.name;cp.objects.link(dup);dup.display_type='WIRE';dup.hide_render=True
    # Store review notes inside Blender; pack both user references into this file.
    note=bpy.data.texts.new('START HERE • Garden Circuit review')
    note.write('APPLE LEGENDS / A1 GARDEN CIRCUIT\n\nOriginal Blender arena for eventual 3v3 King of the Hill.\n18 x 24 m footprint. Robot reference height ~0.55 m. Human bench seat ~0.45 m; human doors 2.2 m.\nTwo raised galleries at 0.85 m, each approached by two ~10.7-degree ramps.\nNeutral central capture ring radius 1.8 m. Six spawn markers behind fire screens. Two optional pickup sockets.\n\nREVIEW: Numpad 0 for active camera. Camera list contains overview, robot eye, bench scale, flank, docks, and tactical overhead.\nRobot scale reference is a review-only collection. Gameplay markers are named empties, not working game logic.\nCollision proxies are hidden and only an initial structural kit; remaining prop collision must be built during Godot integration.\n\nAll map geometry and foliage are original. Robot/bench/charger/pod reuse this project\'s original Blender source. Reference images are packed image datablocks.\nBlender meters are presentation scale. Suggested export conversion ~3.226 game units per meter; do not silently change the accepted Godot controller.\nThe full jump in current game would be ~1.84 m at this convention: test shortcut and roof access on integration.\nNo KOTH scripting, bot navigation, team combat, or networking is included in this art review.\n')
    for p in [OUT.parent/'references/mini-bots-primary.png',OUT.parent/'references/mini-bots-personality.png']:
        img=bpy.data.images.load(str(p),check_existing=True);img.pack()
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            sp=area.spaces.active;sp.shading.type='MATERIAL';sp.overlay.show_overlays=False;sp.clip_end=250
            sp.region_3d.view_location=(0,0,1);sp.region_3d.view_distance=32
            sp.region_3d.view_rotation=cams[0].rotation_euler.to_quaternion();sp.region_3d.view_perspective='PERSP'
    bpy.ops.object.select_all(action='DESELECT')
    # Everything is isolated in its own scene; old source scenes remain intact.
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Apple_Legends_Garden_Circuit.blend'))
    print('STAGE 4: saved editable arena, six review cameras, packed concept boards, markers, structural collision kit.')

if BUILD_STAGE==1:stage1()
elif BUILD_STAGE==2:stage2()
elif BUILD_STAGE==3:stage3()
elif BUILD_STAGE==4:stage4()
