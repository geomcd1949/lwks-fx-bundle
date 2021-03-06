// @Maintainer jwrl
// @Released 2018-06-22
// @Author jwrl
// @Created 2018-06-12
// @see https://www.lwks.com/media/kunena/attachments/6375/Ax_Ripples_640.png
// @see https://www.lwks.com/media/kunena/attachments/6375/Ax_Ripples.mp4
//-----------------------------------------------------------------------------------------//
// Lightworks user effect Ax_Ripples.fx
//
// This effect starts off by rippling the outgoing title as it dissolves to the new one,
// on which it progressively loses the ripple.  Alpha levels are boosted to support
// Lightworks titles, which is the default setting.
//
// This is a revision of an earlier effect, Adx_Ripples.fx, which also had the ability to
// transition between two titles.  That adds needless complexity since the same result
// can be obtained by overlaying two effects.
//-----------------------------------------------------------------------------------------//

int _LwksEffectInfo
<
   string EffectGroup = "GenericPixelShader";
   string Description = "Alpha ripple dissolve";
   string Category    = "Mix";
   string SubCategory = "Alpha transitions";
   string Notes       = "Ripples a title as it dissolves in or out";
> = 0;

//-----------------------------------------------------------------------------------------//
// Inputs
//-----------------------------------------------------------------------------------------//

texture Sup;
texture Vid;

texture BlurXinput : RenderColorTarget;
texture BlurYinput : RenderColorTarget;

//-----------------------------------------------------------------------------------------//
// Samplers
//-----------------------------------------------------------------------------------------//

sampler s_Video = sampler_state { Texture = <Vid>; };

sampler s_Super = sampler_state
{
   Texture   = <Sup>;
   AddressU  = Mirror;
   AddressV  = Mirror;
   MinFilter = Linear;
   MagFilter = Linear;
   MipFilter = Linear;
};

sampler s_Blur_X = sampler_state {
   Texture   = <BlurXinput>;
   AddressU  = Mirror;
   AddressV  = Mirror;
   MinFilter = Linear;
   MagFilter = Linear;
   MipFilter = Linear;
};

sampler s_Blur_Y = sampler_state {
   Texture   = <BlurYinput>;
   AddressU  = Mirror;
   AddressV  = Mirror;
   MinFilter = Linear;
   MagFilter = Linear;
   MipFilter = Linear;
};

//-----------------------------------------------------------------------------------------//
// Parameters
//-----------------------------------------------------------------------------------------//

int Boost
<
   string Description = "If using a Lightworks text effect disconnect its input and set this first";
   string Enum = "Crawl/Roll/Titles,Video/External image";
> = 0;

float Amount
<
   string Description = "Amount";
   float MinVal = 0.0;
   float MaxVal = 1.0;
   float KF0    = 0.0;
   float KF1    = 1.0;
> = 0.5;

int SetTechnique
<
   string Description = "Transition";
   string Enum = "Fade in,Fade out";
> = 0;

int WaveType
<
   string Description = "Wave type";
   string Enum = "Waves,Ripples";
> = 0;

float Frequency
<
   string Group = "Pattern";
   string Flags = "Frequency";
   float MinVal = 0.0;
   float MaxVal = 1.0;
> = 0.2;

float Speed
<
   string Group = "Pattern";
   string Description = "Speed";
   float MinVal = 0.0;
   float MaxVal = 1.0;
> = 0.5;

float BlurAmt
<
   string Group = "Pattern";
   string Description = "Blur";
   float MinVal = 0.0;
   float MaxVal = 1.0;
> = 0.5;

float StrengthX
<
   string Group = "Pattern";
   string Description = "Strength";
   string Flags = "SpecifiesPointX";
   float MinVal = 0.0;
   float MaxVal = 1.0;
> = 0.2;

float StrengthY
<
   string Group = "Pattern";
   string Description = "Strength";
   string Flags = "SpecifiesPointY";
   float MinVal = 0.0;
   float MaxVal = 1.0;
> = 0.0;

//-----------------------------------------------------------------------------------------//
// Definitions and declarations
//-----------------------------------------------------------------------------------------//

#define SAMPLE  30
#define SAMPLES 60
#define OFFSET  0.0005

#define CENTRE  (0.5).xx

#define EMPTY   (0.0).xxxx

#define HALF_PI 1.5707963268

float _Progress;

//-----------------------------------------------------------------------------------------//
// Functions
//-----------------------------------------------------------------------------------------//

float4 fn_tex2D (sampler Vsample, float2 uv)
{
   if ((uv.x < 0.0) || (uv.y < 0.0) || (uv.x > 1.0) || (uv.y > 1.0)) return EMPTY;

   float4 retval = tex2D (Vsample, uv);

   if (Boost == 0) {
      retval.a    = pow (retval.a, 0.5);
      retval.rgb /= retval.a;
   }

   return retval;
}

float2 fn_wave (float2 uv, float2 waves, float levels)
{
   float waveRate = _Progress * Speed * 25.0;

   float2 xy = (uv - CENTRE) * waves;
   float2 strength  = float2 (StrengthX, StrengthY) * levels / 10.0;
   float2 retXY = (WaveType == 0) ? float2 (sin (waveRate + xy.y), cos (waveRate + xy.x))
                                  : float2 (sin (waveRate + xy.x), cos (waveRate + xy.y));

   return uv + (retXY * strength);
}

//-----------------------------------------------------------------------------------------//
// Shaders
//-----------------------------------------------------------------------------------------//

