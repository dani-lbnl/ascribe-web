// Vendored from vr-start shaders/raymarching.gdshader (as of c45c7ce, "Overhaul raymarching
// shader: correct compositing, interval clipping, jitter, optional shading"). Note this is the
// overhauled root-level shader, NOT addons/volume_layered_shader/shaders/volume_shader.gdshader,
// which is the older copy this viewer originally vendored.
//
// Local changes:
// - `zoom` is replaced by `box_extents`: SpecimenStage stages non-cubic volumes in a box whose
//   largest axis is 1m, so the texture has to be normalized per-axis rather than by one scalar.
// - filter_linear instead of filter_linear_mipmap (no mipmaps are generated; WebGL2 mipmap
//   filtering of a mipless texture is undefined-ish).
// - the march step widens when max_steps * step_size cannot span the clipped interval, so a
//   volume is never truncated part-way through (the opacity correction follows the step
//   actually used, so density stays consistent).
// - the per-eye offset comes from an `eye_offsets` uniform indexed by VIEW_INDEX rather than
//   from EYE_OFFSET, which cannot be named at all under Godot 4.6's Compatibility (GLES3)
//   backend without breaking the mono shader variant. See the note in vertex().
shader_type spatial;
render_mode unshaded, cull_front, blend_premul_alpha;

const int MAX_EXCLUSION_PLANES = 4;
// Opacity is calibrated against this step size; changing step_size only
// changes quality, not the rendered density.
const float REFERENCE_STEP = 0.005;

uniform int max_steps = 256;
uniform float step_size = 0.005;

uniform sampler3D texture_volume : source_color, filter_linear, repeat_disable;
uniform sampler2D gradient : filter_linear, repeat_disable;
uniform float opacity = 1.0;
uniform float gamma = 1.0;
uniform float color_scalar = 1.0;
// Half-extents (in object space) of the box the volume is staged in. 0.5 on every axis is a
// unit cube; SpecimenStage overrides this per-specimen so an anisotropic volume fills its box
// exactly on every axis instead of being stretched.
uniform vec3 box_extents = vec3(0.5, 0.5, 0.5);
uniform int num_exclusion_planes = 0;
// Planes in object (mesh-local) space; kept region is dot(p, xyz) <= w.
uniform vec4[MAX_EXCLUSION_PLANES] exclusion_planes;

// Smooths the hardware's trilinear reconstruction (see quintic_texel_coord). Off by default:
// on the close-up tested so far it made no measurable difference to the banding, so it is not
// worth the per-sample cost until a view is found where it helps.
uniform bool smooth_sampling = false;

// Diagnostic: reconstruct the volume with a manual trilinear blend (8 texelFetch + float32
// lerps) instead of the hardware sampler. Hardware texture filtering interpolates with
// fixed-point weights -- classically 8 bits of subtexel precision -- so a magnified texture
// reconstructs as ~256 discrete steps between adjacent texels, which shows up as banding.
// Doing the blend in the shader runs at full float precision. Costs 8 fetches per sample, so
// this exists to identify the artifact, not to ship enabled.
uniform bool manual_filter = false;

// Diagnostic: scale of the per-ray start jitter (1.0 = one full march step, 0.0 = none).
// With jitter off, sampling-phase error becomes coherent banding instead of fine noise, which
// distinguishes "sampling position" artifacts from "reconstruction" artifacts.
uniform float jitter_amount = 1.0;

uniform bool shading_enabled = false;
// Light direction in object space.
uniform vec3 light_dir = vec3(0.5, 0.7, 0.5);
uniform float ambient = 0.4;

// Per-view eye offset in view space, pushed by SpecimenStage while an XR session is running;
// both entries stay zero on desktop. See the note in vertex() for why this is not EYE_OFFSET.
uniform vec3 eye_offsets[2];

varying vec3 pos_local;
varying vec3 eye_pos_local;


