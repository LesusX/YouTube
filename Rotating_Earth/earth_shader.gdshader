shader_type spatial;

uniform sampler2D day_texture; // Daytime Earth texture
uniform sampler2D night_texture; // Nighttime Earth texture
uniform sampler2D cloud_texture; // Clouds texture
uniform sampler2D specular_map; // Specular map for water/land distinction

uniform vec3 light_direction; // Direction of the light
uniform float blend_smoothness = 0.05; // Transition between day and night
uniform float cloud_opacity = 0.9; // Maximum opacity of the clouds
uniform float cloud_speed = 0.002; // Speed of cloud rotation
uniform float earth_speed = -0.015; // Speed of Earth rotation
uniform float night_side_brightness = 31.0; // Brightness of the dark side
uniform float day_side_brightness = 6.0; // Brightness of the dark side
uniform float night_cloud_visibility = 0.82; // Visibility of clouds on the night side

varying vec3 v_normal; //Normal from Vertex

void vertex() {
    // Rotate vertices to simulate Earth's rotation
    float rotation_angle = TIME * earth_speed * 2.0 * 3.14159; // Convert speed to radians
    float cos_angle = cos(rotation_angle);
    float sin_angle = sin(rotation_angle);

    // Build the rotation matrix row by row
    mat3 rotation_matrix = mat3(
        vec3(cos_angle, 0.0, -sin_angle),
        vec3(0.0,      1.0,  0.0),       
        vec3(sin_angle, 0.0, cos_angle) 
    );
    
    // Transform the vertex position and normal
    VERTEX = rotation_matrix * VERTEX;
    NORMAL = rotation_matrix * NORMAL;
    
    // Pass the rotated normal to the fragment shader
    v_normal = NORMAL;
}

void fragment() {
    vec3 normal = normalize(v_normal);

    // Day-night blending
    float light_intensity = dot(normal, normalize(light_direction));
    float blend_factor = smoothstep(-blend_smoothness, blend_smoothness, light_intensity);

    vec2 uv = UV;

    vec4 day_color = texture(day_texture, uv);
    vec4 night_color = texture(night_texture, uv);

    // Specular map for night enhancement
    vec4 specular = texture(specular_map, uv);

    // Invert specular for water
    vec3 inverted_specular = vec3(1.0) - specular.rgb;

    // Adjust night color based on specular map
    night_color.rgb *= inverted_specular;
    night_color.rgb = mix(night_color.rgb, night_color.rgb * 1.5, 1.0 - inverted_specular);

    vec4 earth_color = mix(night_color * night_side_brightness, day_color * day_side_brightness, blend_factor);

    // Rotate Clouds
    vec2 cloud_uv = UV;
    cloud_uv.x += TIME * cloud_speed;
    vec4 cloud_color = texture(cloud_texture, fract(cloud_uv));

    // Scale cloud visibility based on light intensity
    float cloud_visibility = mix(night_cloud_visibility, cloud_opacity, max(light_intensity, 0.0));
    cloud_color.a *= cloud_visibility;

    // Combine Earth color and clouds
    vec4 final_color = mix(earth_color, cloud_color, cloud_color.a);

    ALBEDO = final_color.rgb;
    ALPHA = 1.0;
}
