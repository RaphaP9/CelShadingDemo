#ifndef CELL_SHADING_FUNCTIONS
#define CELL_SHADING_FUNCTIONS

#ifndef SHADERGRAPH_PREVIEW
struct SurfaceVariables
{
    float3 normal;
    float3 view;
    float lightingBands;
    float bandsPowerShift;
    float highlightThreshold;
    float hightlightIntensity;
    float specularThreshold;
    float specularIntensity;
    float rimThreshold;
    float rimIntensity;
};
    
float PlaceLightingInBand(float Lighting, float LightingBands)
{
    LightingBands = max(LightingBands, 1.0); //Keep at least 1 band
    return floor(Lighting * LightingBands) / LightingBands; //Use ceil if priority to high light levels is desired
}

float CalculateHighlight(float lighting, float threshold, float intensity)
{
    float highlight = step(threshold, lighting) * intensity;
    return highlight;
}

float CalculateSpecular(float3 lightDirection, float3 viewDirection, float3 surfaceNormal, float diffuse, float bandedLighting, float threshold, float intensity)
{
    //Blinn-Phon aproximation for specular lighing
    //Not exaclty phisically accurate but reduces computational power usage
    //It is not necessary to use a shininess constant due to this being a stylized shader (no need for continous specular)
    float3 halfVector = SafeNormalize(lightDirection + viewDirection);
    float primitiveSpecular = saturate(dot(surfaceNormal, halfVector));
    float specular = step(threshold, primitiveSpecular) * intensity; //Only Enlighten parts where the primitive specular is over the threshold
    //Multiply with banded lighting so specular is influenced by the light band it belongs
    //Do not produce specular parts where diffuse = 0 (Shadowed or dark parts). Use 0.0001 due to step being greater or equal to)
    specular *= step(0.0001, diffuse) * bandedLighting; 
    return specular;
}

float CalculateRim(float3 viewDirection, float3 surfaceNormal, float diffuse, float bandedLighting, float threshold, float intensity)
{
    float primitiveRim = 1 - dot(viewDirection, surfaceNormal); //Primitive rim is also a gradient
    float rim = step(threshold, primitiveRim) * intensity; //Exact same logic as specular
    rim *= step(0.0001, diffuse) * bandedLighting;
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
    float specular = CalculateSpecular(l.direction, s.view, s.normal, diffuse, bandedLighting, s.specularThreshold, s.specularIntensity);
    float rim = CalculateRim(s.view, s.normal, diffuse, bandedLighting, s.rimThreshold, s.rimIntensity);
    
    //Find the max value among the three AddOns(Highligh, Specular and Rim), as we dont want overlapping AddOns in each pixel, only the most intense one
    float addOn = max(highlight, max(specular, rim));
    bandedLighting += addOn; //Add to the bandedLighting
    
    //Power the lighting to get a nice effect (If bandsPowerShift < 1, enlighten and uniformize lighting, if bandsPowerShift > 1, darken all light but stand out addOns)
    bandedLighting = pow(bandedLighting, s.bandsPowerShift); 
    
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
    float BandsPowerShift,
    float HightlightThreshold,
    float HightlightIntensity,
    float SpecularThreshold,
    float SpecularIntensity,
    float RimThreshold,
    float RimIntensity,
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
    s.bandsPowerShift = BandsPowerShift;
    s.highlightThreshold = HightlightThreshold;
    s.hightlightIntensity = HightlightIntensity;
    s.specularThreshold = SpecularThreshold;
    s.specularIntensity = SpecularIntensity;
    s.rimThreshold = RimThreshold;
    s.rimIntensity = RimIntensity;
    
    #if SHADOWS_SCREEN
        float4 clipPos = TransformWorldToHClip(Position);
        float4 shadowCoord = ComputeScreenPos(clipPos);
    #else 
        float4 shadowCoord = TransformWorldToShadowCoord(Position);
    #endif
    
    Light light = GetMainLight(shadowCoord);
    Color = CalculateCelShading(light, s, MinimumMainLight, DarkSideMinimumLightMuliplier, true);
    
    #if _ADDITIONAL_LIGHTS
    int pixelLightCount = GetAdditionalLightsCount();
    
    for (int i = 0; i < pixelLightCount; i++)
    {
        light = GetAdditionalLight(i, Position, 1);
        Color += CalculateCelShading(light, s, MinimumAdditionalLight, DarkSideMinimumLightMuliplier, false);
    }
#endif
    
#endif
}

#endif