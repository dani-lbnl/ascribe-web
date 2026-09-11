## Loads an ascribe-web content bundle (manifest.json + envelope-encoded specimen blobs).
##
## Two transports, selected by `base_url`:
##   - "res://..."  -> read synchronously via FileAccess (used by tests and any bundle shipped
##                     inside the exported pck). Still emits the same signals as the http path.
##   - anything else (a relative path, or an http(s) URL) -> fetched via HTTPRequest children.
##     URLs are always used relative to the current page (no CORS assumptions).
##
## On any failure at any stage, `failed(message)` is emitted with a human-readable message that
## names the offending file; `loaded` is never emitted after a failure.
class_name BundleLoader
extends Node

signal progress(stage: String, ratio: float)
signal loaded(manifest: Dictionary, specimens: Dictionary)
signal failed(message: String)

const MANIFEST_FILE := "manifest.json"


## Validates a parsed manifest dictionary. Returns "" if valid, else a human-readable error.
## Mirrors the bundler CLI's validate_manifest: version must be 1, specimens/story must be
## arrays, and every story page's `specimen` pin must reference a known specimen id.
static func validate_manifest(manifest: Dictionary) -> String:
	if not manifest.has("version"):
		return "manifest is missing 'version'"
	if int(manifest.get("version", -1)) != 1:
		return "unsupported manifest version %s (expected 1)" % [str(manifest.get("version"))]
	if not (manifest.get("specimens") is Array):
		return "manifest is missing a 'specimens' array"
	if not (manifest.get("story") is Array):
		return "manifest is missing a 'story' array"

	var specimen_ids := {}
	for spec in manifest["specimens"]:
		if not (spec is Dictionary) or not spec.has("id"):
			return "a specimen entry is missing 'id'"
		specimen_ids[spec["id"]] = true

	for page in manifest["story"]:
		if not (page is Dictionary):
			return "a story entry is not an object"
		var pin = page.get("specimen", null)
		if pin != null and not specimen_ids.has(pin):
			return "unknown specimen '%s' referenced in story" % [str(pin)]

	return ""


## Loads the bundle at `base_url` (a directory containing manifest.json and its data files).
func load_bundle(base_url: String) -> void:
	if base_url.begins_with("res://"):
		await _load_from_res(base_url)
	else:
		await _load_from_http(base_url)


func _join(base_url: String, name: String) -> String:
	if base_url.ends_with("/"):
		return base_url + name
	return base_url + "/" + name


func _load_from_res(base_url: String) -> void:
	var manifest_path := _join(base_url, MANIFEST_FILE)
	progress.emit("manifest", 0.0)

	if not FileAccess.file_exists(manifest_path):
		failed.emit("failed to read %s: file not found" % [manifest_path])
		return

	var text := FileAccess.get_file_as_string(manifest_path)
	var manifest = JSON.parse_string(text)
	if manifest == null or not (manifest is Dictionary):
		failed.emit("%s: invalid JSON" % [MANIFEST_FILE])
		return

	progress.emit("manifest", 1.0)
	await _finish_load(manifest, func(rel_path: String) -> Variant:
		var full_path := _join(base_url, rel_path)
		if not FileAccess.file_exists(full_path):
			return {"error": "failed to read %s: file not found" % [rel_path]}
		return {"body": FileAccess.get_file_as_bytes(full_path)}
	)


func _load_from_http(base_url: String) -> void:
	var manifest_url := _join(base_url, MANIFEST_FILE)
	progress.emit("manifest", 0.0)

	var manifest_result := await _http_get(manifest_url)
	if manifest_result.has("error"):
		failed.emit("failed to fetch %s: %s" % [MANIFEST_FILE, manifest_result["error"]])
		return

	var manifest = JSON.parse_string(manifest_result["body"].get_string_from_utf8())
	if manifest == null or not (manifest is Dictionary):
		failed.emit("%s: invalid JSON" % [MANIFEST_FILE])
		return

	progress.emit("manifest", 1.0)
	await _finish_load(manifest, func(rel_path: String) -> Variant:
		var result := await _http_get(_join(base_url, rel_path))
		if result.has("error"):
			return {"error": "failed to fetch %s: %s" % [rel_path, result["error"]]}
		return result
	)


## Shared validation + specimen decode loop, parameterized by a `fetch(rel_path) -> Dictionary`
## callable that returns {"body": PackedByteArray} or {"error": String}.
func _finish_load(manifest: Dictionary, fetch: Callable) -> void:
	var err := validate_manifest(manifest)
	if err != "":
		failed.emit("%s: %s" % [MANIFEST_FILE, err])
		return

	var specimens := {}
	for spec in manifest["specimens"]:
		var spec_id: String = spec.get("id", "")
		var rel_path: String = spec.get("data", "")
		progress.emit(spec_id, 0.0)

		var fetched = await fetch.call(rel_path)
		if fetched.has("error"):
			failed.emit(fetched["error"])
			return

		var body: PackedByteArray = fetched["body"]
		progress.emit(spec_id, 0.5)

		var obj = await _decode_specimen(spec, body)
		if obj == null:
			failed.emit("failed to decode %s: invalid or unsupported envelope" % [rel_path])
			return

		specimens[spec_id] = obj
		progress.emit(spec_id, 1.0)

	loaded.emit(manifest, specimens)


## Decodes one specimen's envelope body into a WebVolumetricData or WebMeshData, or null on
## any failure. Volume decode batches across frames via WebVolumetricData.build_async.
func _decode_specimen(spec: Dictionary, body: PackedByteArray) -> Variant:
	var parsed := BinaryEnvelope.parse(body)
	if parsed.has("error"):
		push_error(parsed["error"])
		return null

	var preamble: Dictionary = parsed["preamble"]
	var offset: int = parsed["offset"]
	var kind: String = spec.get("type", "")

	if kind == "volume":
		var vol := WebVolumetricData.new()
		var ok: bool = await vol.build_async(preamble, body, offset, get_tree())
		return vol if ok else null

	if kind == "mesh":
		var mesh := WebMeshData.new()
		return mesh if mesh.set_from_bytes(preamble, body, offset) else null

	push_error("BundleLoader: unknown specimen type '%s'" % [kind])
	return null


## Builds an HTTPRequest configured the way every bundle fetch needs it.
##
## `accept_gzip` must stay off. On web the browser transparently decompresses a gzipped
## response before Godot ever sees the body, but HTTPRequest still reads the
## `Content-Encoding: gzip` header and tries to inflate it a second time -- that fails inside
## stream_peer_gzip and hands back garbage, which surfaces as "manifest.json: invalid JSON".
## A local `python -m http.server` never compresses, so this only appears on a real static
## host; GitHub Pages gzips JSON by default.
func make_request() -> HTTPRequest:
	var request := HTTPRequest.new()
	request.accept_gzip = false
	return request


## Performs a single HTTPRequest GET, returning {"body": PackedByteArray} on 2xx, or
## {"error": String} otherwise. Always relative-safe: the caller passes a same-origin URL.
func _http_get(url: String) -> Dictionary:
	var request := make_request()
	add_child(request)
	var start_err := request.request(url)
	if start_err != OK:
		request.queue_free()
		return {"error": "could not start request (error %d)" % [start_err]}

	var result: Array = await request.request_completed
	request.queue_free()

	var response_code: int = result[1]
	var body: PackedByteArray = result[3]
	if response_code < 200 or response_code >= 300:
		return {"error": "HTTP %d" % [response_code]}
	return {"body": body}
