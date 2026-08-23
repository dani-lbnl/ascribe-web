# ascribe-web

A browser-based viewer for volumetric and mesh data with accompanying story narratives. The
**ascribe-web** system combines a WebGL2-compatible Godot viewer with static hosting support,
allowing scientific volumes and meshes to be explored interactively through a web browser without
server-side processing. The viewer supports both desktop (mouse/keyboard) and WebXR headset
interaction modes.

## Author workflow: building and publishing a bundle

### 1. Set up the bundler

```powershell
cd bundler
python -m venv ..\.venv
..\.venv\Scripts\activate
pip install -e .
```

(`.venv` lives at the repo root so it's shared by anything else that needs it; there's no `uv`
here, just a vanilla venv.)

### 2. Bake a bundle

```powershell
ascribe-bundle build data.npy --story story.md --title "My Data" -o out/
```

- `data.npy` (or `.tif`/`.tiff`) is a 3D volume array. It can be any numeric dtype on disk --
  the CLI converts it to a web-safe dtype for you (default `float16`; pass `--dtype u8` for an
  8-bit volume, which halves the payload size at the cost of dynamic range).
- `--story story.md` is optional. Pages are split on lines containing only `---`. A page can pin
  a specimen by starting with `@specimen <id>` (the pin persists until a later page pins a
  different one). Standard markdown (`#`/`##` headers, `**bold**`, `*italic*`,
  `![alt](image.png)`) is supported and converted to BBCode by the viewer at load time.
- `--max-dim N` downsamples any axis larger than `N` voxels (uniform stride) -- useful for keeping
  bundle size down.
- `--size-warn-mb N` (default 100) prints a warning, not an error, if the baked bundle exceeds it.
- `-o out/` is the output directory: `manifest.json` + one `.bin` envelope per specimen, plus any
  images referenced by the story, copied alongside.

Run `ascribe-bundle inspect out/` to validate an existing bundle and print its manifest plus each
specimen's decoded envelope header.

### 3. Preview locally

The viewer's `res://tests/fixtures/tiny_bundle` fixture bundle is baked into the exported web
build for offline testing, but to preview a real bundle you need a same-origin HTTP server (the
viewer never assumes CORS):

```powershell
cd build\web
python -m http.server 8060
```

Then open `http://localhost:8060/index.html?bundle=../../out` (or copy your bundle's `out/`
directory next to `index.html` first and use a relative `?bundle=` path — see below).

### 4. Deploy

The exported `build/web/` directory is fully static: copy it, plus one or more bundle directories,
to any static host (GitHub Pages, S3 + CloudFront, an internal file server, `python -m
http.server` for a LAN demo, etc.) preserving relative paths. Load a specific bundle with the
`?bundle=` query parameter, e.g.:

```
https://your-host.example/index.html?bundle=demo_bundle
```

`?bundle=` is resolved relative to `index.html`'s own URL (same-origin, no CORS needed). Omitting
it falls back to the bundle baked into the exported `.pck` (the test fixture, for a bare desktop
smoke-test).

This repo ships a demo bundle at `build/web/demo_bundle/` (also kept at `demo/bundle/` alongside
the numpy generator that produced it, `demo/gen_demo_volume.py`, and its story, `demo/story.md`) --
load it with `?bundle=demo_bundle` against the exported build.

## Rebuilding the viewer

```powershell
& "<path to Godot_v4.6-stable_win64_console.exe>" --headless --path viewer --export-release Web ../build/web/index.html
```

Godot 4.6, Compatibility renderer, single-threaded web export (no COOP/COEP headers required by
the host). A benign segfault after "Saving resource cache" during headless export is expected and
does not indicate export failure -- check that the export artifacts were actually written/updated.

## Running tests

Bundler (pytest):

```powershell
.venv\Scripts\python -m pytest bundler
```

Viewer (gdUnit4, headless):

```powershell
& "<path to Godot_v4.6-stable_win64_console.exe>" --headless --path viewer -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

## Roadmap / limitations

- **Building directly from a running ascribe-link server is not yet implemented.** The bundler CLI
  (`ascribe-bundle build`) only accepts local files -- a `.npy`/`.tif`/`.tiff` volume array, or a
  pre-baked `.bin` envelope. There is no "point the CLI at a specimen ID on a live server" workflow
  yet; that would require an ascribe-link client and is left for a future iteration.
