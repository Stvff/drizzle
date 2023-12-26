#version 330 core
out vec4 FragColor;

in vec2 tex_coord;

uniform sampler2D top_texture;
uniform sampler2D bot_texture;

void main() {
	vec4 top_clr = texture(top_texture, tex_coord);
	vec4 bot_clr = texture(bot_texture, tex_coord);
//	FragColor = mix(gui_clr, img_clr, img_clr.w);
	FragColor = vec4((1.0 - top_clr.w)*bot_clr + (top_clr.w * top_clr));
//	FragColor = gui_clr;
}
