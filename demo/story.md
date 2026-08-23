# The Gyroid Sphere

This is a **procedurally generated** demo specimen: a soft sphere modulated by a *gyroid* minimal
surface, baked into a 64x64x64 volume by `gen_demo_volume.py`.

It exists to give the ascribe-web viewer something visually interesting to load without needing
real scientific data on hand.

---

## Gyroids

A gyroid is an infinitely connected, triply periodic minimal surface. Here it's approximated with
a simple trig formula, then multiplied against a spherical falloff so only the central region
survives.

*Rotate the specimen* with the mouse (desktop) or grab it with a controller (WebXR) to see the
internal structure.

---
@specimen specimen_0
## Try the controls

Use the display settings panel to adjust **gamma**, **opacity**, and render quality. In WebXR,
point the controller trigger at the panel to click, and the left controller's B/Y button toggles
it.

This page re-pins `specimen_0` explicitly, exercising the story panel's specimen-pin wiring even
though it's the only specimen in this demo bundle.
