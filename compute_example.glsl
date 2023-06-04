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
#define ROUND_CONE     203
#define QUAD_BEZIER    204

#define ROUND          300

#define COLOR          400

layout(binding = 2, std430) restrict buffer ProgramBuffer {
	int data_length;
    int data[];
}
program;

layout(r32f, binding = 3) restrict uniform image2D depthOutput;
layout(rgba32f, binding = 4) restrict uniform image2D normalOutput;

layout(r32ui, binding = 5) restrict uniform uimage2D idOutput;

struct SdfSurface {
    vec3 color;
    uint id;
};

SdfSurface newSdfSurface(vec3 color, uint id) {
	SdfSurface surface;
	surface.color = color,
	surface.id = id;
	
	return surface;
}


struct SdfFragment {
    float depth;
    SdfSurface surface;
};

SdfFragment newSdfFragment(vec3 color, float depth, uint id) {
	SdfFragment fragment;
	fragment.depth = depth;
	fragment.surface.color = color;
	fragment.surface.id = id;
	
	return fragment;
}

float cro( in vec2 a, in vec2 b ) { return a.x*b.y - a.y*b.x; }
float dot2( in vec2 v ) { return dot(v,v); }
float dot2( in vec3 v ) { return dot(v,v); }
float ndot( in vec2 a, in vec2 b ) { return a.x*b.x - a.y*b.y; }

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

float sdRoundCone( vec3 p, vec3 a, vec3 b, float r1, float r2 )
{
  // sampling independent computations (only depend on shape)
  vec3  ba = b - a;
  float l2 = dot(ba,ba);
  float rr = r1 - r2;
  float a2 = l2 - rr*rr;
  float il2 = 1.0/l2;
    
  // sampling dependant computations
  vec3 pa = p - a;
  float y = dot(pa,ba);
  float z = y - l2;
  float x2 = dot2( pa*l2 - ba*y );
  float y2 = y*y*l2;
  float z2 = z*z*l2;

  // single square root!
  float k = sign(rr)*rr*rr*x2;
  if( sign(z)*a2*z2>k ) return  sqrt(x2 + z2)        *il2 - r2;
  if( sign(y)*a2*y2<k ) return  sqrt(x2 + y2)        *il2 - r1;
                        return (sqrt(x2*a2*il2)+y*rr)*il2 - r1;

}

// Modified from https://www.shadertoy.com/view/ldj3Wh
vec2 sdBezier(vec3 pos, vec3 A, vec3 B, vec3 C)
{    
    vec3 a = B - A;
    vec3 b = A - 2.0*B + C;
    vec3 c = a * 2.0;
    vec3 d = A - pos;

    float kk = 1.0 / dot(b,b);
    float kx = kk * dot(a,b);
    float ky = kk * (2.0*dot(a,a)+dot(d,b)) / 3.0;
    float kz = kk * dot(d,a);      

    vec2 res;

    float p = ky - kx*kx;
    float p3 = p*p*p;
    float q = kx*(2.0*kx*kx - 3.0*ky) + kz;
    float q2 = q*q;
    float h = q2 + 4.0*p3;

    if(h >= 0.0) 
    { 
        h = sqrt(h);
        vec2 x = (vec2(h, -h) - q) / 2.0;
        
		// See screeb's (NOT iq's) description of this fix from:
		// https://www.shadertoy.com/view/MlKcDD
		if(abs(abs(h/q) - 1.0) < 0.0001)
        {
            x = vec2(p3/q, -q - p3/q);

            if(q < 0.0)
                x = x.yx;
        }
        
        vec2 uv = sign(x)*pow(abs(x), vec2(1.0/3.0));
		float unclamped_t = uv.x+uv.y-kx;
        float t = clamp(unclamped_t, 0.0, 1.0);

        res = vec2(dot2(d+(c+b*t)*t), unclamped_t);
    }
    else
    {
        float z = sqrt(-p);
        float v = acos( q/(p*z*2.0) ) / 3.0;
        float m = cos(v);
        float n = sin(v)*1.732050808;
		
		vec3 unclamped_t = vec3(m+m,-n-m,n-m)*z-kx;
        vec3 t = clamp( unclamped_t, 0.0, 1.0);
        
        // 3 roots, but only need two
        float dis = dot2(d+(c+b*t.x)*t.x);
        res = vec2(dis,unclamped_t.x);

        dis = dot2(d+(c+b*t.y)*t.y);
        if( dis<res.x ) res = vec2(dis, unclamped_t.y );
    }
    
    res.x = sqrt(res.x);
    return res;
}

