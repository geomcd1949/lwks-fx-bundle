// @Maintainer khaver
// @Released 2018-05-05
// @Author Alexander Alekseev
// @Created 2014
// @see https://www.lwks.com/media/kunena/attachments/6375/SeaScape_640.png
// @see https://www.lwks.com/media/kunena/attachments/32848/Demo-Seascape-FX-Lightworks.mp4
// @see https://www.lwks.com/media/kunena/attachments/6375/Seascape.mp4
//-----------------------------------------------------------------------------------------//
//
//   ***********  WARNING: THIS EFFECT REQUIRES LIGHTWORKS 14.5 OR BETTER  ***********
//
//-----------------------------------------------------------------------------------------//
// "Seascape" by Alexander Alekseev aka TDM - 2014
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// Contact: tdmaav@gmail.com
//-----------------------------------------------------------------------------------------//
// SeaScape.fx for Lightworks was adapted by user khaver 5 May 2018 for use with Lightworks
// version 14.5 and higher from original code by the above licensee taken from the Shadertoy
// website (https://www.shadertoy.com/view/Ms2SD1).
//
// This adaptation retains the same Creative Commons license shown above.
// It cannot be used for commercial purposes.
//--------------------------------------------------------------//

int _LwksEffectInfo
<
   string EffectGroup = "GenericPixelShader";
   string Description = "Sea Scape";
   string Category    = "Matte";
   string SubCategory = "Special Fx";
> = 0;

#ifdef WINDOWS
#define PROFILE ps_3_0
#endif

//--------------------------------------------------------------//
// Inputs
//--------------------------------------------------------------//

texture Input;

//--------------------------------------------------------------//
// Samplers
//--------------------------------------------------------------//

sampler InputSampler = sampler_state { Texture = <Input>; };


//--------------------------------------------------------------//
// Parameters
//--------------------------------------------------------------//

float Direction
<
   string Description = "Direction";
   float MinVal = -2.0;
   float MaxVal = 2.0;
> = 0.0;

float Height
<
   string Description = "Ship Height";
   float MinVal = 0.0;
   float MaxVal = 10.0;
> = 3.5;

float Speed
<
   string Description = "Ship Speed";
   float MinVal = 0.0;
   float MaxVal = 50.0;
> = 10.0;

bool Reverse
<
	string Description = "Reverse";
> = false;

float Ship
<
   string Description = "Rocking Amount";
   float MinVal = 0.0;
   float MaxVal = 1.0;
> = 0.0;

float RSPEED
<
   string Description = "Rocking Speed";
   float MinVal = 0.0;
   float MaxVal = 10.0;
> = 1.0;

float SEA_HEIGHT
<
   string Description = "Wave Height";
   float MinVal = 0.0;
   float MaxVal = 1.0;
> = 0.0;

float SEA_SPEED
<
   string Description = "Wave Speed";
   float MinVal = 0.0;
   float MaxVal = 3.0;
> = 0.8;

float SEA_FREQ
<
   string Description = "Wave Frequency";
   float MinVal = 0.0;
   float MaxVal = 5.0;
> = 0.16;

float SEA_CHOPPY
<
   string Description = "Wave Choppiness";
   float MinVal = 0.00;
   float MaxVal = 10.00;
> = 4.0;


uniform float3 Water = float3(0.8,0.9,0.6); // Water Color
uniform float3 Base = float3(0.1,0.19,0.22); // Base Color

//--------------------------------------------------------------//
// Common
//--------------------------------------------------------------//

float _Progress;
float _OutputWidth;
float _OutputHeight;
float _LengthFrames = 0;
float _Length = 0;


int _NUM_STEPS = 8;
static int ITER_GEOMETRY = 3;
static int ITER_FRAGMENT = 5;
float2x2 octave_m = float2x2(1.6,1.2,-1.2,1.6);

#define EPSILON_NRM	(0.1/_OutputWidth)
#define CTIME (_Length*_Progress*-1.0)
#define SEA_TIME (1.0+CTIME*SEA_SPEED)



//--------------------------------------------------------------//
// Shaders
//--------------------------------------------------------------//

// math

float3x3 fromEuler(float3 ang) {
        float2 a1 = float2(sin(ang.x),cos(ang.x));
    float2 a2 = float2(sin(ang.y),cos(ang.y));
    float2 a3 = float2(sin(ang.z),cos(ang.z));
    float3x3 m;
    m[0] = float3(a1.y*a3.y+a1.x*a2.x*a3.x,a1.y*a2.x*a3.x+a3.y*a1.x,-a2.y*a3.x);
        m[1] = float3(-a2.y*a1.x,a1.y*a2.y,a2.x);
        m[2] = float3(a3.y*a1.x*a2.x+a1.y*a3.x,a1.x*a3.x-a1.y*a3.y*a2.x,a2.y*a3.y);
        return m;
}

float hash( float2 p ) {
        float h = dot(p,float2(127.1,311.7));
    return frac(sin(h)*43758.5453123);
}

float noise( float2 p ) {
    float2 i = floor( p );
    float2 f = frac( p );
        float2 u = f*f*(3.0-2.0*f);
    return -1.0+2.0*lerp( lerp( hash( i + float2(0.0,0.0) ),
                     hash( i + float2(1.0,0.0) ), u.x),
                lerp( hash( i + float2(0.0,1.0) ),
                     hash( i + float2(1.0,1.0) ), u.x), u.y);
}

