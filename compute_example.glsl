#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba8, binding = 0) restrict uniform image2D colorOutput;
layout(binding = 1, std430) restrict buffer CameraBuffer {
    float data[];
}
camera_xform;

#define SDF_SHAPE_BOX            0
#define SDF_SHAPE_BOX_FRAME      1
#define SDF_SHAPE_SPHERE         2
#define SDF_SHAPE_BOX_ROUNDED    3

/*

Stack-based SDF calculator.

Locals:
- Stack (it's hard to even think of how big this needs to be)
- Program Counter
- Position

- Stack starts with [tmax]
- Stack contains positions and distances

Program is a mix of instructions and data (all 32-bit):
- POP_POS                    (Pops position from stack)

// Operations for combining  the top two things on the stack
- UNION                      (min(D1, D2))
- SUNION        K
- SUBTRACTION                (max(-D1, D2))
- SSUBTRACTION  K
- INTERSECTION               (max(D1, D2))
- SINTERSECTION K

- MOV_ROT       3x4 matrix   (Pushes position and multiples position by matrix)
- SCALE         S            (Pushes position and S and divides position by S)
- UNSCALE                    (Pops position and multiplies D by stack[SP-1])

- ROUND         R            (Subtracts D by R)

- SPHERE        R
- BOX           X, Y, Z
*/

#define UNION            0
#define SUBTRACTION      1
#define INTERSECTION     2

#define SUNION          10
#define SSUBTRACTION    11
#define SINTERSECTION   12

#define POP_POS        100
#define MOV            101
#define ROTATE         102
#define SCALE          103
#define UNSCALE        104
#define MOV_ROT        105

#define SPHERE         200
#define BOX            201
#define ELLIPSOID      202

#define ROUND          300

#define COLOR          400

layout(binding = 2, std430) restrict buffer ProgramBuffer {
	int data_length;
    int data[];
}
program;

float smoothUnion( float a, float b, float k ) {
    float h = max( k-abs(a-b), 0.0 )/k;
    return min( a, b ) - h*h*k*(1.0/4.0);
}

float smoothSubtraction( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return mix( d2, -d1, h ) + k*h*(1.0-h);
}

float smoothIntersection( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) + k*h*(1.0-h);
}

float sdBoxFrame( vec3 p, vec3 b, float e)
{
       p = abs(p  )-b;
  vec3 q = abs(p+e)-e;

  return min(min(
      length(max(vec3(p.x,q.y,q.z),0.0))+min(max(p.x,max(q.y,q.z)),0.0),
      length(max(vec3(q.x,p.y,q.z),0.0))+min(max(q.x,max(p.y,q.z)),0.0)),
      length(max(vec3(q.x,q.y,p.z),0.0))+min(max(q.x,max(q.y,p.z)),0.0));
}