float4 ps_dissolve_in (float2 uv : TEXCOORD1) : COLOR
{
   float2 waves = float (Frequency * 200.0).xx;
   float2 xy = fn_wave (uv, waves, cos (Amount * HALF_PI));

   return fn_tex2D (s_Super, xy) * Amount;
}

float4 ps_dissolve_out (float2 uv : TEXCOORD1) : COLOR
{
   float2 waves = float (Frequency * 200.0).xx;
   float2 xy = fn_wave (uv, waves, sin (Amount * HALF_PI));

   return fn_tex2D (s_Super, xy) * (1.0 - Amount);
}

float4 ps_blur_in (float2 uv : TEXCOORD1) : COLOR
{
   float4 Inp = tex2D (s_Blur_X, uv);
   float4 retval = EMPTY;

   float BlurX = (StrengthY > StrengthX) ? WaveType ? BlurAmt : (BlurAmt / 2)
                                         : WaveType ? (BlurAmt / 2) : BlurAmt;
   if (BlurX <= 0.0) return Inp;

   float2 offset = float2 (BlurX, 0.0) * OFFSET;
   float2 blurriness = 0.0.xx;

   for (int i = 0; i < SAMPLE; i++) {
      retval += tex2D (s_Blur_X, uv + blurriness);
      retval += tex2D (s_Blur_X, uv - blurriness);
      blurriness += offset;
   }
    
   retval = retval / SAMPLES;
    
   return lerp (Inp, retval, 1.0 - Amount);
}

float4 ps_blur_out (float2 uv : TEXCOORD1) : COLOR
{
   float4 Inp = tex2D (s_Blur_X, uv);
   float4 retval = EMPTY;

   float BlurY = (StrengthY > StrengthX) ? WaveType ? BlurAmt : (BlurAmt / 2)
                                         : WaveType ? (BlurAmt / 2) : BlurAmt;
   if (BlurY <= 0.0) return Inp;

   float2 offset = float2 (BlurY, 0.0) * OFFSET;
   float2 blurriness = 0.0.xx;

   for (int i = 0; i < SAMPLE; i++) {
      retval += tex2D (s_Blur_X, uv + blurriness);
      retval += tex2D (s_Blur_X, uv - blurriness);
      blurriness += offset;
   }
    
   retval = retval / SAMPLES;
    
   return lerp (Inp, retval, Amount);
}

float4 ps_main_in (float2 uv : TEXCOORD1) : COLOR
{
   float4 Bgnd   = tex2D (s_Video, uv);
   float4 Fgnd   = tex2D (s_Blur_Y, uv);
   float4 retval = EMPTY;

   float BlurY = (StrengthY > StrengthX) ? WaveType ? (BlurAmt / 2.0) : (BlurAmt * 2.0)
                                         : WaveType ? (BlurAmt * 2.0) : (BlurAmt / 2.0);
   if (BlurY > 0.0) {
      float2 offset = float2 (0.0, BlurY) * OFFSET;
      float2 blurriness = 0.0.xx;

      for (int i = 0; i < SAMPLE; i++) {
         retval += tex2D (s_Blur_Y, uv + blurriness);
         retval += tex2D (s_Blur_Y, uv - blurriness);
         blurriness += offset;
      }

      retval /= SAMPLES;

      Fgnd = lerp (Fgnd, retval, 1.0 - Amount);
   }

   return lerp (Bgnd, Fgnd, Fgnd.a);
}

float4 ps_main_out (float2 uv : TEXCOORD1) : COLOR
{
   float4 Bgnd   = tex2D (s_Video, uv);
   float4 Fgnd   = tex2D (s_Blur_Y, uv);
   float4 retval = EMPTY;

   float BlurY = (StrengthY > StrengthX) ? WaveType ? (BlurAmt / 2.0) : (BlurAmt * 2.0)
                                         : WaveType ? (BlurAmt * 2.0) : (BlurAmt / 2.0);
   if (BlurY > 0.0) {
      float2 offset = float2 (0.0, BlurY) * OFFSET;
      float2 blurriness = 0.0.xx;

      for (int i = 0; i < SAMPLE; i++) {
         retval += tex2D (s_Blur_Y, uv + blurriness);
         retval += tex2D (s_Blur_Y, uv - blurriness);
         blurriness += offset;
      }

      retval /= SAMPLES;

      Fgnd = lerp (Fgnd, retval, Amount);
   }

   return lerp (Bgnd, Fgnd, Fgnd.a);
}

//-----------------------------------------------------------------------------------------//
// Techniques
//-----------------------------------------------------------------------------------------//

technique Ax_Ripples_in
{
   pass P_1 < string Script = "RenderColorTarget0 = BlurXinput;"; >
   { PixelShader = compile PROFILE ps_dissolve_in (); }

   pass P_2 < string Script = "RenderColorTarget0 = BlurYinput;"; >
   { PixelShader = compile PROFILE ps_blur_in (); }

   pass P_3
   { PixelShader = compile PROFILE ps_main_in (); }
}

technique Ax_Ripples_out
{
   pass P_1 < string Script = "RenderColorTarget0 = BlurXinput;"; >
   { PixelShader = compile PROFILE ps_dissolve_out (); }

   pass P_2 < string Script = "RenderColorTarget0 = BlurYinput;"; >
   { PixelShader = compile PROFILE ps_blur_out (); }

   pass P_3
   { PixelShader = compile PROFILE ps_main_out (); }
}

