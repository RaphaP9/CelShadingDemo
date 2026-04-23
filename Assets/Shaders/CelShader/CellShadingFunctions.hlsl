#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_SCREEN

#pragma multi_compile _ _ADDITIONAL_LIGHTS
#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

#ifndef CELL_SHADING_FUNCTIONS
#define CELL_SHADING_FUNCTIONS

#ifndef SHADERGRAPH_PREVIEW
struct SurfaceVariables
{
    float3 normal;
    float3 view;
    float lightingBands;
    float powerShift;
    float highlightThreshold;
    float hightlightIntensity;
    float specularThreshold;
    float specularIntensity;
    bool bandDependantSpecular;
    float rimThreshold;
    float rimIntensity;
    float rimCurveFactor;
    bool bandDependantRim;
};
    
float PlaceLightingInBand(float Lighting, float LightingBands)
{
    LightingBands = max(LightingBands, 1.0); //Keep at least 1 band
    return floor(Lighting * LightingBands) / LightingBands; //Use ceil if priority to high light levels is desired (Usefull when using 1 or 2 bands)
}

float CalculateHighlight(float diffuse, float threshold, float intensity)
{
    //Use assertions to avoid unnecessary calculations
    if(intensity <= 0) 
        return 0;
    if (threshold >= 1) 
        return 0;
    
    if (diffuse <= 0) //Do not produce highlighs where diffuse = 0 (Shadowed or dark parts)
        return 0;
    
    float highlight = step(threshold, diffuse) * intensity;
    return highlight;
}

float CalculateSpecular(float3 lightDirection, float3 viewDirection, float3 surfaceNormal, float diffuse, float bandedLighting, float threshold, float intensity, bool bandDependant)
{
    if (intensity <= 0)
        return 0;
    if (threshold >= 1)
        return 0;
    
    if (diffuse <= 0) //Do not produce specular lighting where diffuse = 0 (Shadowed or dark parts)
        return 0;
    
    //Blinn-Phon aproximation for specular lighing
    //Not exaclty phisically accurate but reduces computational power usage
    //It is not necessary to use a shininess constant due to this being a stylized shader (no need for continous specular)
    float3 halfVector = SafeNormalize(lightDirection + viewDirection);
    float primitiveSpecular = saturate(dot(surfaceNormal, halfVector));
    
    //Considering threshold values between 0 - 1, we can power the threshold so it is easier to control in the inspector due to the Specular Behavior (0.2 value is arbitrary)
    //The right approach might be to do this by ShaderGraph nodes, but I wanted to give context of this decision
    float poweredThreshold = pow(abs(threshold), 0.2f); //Use abs only to avoid console warnings
    
    float specular = step(poweredThreshold, primitiveSpecular) * intensity; //Only Enlighten parts where the primitive specular is over the threshold
    
    //Multiply with banded lighting so specular is influenced by the light band it belongs (more realistic look). No multiplication gives a more garish look
    if (bandDependant)
    {
        specular *= bandedLighting;
    }
    
    return specular;
}

float CalculateRim(float3 viewDirection, float3 surfaceNormal, float diffuse, float bandedLighting, float threshold, float intensity, float rimCurveFactor, bool bandDependant)
{
    if (intensity <= 0)
        return 0;
    if (threshold >= 1)
        return 0;
    
    if (diffuse <= 0) //Do not produce rim lighting where diffuse = 0 (Shadowed or dark parts)
        return 0;
    
    //Produce a sort of simplified fresnel effect (using linear gradient) accross the surface of the object
    float primitiveRim = 1 - saturate(dot(viewDirection, surfaceNormal)); //Primitive rim is also a gradient     
    primitiveRim *= lerp(1.0, diffuse, rimCurveFactor); //Give rim a curvature/nail shape (Thick on center, narrow on sides) using the diffuse
    
    //Exact same logic as specular
    float rim = step(threshold, primitiveRim) * intensity; 

    if (bandDependant)
    {
        rim *= bandedLighting;
    }
    
    return rim;
}