// lighting
float diffuse(float3 n,float3 l,float p) {
    return pow(dot(n,l) * 0.4 + 0.6,p);
}
float specular(float3 n,float3 l,float3 e,float s) {
    float nrm = (s + 8.0) / (3.1415 * 8.0);
    return pow(max(dot(reflect(e,n),l),0.0),s) * nrm;
}

// sky
float3 getSkyColor(float3 e) {
    e.y = max(e.y,0.0);
    return float3(pow(1.0-e.y,2.0), 1.0-e.y, 0.6+(1.0-e.y)*0.4);
}

// sea
float sea_octave(float2 uv, float choppy) {
    uv += noise(uv);
    float2 wv = 1.0-abs(sin(uv));
    float2 swv = abs(cos(uv));
    wv = lerp(wv,swv,wv);
    return pow(1.0-pow(wv.x * wv.y,0.65),choppy);
}

float map(float3 p) {
    float freq = SEA_FREQ;
    float amp = SEA_HEIGHT;
    float choppy = SEA_CHOPPY;
    float2 uv = p.xz; uv.x *= 0.75;

    float d, h = 0.0;
    for(int i = 0; i < ITER_GEOMETRY; i++) {
        d = sea_octave((uv+SEA_TIME)*freq,choppy);
        d += sea_octave((uv-SEA_TIME)*freq,choppy);
        h += d * amp;
        uv = mul(uv,octave_m); freq *= 1.9; amp *= 0.22;
        choppy = lerp(choppy,1.0,0.2);
    }
    return p.y - h;
}

float map_detailed(float3 p) {
    float freq = SEA_FREQ;
    float amp = SEA_HEIGHT;
    float choppy = SEA_CHOPPY;
    float2 uv = p.xz; uv.x *= 0.75;

    float d, h = 0.0;
    for(int i = 0; i < ITER_FRAGMENT; i++) {
        d = sea_octave((uv+SEA_TIME)*freq,choppy);
        d += sea_octave((uv-SEA_TIME)*freq,choppy);
        h += d * amp;
        uv = mul(uv,octave_m); freq *= 1.9; amp *= 0.22;
        choppy = lerp(choppy,1.0,0.2);
    }
    return p.y - h;
}

float3 getSeaColor(float3 p, float3 n, float3 l, float3 eye, float3 dist) {
    float fresnel = clamp(1.0 - dot(n,-eye), 0.0, 1.0);
    fresnel = pow(fresnel,3.0) * 0.65;

    float3 reflected = getSkyColor(reflect(eye,n));
    float3 refracted = Base + diffuse(n,l,80.0) * Water * 0.12;

    float3 color = lerp(refracted,reflected,fresnel);

    float atten = max(1.0 - dot(dist,dist) * 0.001, 0.0);
    color += Water * (p.y - SEA_HEIGHT) * 0.18 * atten;
	float spec = specular(n,l,eye,60.0);

    color += float3(spec,spec,spec);

    return color;
}

// tracing
float3 getNormal(float3 p, float eps) {
    float3 n;
    n.y = map_detailed(p);
    n.x = map_detailed(float3(p.x+eps,p.y,p.z)) - n.y;
    n.z = map_detailed(float3(p.x,p.y,p.z+eps)) - n.y;
    n.y = eps;
    return normalize(n);
}

float heightMapTracing(float3 ori, float3 dir, out float3 p) {
    float tm = 0.0;
    float tx = 1000.0;
    float hx = map(ori + dir * tx);
    if(hx > 0.0) return tx;
    float hm = map(ori + dir * tm);
    float tmid = 0.0;
    for(int i = 0; i < 8; i++) {
        tmid = lerp(tm,tx, hm/(hm-hx));
        p = ori + dir * tmid;
        float hmid = map(p);
		if(hmid < 0.0) {
            tx = tmid;
            hx = hmid;
        } else {
            tm = tmid;
            hm = hmid;
        }
    }
    return tmid;
}

// main
float4 mainImage(float2 uv : TEXCOORD0) : COLOR {
	float iTime = CTIME;
	if (Reverse) iTime *= -1.0;
	uv.y = 1.0 - uv.y;
    uv = ( uv * 2.0 - 1.0 );
    uv.x *= _OutputWidth / _OutputHeight;
    float time = iTime * 0.3;
	float rtime = time * RSPEED;

    // ray
    float3 ang = float3(sin(rtime*3.0)*0.1,sin(rtime)*0.2+0.3,rtime);
    float3 ori = float3(0.0,Height,time*Speed);
    float3 dir = normalize(float3(uv.xy,-2.0)); dir.z += length(uv) * 0.00005;
	ang.xy *= Ship;
	ang.z *= Direction;
    dir = mul(normalize(dir),fromEuler(ang));


    // tracing
    float3 p;
    heightMapTracing(ori,dir,p);
    float3 dist = p - ori;
    float3 n = getNormal(p, dot(dist,dist) * EPSILON_NRM);
    float3 light = normalize(float3(0.0,1.0,0.8));

    // color
    float3 color = lerp(
        getSkyColor(dir),
        getSeaColor(p,n,light,dir,dist),
        pow(smoothstep(0.0,-0.05,dir.y),0.3));

    // post
        float4 fragColor = float4(pow(color,float3(0.75, 0.75, 0.75)), 1.0);
		return fragColor;
}



//--------------------------------------------------------------//
// Techniques
//--------------------------------------------------------------//

technique Scape
{
   pass Pass1
   {
      PixelShader = compile PROFILE mainImage ();
   }
}

