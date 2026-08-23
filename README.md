# ascribe-web

A browser-based viewer for volumetric and mesh data with accompanying story narratives. The **ascribe-web** system combines a WebGL2-compatible Godot viewer with static hosting support, allowing scientific volumes and meshes to be explored interactively through a web browser without server-side processing. The viewer supports both desktop (mouse/keyboard) and WebXR headset interaction modes.

To build a bundle for hosting, use the `ascribe-bundle` Python CLI: `ascribe-bundle build data.npy --story story.md --title "My Data" -o out/`. Then copy the generated `out/` directory to your static web host. The bundle format is self-contained (manifest + data envelopes) and loads seamlessly in the viewer without CORS complications.
