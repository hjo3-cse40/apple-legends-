import bpy,sys,json
from pathlib import Path
s=bpy.data.scenes['A1 • Garden Circuit • 3v3 KOTH'];bpy.context.window.scene=s
out=Path('/Users/samjo/Documents/Codex/2026-10-02/reg/outputs/garden-circuit')
# Native EEVEE review renders; original file remains untouched.
s.render.resolution_x=1440;s.render.resolution_y=960;s.render.resolution_percentage=100
if hasattr(s,'eevee'):s.eevee.taa_render_samples=128
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['01','02','03','06']
for prefix in args:
    cam=next(o for o in s.objects if o.type=='CAMERA' and o.name.startswith(prefix))
    roof=bpy.data.collections['GC • Roof canopies • hide for tactical review']
    roof.hide_render=(prefix=='06')
    s.camera=cam;s.render.filepath=str(out/(prefix+'-review.png'))
    bpy.ops.render.render(write_still=True)
    print('RENDERED',prefix,flush=True)
