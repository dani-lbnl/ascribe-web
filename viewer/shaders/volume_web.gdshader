// Vendored from vr-start addons/volume_layered_shader/shaders/volume_shader.gdshader (1.1.0); local changes noted below.
// - max_steps/step_size are now uniforms instead of consts (runtime quality control).
// - texture_volume/gradient use filter_linear instead of filter_linear_mipmap (no mipmaps generated; WebGL2 mipmap filtering of a mipless texture is undefined-ish).
// - removed the stereo debug tint (VIEW_INDEX == VIEW_RIGHT green tint) at the end of fragment().
// - removed the unused `layers` uniform.
shader_type spatial;
render_mode unshaded, cull_front;

const int MAX_EXCLUSION_PLANES = 4;

uniform sampler3D texture_volume : source_color, filter_linear, repeat_disable;
uniform sampler2D gradient : filter_linear, repeat_disable;
uniform float zoom = 2;
uniform float opacity = 1;
uniform float gamma = 1;
uniform float color_scalar = 1;
uniform int max_steps = 128;
uniform float step_size = 0.01;
// Half-extents (in local/object space) of the box the volume is staged in. Defaults to 0.5,
// matching the original unit-cube assumption -- SpecimenStage overrides this per-specimen for
// anisotropic (non-cubic) volumes so the texture fills the box exactly on every axis instead of
// getting stretched/squashed.
uniform vec3 box_extents = vec3(0.5, 0.5, 0.5);
uniform int num_exclusion_planes = 0;
uniform vec4[MAX_EXCLUSION_PLANES] exclusion_planes;

varying vec3 pos_local;
varying vec3 pos_world;
varying mat3 inv_model_rotation; // Precomputed rotation matrix
varying vec3 inv_model_translation; // Precomputed translation vector
varying vec3 world_camera;
varying vec3 world_position;

void vertex() {
    world_position = VERTEX;
    world_camera = (inverse(MODELVIEW_MATRIX) * vec4(0, 0, 0, 1)).xyz; //object space
    //world_camera = ( CAMERA_MATRIX  * vec4(0, 0, 0, 1)).xyz; //uncomment this to raymarch in world space
    world_camera += EYE_OFFSET;
}

// Function to check if a point is outside of an exclusion plane
bool is_outside_exclusion_planes(vec3 point) {
    for (int i = 0; i < num_exclusion_planes; ++i) {
        // Exclusion planes are stored in vec4 (x, y, z) as the normal and w as the distance
        vec4 plane = exclusion_planes[i];
        // Dot product between point and plane normal and check if it's greater than the plane's distance
        if (dot(point, plane.xyz) > plane.w) {
            return true; // Point is outside this exclusion plane
        }
    }
    return false;
}

// Raymarching function
vec4 raymarch(vec3 ray_origin, vec3 ray_dir) {
    vec4 accumulated_color = vec4(0.0, 0.0, 0.0, 0.0);
    float total_opacity = 0.0;

    for (int i = 0; i < max_steps; ++i) {
        // Step along the ray
        ray_origin += ray_dir * step_size;

        // Sample the texture volume. Each axis is normalized by its own half-extent so the
        // volume fills the (possibly non-cubic) box exactly, instead of assuming a unit cube.
        vec3 tex_sample_pt = ((ray_origin / (2.0 * box_extents)) * zoom) + vec3(0.5, 0.5, 0.5);

        // Skip invalid samples
        if (any(lessThan(tex_sample_pt, vec3(0.0))) || any(greaterThan(tex_sample_pt, vec3(1.0))))
            break;

        // Check if the current point is outside of any exclusion planes
        if (is_outside_exclusion_planes(ray_origin)) {
            continue; // Skip this sample if it's outside of an exclusion plane
        }

        vec4 sample = texture(texture_volume, tex_sample_pt);
        sample = texture(gradient, vec2(pow(sample.r, gamma), 0));

        // Accumulate color and opacity
        float sample_opacity = sample.a * opacity;
        accumulated_color.rgb += sample.rgb * sample_opacity * (1.0 - total_opacity);
        total_opacity += sample_opacity;

        // If the opacity reaches 1, we can break out early
        if (total_opacity >= 1.0)
            break;
    }

    accumulated_color.a = total_opacity;
    return accumulated_color;
}

void fragment() {
    vec3 ro = world_camera;
    vec3 rd = normalize(world_position - ro);

    // The box is centered at (0, 0, 0) with half-extents `box_extents` (0.5 = a unit cube; set
    // per-specimen by SpecimenStage to match the staged BoxMesh's actual size).

    // Ray-box intersection logic to clamp ray origin to the surface of the box
    vec3 t_min = ( -box_extents - ro ) / rd; // Compute entry point of the ray
    vec3 t_max = ( box_extents - ro ) / rd;  // Compute exit point of the ray

    // Ensure t_min is less than t_max
    vec3 t_near = min(t_min, t_max);
    vec3 t_far = max(t_min, t_max);

    // Find the largest of the entry points to determine where the ray first enters the box
    float t_entry = max(max(t_near.x, t_near.y), t_near.z);
    // The ray origin should be adjusted to this entry point
    ro += rd * t_entry;

    // Now perform raymarching from the adjusted origin
    vec4 col = raymarch(ro, rd);

    // Apply color scalar
    col *= color_scalar;

    ALBEDO = col.rgb;
    ALPHA = col.a;
}