void vertex() {
	pos_local = VERTEX;

	// Per-eye camera position in object space, so the fragment shader needs no matrix inverses.
	//
	// Upstream writes `(INV_VIEW_MATRIX * vec4(EYE_OFFSET, 1.0)).xyz`, but EYE_OFFSET cannot be
	// named here at all: Godot 4.6's Compatibility (GLES3) backend only declares `eye_offset` in
	// the multiview shader variant, so the mono variant fails to compile and nothing draws in a
	// normal browser tab. Dropping it entirely compiled, but then both eyes marched from the
	// same origin -- the image was identical in each eye, i.e. no stereo at all.
	//
	// VIEW_INDEX *does* compile in both variants, so the offsets come in as a uniform array
	// instead and are indexed per view. inverse(MODELVIEW_MATRIX) == inverse(MODEL) *
	// inverse(VIEW), so this is algebraically the same as upstream's two-step transform.
	eye_pos_local = (inverse(MODELVIEW_MATRIX) * vec4(eye_offsets[VIEW_INDEX], 1.0)).xyz;
}


// Clip the ray interval [t_near, t_far] to an axis-aligned box of the given
// half extents centered at the origin.
void clip_to_box(vec3 ro, vec3 rd, vec3 half_extents, inout float t_near, inout float t_far) {
	vec3 t_a = (-half_extents - ro) / rd;
	vec3 t_b = ( half_extents - ro) / rd;
	vec3 t_lo = min(t_a, t_b);
	vec3 t_hi = max(t_a, t_b);
	t_near = max(t_near, max(max(t_lo.x, t_lo.y), t_lo.z));
	t_far = min(t_far, min(min(t_hi.x, t_hi.y), t_hi.z));
}


// Reshape the position *within* a texel so the hardware's trilinear blend becomes smooth
// across voxel boundaries.
//
// Trilinear interpolation is continuous but its derivative is not: it kinks at every voxel
// boundary. Where a surface crosses the grid at a shallow angle those kinks line up into
// ridges whose spacing is the voxel pitch -- banding that does not move when you change the
// ray step size, because it is a property of the reconstruction, not of the sampling.
// Applying the quintic smoothstep 6t^5-15t^4+10t^3 to the in-texel fraction makes the
// interpolant C1-continuous, so the ridges have nothing to line up on.
vec3 quintic_texel_coord(vec3 uvw) {
	vec3 res = vec3(textureSize(texture_volume, 0));
	vec3 p = uvw * res - 0.5;
	vec3 base = floor(p);
	vec3 f = p - base;
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return (base + 0.5 + f) / res;
}


// Trilinear blend done in the shader at full float precision, bypassing the hardware sampler's
// fixed-point interpolation weights. See the `manual_filter` uniform.
float sample_volume_manual(vec3 uvw) {
	vec3 res = vec3(textureSize(texture_volume, 0));
	vec3 p = uvw * res - 0.5;
	vec3 base = floor(p);
	vec3 f = p - base;
	ivec3 i0 = ivec3(base);
	ivec3 hi = ivec3(res) - ivec3(1);

	float c000 = texelFetch(texture_volume, clamp(i0 + ivec3(0, 0, 0), ivec3(0), hi), 0).r;
	float c100 = texelFetch(texture_volume, clamp(i0 + ivec3(1, 0, 0), ivec3(0), hi), 0).r;
	float c010 = texelFetch(texture_volume, clamp(i0 + ivec3(0, 1, 0), ivec3(0), hi), 0).r;
	float c110 = texelFetch(texture_volume, clamp(i0 + ivec3(1, 1, 0), ivec3(0), hi), 0).r;
	float c001 = texelFetch(texture_volume, clamp(i0 + ivec3(0, 0, 1), ivec3(0), hi), 0).r;
	float c101 = texelFetch(texture_volume, clamp(i0 + ivec3(1, 0, 1), ivec3(0), hi), 0).r;
	float c011 = texelFetch(texture_volume, clamp(i0 + ivec3(0, 1, 1), ivec3(0), hi), 0).r;
	float c111 = texelFetch(texture_volume, clamp(i0 + ivec3(1, 1, 1), ivec3(0), hi), 0).r;

	float c00 = mix(c000, c100, f.x);
	float c10 = mix(c010, c110, f.x);
	float c01 = mix(c001, c101, f.x);
	float c11 = mix(c011, c111, f.x);
	return mix(mix(c00, c10, f.y), mix(c01, c11, f.y), f.z);
}