#define POP_VEC3(arr, i) vec3(intBitsToFloat(arr[++i]), intBitsToFloat(arr[++i]), intBitsToFloat(arr[++i]))
#define POP_F32(arr, i) intBitsToFloat(arr[++i])

float mapDepth( in vec3 pos ) {
	int sp = -1;
	int pos_sp = -1;
	float stack[20];
	vec3 pos_stack[20];
	
	for (int i=0; i<program.data_length; i++) {
		if (program.data[i] == SPHERE) {
			stack[++sp] = sdSphere(pos, POP_F32(program.data, i));
		} else if (program.data[i] == ROUND_CONE) {
			stack[++sp] = sdRoundCone(
				pos,
				POP_VEC3(program.data, i),
				POP_VEC3(program.data, i),
				POP_F32(program.data, i),
				POP_F32(program.data, i)
			);
		} else if (program.data[i] == BOX) {
			stack[++sp] = sdBox(pos, POP_VEC3(program.data, i));
		} else if (program.data[i] == QUAD_BEZIER) {
			vec2 dt = sdBezier(
				pos,
				POP_VEC3(program.data, i),
				POP_VEC3(program.data, i),
				POP_VEC3(program.data, i)
			);
			
			// We want to look at the t value slightly beyond 0 and 1 so that the bezier
			// doesn't stop with a weird spherical nub
			float t = clamp(dt.y, -0.05, 1.05);
			
			// TODO: pass in thickness params
			
			//float ra = (dt.y-1)*dt.y*(-0.5)*(dt.y-1)*dt.y*(-0.5)*10.0;
			
			float ra = -t*(t-1.0);
			
			ra *= 1.2;
			ra += 0.2;
			
			ra = 0.1;
			stack[++sp] = dt.x-ra;
		} else if (program.data[i] == ELLIPSOID) {
			stack[++sp] = sdEllipsoid(pos, POP_VEC3(program.data, i));
		} else if (program.data[i] == UNION) {
			stack[--sp] = min(stack[sp+1], stack[sp]);
		} else if (program.data[i] == SUNION) {
			stack[--sp] = smoothUnion(stack[sp+1], stack[sp], POP_F32(program.data, i));
		} else if (program.data[i] == SUBTRACTION) {
			stack[--sp] = max(-stack[sp+1], stack[sp]);
		} else if (program.data[i] == SSUBTRACTION) {
			stack[--sp] = smoothSubtraction(stack[sp+1], stack[sp], POP_F32(program.data, i));
		} else if (program.data[i] == INTERSECTION) {
			stack[--sp] = max(stack[sp+1], stack[sp]);
		} else if (program.data[i] == SINTERSECTION) {
			stack[--sp] = smoothIntersection(stack[sp+1], stack[sp], POP_F32(program.data, i));
		} else if (program.data[i] == ROUND) {
			stack[sp] = stack[sp] - POP_F32(program.data, i);
		} else if (program.data[i] == POP_POS) {
			pos = pos_stack[pos_sp--];
		} else if (program.data[i] == MOV) {
			pos -= POP_VEC3(program.data, i);
		} else if (program.data[i] == MOV_ROT) {
			pos_stack[++pos_sp] = pos;

			mat4 transform;	

			transform[0] = vec4(POP_VEC3(program.data, i), 0);
			transform[1] = vec4(POP_VEC3(program.data, i), 0);
			transform[2] = vec4(POP_VEC3(program.data, i), 0);
			transform[3] = vec4(0, 0, 0, 1);
			
			pos = (vec4(pos, 1)*transform).xyz;
		}
	}
	
	return stack[sp];
}