float sdBox( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdSphere( vec3 p, float s )
{
  return length(p)-s;
}

float sdEllipsoid( in vec3 p, in vec3 r )
{
    float k1 = length(p/r);
    float k2 = length(p/(r*r));
    return k1*(k1-1.0)/k2;
}

vec4 map( in vec3 pos ) {
	int sp = -1;
	vec4 stack[20];
	
	vec3 color = vec3(0.5, 0.5, 0.5);
	
	for (int i=0; i<program.data_length; i++) {
		if (program.data[i] == SPHERE) {
			stack[++sp] = vec4(color, sdSphere(pos, intBitsToFloat(program.data[i+1])));
			i++;
		} else if (program.data[i] == BOX) {
			vec3 b = vec3(
				intBitsToFloat(program.data[i+1]),
				intBitsToFloat(program.data[i+2]),
				intBitsToFloat(program.data[i+3])
			);
			stack[sp+1] = vec4(color, sdBox(pos, b));
			i += 3;
			sp++;
		} else if (program.data[i] == ELLIPSOID) {
			vec3 r = vec3(
				intBitsToFloat(program.data[i+1]),
				intBitsToFloat(program.data[i+2]),
				intBitsToFloat(program.data[i+3])
			);
			stack[sp+1] = vec4(color, sdEllipsoid(pos, r));
			i += 3;
			sp++;
		} else if (program.data[i] == UNION) {
			vec3 newColor = mix(stack[sp-1].xyz, stack[sp].xyz, 0.5 + 0.5*sign(stack[sp-1].w - stack[sp].w));
			stack[sp-1] = vec4(newColor, min(stack[sp].w, stack[sp-1].w));
			sp--;
		} else if (program.data[i] == SUNION) {
			vec3 c1 = stack[sp].xyz;
			vec3 c2 = stack[sp-1].xyz;
			float d1 = stack[sp].w;
			float d2 = stack[sp-1].w;
			float smoothness = intBitsToFloat(program.data[i+1]);
			float interpolation = clamp(0.5 + 0.5 * (d2 - d1) / smoothness, 0.0, 1.0);
			vec3 newColor = mix(c2, c1, interpolation);
			
			float new_d = smoothUnion(d1, d2, intBitsToFloat(program.data[i+1]));
		
			stack[sp-1] = vec4(newColor, new_d);
			i++;
			sp--;
		} else if (program.data[i] == SUBTRACTION) {
			vec3 newColor = mix(stack[sp-1].xyz, stack[sp].xyz, 0.5 - 0.5*sign(stack[sp-1].w + stack[sp].w));
			stack[sp-1] = vec4(newColor, max(-stack[sp].w, stack[sp-1].w));
			sp--;
		} else if (program.data[i] == SSUBTRACTION) {
			vec3 c1 = stack[sp].xyz;
			vec3 c2 = stack[sp-1].xyz;
			float d1 = stack[sp].w;
			float d2 = stack[sp-1].w;
			float smoothness = intBitsToFloat(program.data[i+1]);
			
			float interpolation = clamp( 0.5 - 0.5*(d2+d1)/smoothness, 0.0, 1.0 );
			
			vec3 newColor = mix(c2, c1, interpolation);
			
			stack[sp-1] = vec4(newColor, smoothSubtraction(stack[sp].w, stack[sp-1].w, intBitsToFloat(program.data[i+1])));
			i++;
			sp--;
		} else if (program.data[i] == INTERSECTION) {
			vec3 newColor = mix(stack[sp-1].xyz, stack[sp].xyz, 0.5 - 0.5*sign(stack[sp-1].w - stack[sp].w));
			stack[sp-1] = vec4(newColor, max(stack[sp].w, stack[sp-1].w));
			sp--;
		} else if (program.data[i] == SINTERSECTION) {
			vec3 c1 = stack[sp].xyz;
			vec3 c2 = stack[sp-1].xyz;
			float d1 = stack[sp].w;
			float d2 = stack[sp-1].w;
			float smoothness = intBitsToFloat(program.data[i+1]);
			
			float interpolation = clamp( 0.5 - 0.5*(d2-d1)/smoothness, 0.0, 1.0 );
			
			vec3 newColor = mix(c2, c1, interpolation);
			
			stack[sp-1] = vec4(newColor, smoothIntersection(stack[sp].w, stack[sp-1].w, intBitsToFloat(program.data[i+1])));
			i++;
			sp--;
		} else if (program.data[i] == ROUND) {
			stack[sp] = vec4(color, stack[sp].w - intBitsToFloat(program.data[i+1]));
			i++;
		} else if (program.data[i] == POP_POS) {
			pos = stack[sp--].xyz;
		} else if (program.data[i] == MOV) {
			//stack[++sp] = pos.xxyz;
			pos -= vec3(
				intBitsToFloat(program.data[i+1]),
				intBitsToFloat(program.data[i+2]),
				intBitsToFloat(program.data[i+3])
			);
			i += 3;
		} else if (program.data[i] == COLOR) {
			color = vec3(
				intBitsToFloat(program.data[i+1]),
				intBitsToFloat(program.data[i+2]),
				intBitsToFloat(program.data[i+3])
			);
			i += 3;
		}
	}
	
	return stack[sp];
}

// https://iquilezles.org/articles/normalsSDF
vec3 calcNormal( in vec3 pos )
{
    vec2 e = vec2(1.0,-1.0)*0.5773;
    const float eps = 0.0005;
    return normalize( e.xyy*map( pos + e.xyy*eps ).w + 
					  e.yyx*map( pos + e.yyx*eps ).w + 
					  e.yxy*map( pos + e.yxy*eps ).w + 
					  e.xxx*map( pos + e.xxx*eps ).w );
}

// The code we want to execute in each invocation
void main() {
	ivec2 fragCoord = ivec2(gl_GlobalInvocationID.xy);
	ivec2 iResolution = imageSize(colorOutput);
	
	vec3 ww = vec3(camera_xform.data[0], camera_xform.data[1], camera_xform.data[2]);
	vec3 uu = vec3(camera_xform.data[3], camera_xform.data[4], camera_xform.data[5]);
	vec3 vv = vec3(camera_xform.data[6], camera_xform.data[7], camera_xform.data[8]);
   
	vec3 ro = vec3(camera_xform.data[9], camera_xform.data[10], camera_xform.data[11]);
   
    // render    
    vec3 tot = vec3(0.0);

	vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;


	// create view ray
	vec3 rd = normalize( p.x*uu + p.y*vv + 1.5*ww );

	// raymarch
	const float tmax = 100.0;
	float t = 0.0;
	for( int i=0; i<256; i++ )
	{
		vec3 pos = ro + t*rd;
		float h = map(pos).w;
		if( h<0.0001 || t>tmax ) break;
		t += h;
	}
	

	// shading/lighting	
	vec3 col = vec3(0.0);
	if( t<tmax )
	{
		vec3 pos = ro + t*rd;
		vec3 nor = calcNormal(pos);
		
		float dif = clamp( dot(nor,vec3(0.57703)), 0.05, 1.0 );
		vec3 diffuseColor = map(pos).xyz;
		
		col = diffuseColor*dif;
	}
	
	float alpha = t < tmax ? 1.0 : 0.0;

	// gamma        
	col = sqrt( col );
	tot += col;
	
	imageStore(colorOutput, fragCoord, vec4( tot, alpha ));
}