// Estimate the volume-density normal via central differences, in texture space.
vec3 density_normal(vec3 uvw) {
	vec3 eps = 1.0 / vec3(textureSize(texture_volume, 0));
	float dx = texture(texture_volume, uvw + vec3(eps.x, 0.0, 0.0)).r
	         - texture(texture_volume, uvw - vec3(eps.x, 0.0, 0.0)).r;
	float dy = texture(texture_volume, uvw + vec3(0.0, eps.y, 0.0)).r
	         - texture(texture_volume, uvw - vec3(0.0, eps.y, 0.0)).r;
	float dz = texture(texture_volume, uvw + vec3(0.0, 0.0, eps.z)).r
	         - texture(texture_volume, uvw - vec3(0.0, 0.0, eps.z)).r;
	return vec3(dx, dy, dz);
}


void fragment() {
	vec3 ro = eye_pos_local;
	vec3 rd = normalize(pos_local - eye_pos_local);

	// Clip the ray to the staged box. Texture coordinates are normalized by the same extents,
	// so this one clip also keeps every sample inside [0, 1].
	float t_near = 0.0;
	float t_far = 1e20;
	clip_to_box(ro, rd, box_extents, t_near, t_far);

	// The kept region of the exclusion planes (dot <= w for every plane) is
	// convex, so it clips the interval exactly — no per-step tests needed.
	for (int i = 0; i < num_exclusion_planes; ++i) {
		vec4 plane = exclusion_planes[i];
		float denom = dot(rd, plane.xyz);
		float dist = plane.w - dot(ro, plane.xyz);
		if (abs(denom) < 1e-6) {
			if (dist < 0.0)
				t_far = -1.0; // origin excluded, ray parallel: nothing kept
		} else if (denom > 0.0) {
			t_far = min(t_far, dist / denom);
		} else {
			t_near = max(t_near, dist / denom);
		}
	}

	if (t_far <= t_near)
		discard;

	// Jitter the ray start (interleaved gradient noise) to break up the
	// banding of fixed-step sampling.
	float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))))
		* jitter_amount;

	// max_steps * step_size is not guaranteed to span the clipped interval -- the desktop tier
	// reaches 1.28 but a 1m staged volume's diagonal can be ~1.39, so corner-on views would
	// drop the far side. Widen the step when the ray is longer than the budget covers, which
	// trades a little sampling detail for never truncating the volume.
	float span = max(t_far - t_near, 0.0);
	float march_step = max(step_size, span / float(max_steps));

	// Opacity correction keeps density independent of step size.
	float step_ratio = march_step / REFERENCE_STEP;
	vec3 accumulated_color = vec3(0.0);
	float total_opacity = 0.0;

	for (int i = 0; i < max_steps; ++i) {
		float t = t_near + (float(i) + jitter) * march_step;
		if (t > t_far)
			break;

		vec3 ray_pos = ro + rd * t;
		vec3 tex_sample_pt = (ray_pos / (2.0 * box_extents)) + vec3(0.5);

		vec3 sample_pt = smooth_sampling ? quintic_texel_coord(tex_sample_pt) : tex_sample_pt;
		float density = manual_filter
			? sample_volume_manual(sample_pt)
			: texture(texture_volume, sample_pt).r;
		vec4 sample = texture(gradient, vec2(pow(density, gamma), 0.5));

		float sample_opacity = 1.0 - pow(1.0 - clamp(sample.a * opacity, 0.0, 1.0), step_ratio);

		if (shading_enabled && sample_opacity > 0.001) {
			vec3 n = density_normal(tex_sample_pt);
			if (dot(n, n) > 1e-8) {
				float diffuse = max(dot(normalize(n), normalize(light_dir)), 0.0);
				sample.rgb *= ambient + (1.0 - ambient) * diffuse;
			}
		}

		accumulated_color += sample.rgb * sample_opacity * (1.0 - total_opacity);
		total_opacity += sample_opacity * (1.0 - total_opacity);

		if (total_opacity >= 0.95)
			break;
	}

	// The march accumulates colour already weighted by each sample's opacity, so the output is
	// premultiplied. blend_premul_alpha composites that as `src.rgb + dst * (1 - src.a)`, which
	// is exactly right; plain alpha blending would multiply by alpha a second time, darkening
	// everything in proportion to its own transparency and amplifying sampling variation.
	ALBEDO = accumulated_color * color_scalar;
	ALPHA = total_opacity;
}