SdfSurface mapSurface( in vec3 pos ) {
	int sp = -1;
	int pos_sp = -1;
	SdfFragment stack[20];
	vec3 pos_stack[20];
	
	vec3 color = vec3(0.5, 0.5, 0.5);
	
	for (int i=0; i<program.data_length; i++) {
		if (program.data[i] == SPHERE) {
			stack[++sp] = newSdfFragment(color, sdSphere(pos, intBitsToFloat(program.data[i+1])), i);
			i++;
		} else if (program.data[i] == ROUND_CONE) {
			vec3 a = vec3(intBitsToFloat(program.data[i+1]), intBitsToFloat(program.data[i+2]), intBitsToFloat(program.data[i+3]));
			vec3 b = vec3(intBitsToFloat(program.data[i+4]), intBitsToFloat(program.data[i+5]), intBitsToFloat(program.data[i+6]));

			float r1 = intBitsToFloat(program.data[i+7]);
			float r2 = intBitsToFloat(program.data[i+8]);

			stack[++sp] = newSdfFragment(color, sdRoundCone(pos, a, b, r1, r2), i);
			i += 8;
		} else if (program.data[i] == BOX) {
			vec3 b = vec3(
				intBitsToFloat(program.data[i+1]),
				intBitsToFloat(program.data[i+2]),
				intBitsToFloat(program.data[i+3])
			);
			stack[sp+1] = newSdfFragment(color, sdBox(pos, b), i);
			
			i += 3;
			sp++;
		} else if (program.data[i] == QUAD_BEZIER) {
			vec3 a = vec3(
				intBitsToFloat(program.data[i+1]),
				intBitsToFloat(program.data[i+2]),
				intBitsToFloat(program.data[i+3])
			);
			vec3 b = vec3(
				intBitsToFloat(program.data[i+4]),
				intBitsToFloat(program.data[i+5]),
				intBitsToFloat(program.data[i+6])
			);
			vec3 c = vec3(
				intBitsToFloat(program.data[i+7]),
				intBitsToFloat(program.data[i+8]),
				intBitsToFloat(program.data[i+9])
			);


			vec2 dt = sdBezier(pos, a, b, c);
			
			// We want to look at the t value slightly beyond 0 and 1 so that the bezier
			// doesn't stop with a weird spherical nub
			float t = clamp(dt.y, -0.05, 1.05);
			
			// TODO: pass in thickness params
			
			//float ra = (dt.y-1)*dt.y*(-0.5)*(dt.y-1)*dt.y*(-0.5)*10.0;
			
			float ra = -t*(t-1.0);
			
			ra *= 1.2;
			ra += 0.2;
			
			ra = 0.1;
			stack[sp+1] = newSdfFragment(color, dt.x-ra, i);


			
			
			
			i += 9;
			sp++;
		} else if (program.data[i] == ELLIPSOID) {
			vec3 r = vec3(
				intBitsToFloat(program.data[i+1]),
				intBitsToFloat(program.data[i+2]),
				intBitsToFloat(program.data[i+3])
			);
			stack[sp+1] = newSdfFragment(color, sdEllipsoid(pos, r), i);
			i += 3;
			sp++;
		} else if (program.data[i] == UNION) {
			vec3 newColor = mix(stack[sp-1].surface.color, stack[sp].surface.color, 0.5 + 0.5*sign(stack[sp-1].depth - stack[sp].depth));
			stack[sp-1] = newSdfFragment(newColor, min(stack[sp].depth, stack[sp-1].depth), i);
			sp--;
		} else if (program.data[i] == SUNION) {
			vec3 c1 = stack[sp].surface.color;
			vec3 c2 = stack[sp-1].surface.color;
			float d1 = stack[sp].depth;
			float d2 = stack[sp-1].depth;
			float smoothness = intBitsToFloat(program.data[i+1]);
			float interpolation = clamp(0.5 + 0.5 * (d2 - d1) / smoothness, 0.0, 1.0);
			vec3 newColor = mix(c2, c1, interpolation);
			
			float new_d = smoothUnion(d1, d2, intBitsToFloat(program.data[i+1]));
		
			stack[sp-1] = newSdfFragment(newColor, new_d, interpolation < 0.5 ? stack[sp-1].surface.id : stack[sp].surface.id);
			i++;
			sp--;
		} else if (program.data[i] == SUBTRACTION) {
			vec3 newColor = mix(stack[sp-1].surface.color, stack[sp].surface.color, 0.5 - 0.5*sign(stack[sp-1].depth + stack[sp].depth));
			stack[sp-1] = newSdfFragment(newColor, max(-stack[sp].depth, stack[sp-1].depth), i);
			sp--;
		} else if (program.data[i] == SSUBTRACTION) {
			vec3 c1 = stack[sp].surface.color;
			vec3 c2 = stack[sp-1].surface.color;
			float d1 = stack[sp].depth;
			float d2 = stack[sp-1].depth;
			float smoothness = intBitsToFloat(program.data[i+1]);
			
			float interpolation = clamp( 0.5 - 0.5*(d2+d1)/smoothness, 0.0, 1.0 );
			
			vec3 newColor = mix(c2, c1, interpolation);
			
			stack[sp-1] = newSdfFragment(newColor, smoothSubtraction(stack[sp].depth, stack[sp-1].depth, intBitsToFloat(program.data[i+1])), i);
			i++;
			sp--;
		} else if (program.data[i] == INTERSECTION) {
			vec3 newColor = mix(stack[sp-1].surface.color, stack[sp].surface.color, 0.5 - 0.5*sign(stack[sp-1].depth - stack[sp].depth));
			stack[sp-1] = newSdfFragment(newColor, max(stack[sp].depth, stack[sp-1].depth), i);
			sp--;
		} else if (program.data[i] == SINTERSECTION) {
			vec3 c1 = stack[sp].surface.color;
			vec3 c2 = stack[sp-1].surface.color;
			float d1 = stack[sp].depth;
			float d2 = stack[sp-1].depth;
			float smoothness = intBitsToFloat(program.data[i+1]);
			
			float interpolation = clamp( 0.5 - 0.5*(d2-d1)/smoothness, 0.0, 1.0 );
			
			vec3 newColor = mix(c2, c1, interpolation);
			
			stack[sp-1] = newSdfFragment(newColor, smoothIntersection(stack[sp].depth, stack[sp-1].depth, intBitsToFloat(program.data[i+1])), i);
			i++;
			sp--;
		} else if (program.data[i] == ROUND) {
			stack[sp] = newSdfFragment(color, stack[sp].depth - intBitsToFloat(program.data[i+1]), i);
			i++;
		} else if (program.data[i] == POP_POS) {
			pos = pos_stack[pos_sp--];
		} else if (program.data[i] == MOV) {
			//stack[++sp] = pos.xxyz;
			pos -= vec3(
				intBitsToFloat(program.data[i+1]),
				intBitsToFloat(program.data[i+2]),
				intBitsToFloat(program.data[i+3])
			);
			i += 3;
		} else if (program.data[i] == MOV_ROT) {
			pos_stack[++pos_sp] = pos;

			mat4 transform;	

			transform[0] = vec4(intBitsToFloat(program.data[i+1]), intBitsToFloat(program.data[i+2]), intBitsToFloat(program.data[i+3]), 0);
			transform[1] = vec4(intBitsToFloat(program.data[i+4]), intBitsToFloat(program.data[i+5]), intBitsToFloat(program.data[i+6]), 0);
			transform[2] = vec4(intBitsToFloat(program.data[i+7]), intBitsToFloat(program.data[i+8]), intBitsToFloat(program.data[i+9]), 0);
			transform[3] = vec4(0, 0, 0, 1);

			
			pos = (vec4(pos, 1)*transform).xyz;
			
			i += 9;
		} else if (program.data[i] == COLOR) {
			color = vec3(
				intBitsToFloat(program.data[i+1]),
				intBitsToFloat(program.data[i+2]),
				intBitsToFloat(program.data[i+3])
			);
			i += 3;
		}
	}
	
	return newSdfSurface(stack[sp].surface.color, stack[sp].surface.id);
}


