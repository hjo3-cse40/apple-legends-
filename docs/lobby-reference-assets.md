# Reference-style lobby assets

Built-in image_gen edit mode was used with the user-selected lobby reference. All UI is implemented as Godot controls; the background and central lobby portrait are raster assets, not a baked UI. Combat models and map geometry are unchanged.

Saved asset paths:
- /Users/samjo/Documents/Codex/2026-10-03/for-the-apple-legends-i-wanna/work/apple-legends-expanded/art/lobby/garden-lobby-backdrop.png
- /Users/samjo/Documents/Codex/2026-10-03/for-the-apple-legends-i-wanna/work/apple-legends-expanded/art/lobby/porcelain-robot-portrait.png

Backdrop prompt:
Edit target: attached Apple Legends lobby reference. Create ONLY the clean background plate for the interactive game lobby. Remove ALL UI, text, panels, cards, buttons, icons, overlays AND the central robot completely. Preserve the bright white futuristic garden campus, rounded buildings, green trees, blue sky, camera angle, pastel cinematic 3D style, and the central white circular pedestal with cyan glowing rim. Fill removed regions naturally with continuing garden environment. Wide 16:9 composition identical to source. No text, no characters, no UI anywhere. Pedestal top stays at about 65% image height, empty for our live 3D robot. This is a background asset, not a new UI mockup.

Portrait prompt:
Edit target reference image. Extract only the central full-body white porcelain robot character, preserving its exact appearance: rounded white head, glossy black face two cyan eyes, articulated white arms hands torso and legs with black joints, cyan shoulder/knee details, same friendly confident three-quarter stance and polished 3D shading. Render the robot alone as a clean full-body game lobby portrait on a truly transparent background. No pedestal, no shadow outside feet, no buildings, no UI, no text. Keep whole robot from head to feet and close crop. Preserve proportions and style from source exactly.

Final implementation uses the matching illustrated portrait instead of a 3D lobby render; a shader recolors cyan accents for the selected team. Both 720p disconnected and 1080p connected layouts were rendered and inspected. The screenshot party includes a labelled synthetic second human for preview. Actual UI tests verify 1v1/2v2/3v3, team choice, ready, partial match start, removal, return/leave and fill-on-start. Version rejection was also checked with two processes.