float3 CalculateCelShading(Light l, SurfaceVariables s, float minimumLight, float darkSideMinimumLightMuliplier, bool enlightenDarkSideWithMinimumLight)
{
    float diffuse = saturate(dot(s.normal, l.direction));
    float attenuation = l.distanceAttenuation * l.shadowAttenuation;  
    
    attenuation = saturate(attenuation); 
    //Important to saturate attenuation before multiplying with diffuse
    //Otherwise, if attenuation (specifically distance Attenuation) goes over 1 (surface very close to light source), diffuse * attenuation can go over 1, increasing the number of light bands
    //PlaceLightingInBand(..) expects a 0 - 1 lighting input
    
    diffuse *= attenuation;  
    float bandedLighting = PlaceLightingInBand(diffuse, s.lightingBands); //Place Lighting in bands
    bandedLighting = lerp(minimumLight, 1.0, bandedLighting); //Remapping using the minimum light
         
    //Apply either darkSide Lighting or cut all lighting from darkSide
    //Always use enlightenAllObjectWithMinimumLight = false for Additional Lights, otherwise there is not a smooth transition when an additionalLight comes close to the shadered object
    float darkSideLight = enlightenDarkSideWithMinimumLight ? minimumLight * darkSideMinimumLightMuliplier : 0.0;
    bandedLighting = diffuse > 0.0 ? bandedLighting : darkSideLight;

    //AddOn Calculations
    float highlight = CalculateHighlight(diffuse, s.highlightThreshold, s.hightlightIntensity);
    float specular = CalculateSpecular(l.direction, s.view, s.normal, diffuse, bandedLighting, s.specularThreshold, s.specularIntensity, s.bandDependantSpecular);
    float rim = CalculateRim(s.view, s.normal, diffuse, bandedLighting, s.rimThreshold, s.rimIntensity, s.rimCurveFactor, s.bandDependantRim);
    
    //Find the max value among the three AddOns(Highligh, Specular and Rim), as we dont want overlapping AddOns in each pixel, only the most intense one
    float addOn = max(highlight, max(specular, rim));
    bandedLighting += addOn; //Add to the bandedLighting
    
    //Power the lighting to get a nice effect (If PowerShift < 1, enlighten and uniformize lighting, if PowerShift > 1, darken all light but stand out addOns)
    bandedLighting = pow(abs(bandedLighting), s.powerShift); //Use abs only to avoid console warnings
    
    return l.color * bandedLighting;
}
#endif

void LightingCelShaded_float(
    float3 Position,
    float3 Normal,
    float3 View,
    float LightingBands,
    float MinimumMainLight,
    float MinimumAdditionalLight,
    float DarkSideMinimumLightMuliplier,
    float PowerShift,
    float HightlightThreshold,
    float HightlightIntensity,
    float SpecularThreshold,
    float SpecularIntensity,
    float BandDependantSpecular,
    float RimThreshold,
    float RimIntensity,
    float RimCurveFactor,
    float BandDependantRim,
    bool UseMainLight,
    bool UseMainLightShadows,
    bool UseAdditionalLights,
    bool UseAdditionalLightsShadows,
    out float3 Color
)
{
#if defined(SHADERGRAPH_PREVIEW)
    Color = float3(0.5f,0.5f,0.5f);
#else
    SurfaceVariables s;
    s.normal = normalize(Normal);
    s.view = SafeNormalize(View);
    s.lightingBands = LightingBands;
    s.powerShift = PowerShift;
    s.highlightThreshold = HightlightThreshold;
    s.hightlightIntensity = HightlightIntensity;
    s.specularThreshold = SpecularThreshold;
    s.specularIntensity = SpecularIntensity;
    s.bandDependantSpecular = BandDependantSpecular;
    s.rimThreshold = RimThreshold;
    s.rimIntensity = RimIntensity;
    s.rimCurveFactor = RimCurveFactor;
    s.bandDependantRim = BandDependantRim;
    
    Color = float3(0.0f, 0.0f, 0.0f);
    
    if (UseMainLight)
    {
        Light mainLight;
        
        if (UseMainLightShadows)
        {
            #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
                float4 shadowCoord = ComputeScreenPos(TransformWorldToHClip(Position));
            #else 
                float4 shadowCoord = TransformWorldToShadowCoord(Position);
            #endif
            
            mainLight = GetMainLight(shadowCoord);
        }
        else
        {
            mainLight = GetMainLight();
        }
        
        Color += CalculateCelShading(mainLight, s, MinimumMainLight, DarkSideMinimumLightMuliplier, true);
    }
    
    if (UseAdditionalLights)
    {
        #if defined(_ADDITIONAL_LIGHTS)

        int pixelLightCount = GetAdditionalLightsCount();

        for (int i = 0; i < pixelLightCount; i++)
        {
            Light additionalLight;
        
            #if defined(_ADDITIONAL_LIGHT_SHADOWS)
              
            if (UseAdditionalLightsShadows)
            {
                additionalLight = GetAdditionalLight(i, Position, 1);
            }
            else
            {
                additionalLight = GetAdditionalLight(i, Position);
            }
            #else
                additionalLight = GetAdditionalLight(i, Position);
            #endif

        
            Color += CalculateCelShading(additionalLight, s, MinimumAdditionalLight, DarkSideMinimumLightMuliplier, false);
        }

        #endif
    }
    #endif
}
#endif