// https://iquilezles.org/articles/normalsSDF
vec3 calcNormal( in vec3 pos )
{
    vec2 e = vec2(1.0,-1.0)*0.5773;
    const float eps = 0.0005;
    return normalize( e.xyy*mapDepth( pos + e.xyy*eps ) + 
					  e.yyx*mapDepth( pos + e.yyx*eps ) + 
					  e.yxy*mapDepth( pos + e.yxy*eps ) + 
					  e.xxx*mapDepth( pos + e.xxx*eps ) );
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

	vec2 p = (2.0*(vec2(fragCoord) + vec2(0.5, 0.5))-iResolution.xy)/iResolution.y;


	// create view ray
	vec3 rd = normalize( p.x*uu + p.y*vv + 1.5*ww );

	// raymarch
	const float tmax = 10.0;
	float t = 0.0;
	for( int i=0; i<256; i++ )
	{
		vec3 pos = ro + t*rd;
		float h = mapDepth(pos);
		if( h<0.0001 || t>tmax ) break;
		t += h;
	}
	

	// shading/lighting	
	vec3 col = vec3(0.0);
	vec3 nor;
	uint id;
	if( t<tmax )
	{
		vec3 pos = ro + t*rd;
		nor = calcNormal(pos);
		
		float dif = clamp( dot(nor, vec3(0.575766, 0.628109, 0.523424)), 0.05, 1.0 );
		SdfSurface surface = mapSurface(pos);
		vec3 diffuseColor = surface.color.xyz;
		id = surface.id;
		
		col = diffuseColor*dif;
	}
	
	float alpha = t < tmax ? 1.0 : 0.0;

	// gamma        
	col = sqrt( col );
	tot += col;
	
	imageStore(colorOutput, fragCoord, vec4( col, alpha ));
	imageStore(depthOutput, fragCoord, vec4( t, 0.0, 0.0, 0.0 ));
	imageStore(normalOutput, fragCoord, vec4( nor, alpha ));
	imageStore(idOutput, fragCoord, uvec4(id));
}
