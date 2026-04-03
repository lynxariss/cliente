/* RENDERTARGETS: 10 */

in vec2 texcoord;

uniform sampler2D colortex10;

void main() {
gl_FragData[0] = texture(colortex10, texcoord);
}
