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

float3 CalculateCelShading(Light l, SurfaceVariables s, float minimumLight, float darkSideMinimumLightMuliplier, bool enlightenDarkSideWithMinimumLight)
{
    float diffuse = saturate(dot(s.normal, l.direction));
    float attenuation = l.distanceAttenuation * l.shadowAttenuation;
    attenuation = saturate(attenuation); 
    //Important to saturate attenuation, otherwise it can increase the number of light bands when attenuation (specifically distance Attenuation) goes over 1 (light very close to the surface).
    //PlaceLightingInBand(..) expects a 0 - 1 lighting input
    
    diffuse *= attenuation;  
    float bandedLighting = PlaceLightingInBand(diffuse, s.lightingBands); //Place Lighting in bands
    
    bandedLighting = lerp(minimumLight, 1.0, bandedLighting); //Remapping using the minimum light
      
    //Apply either darkSide Lighting or cut all lighting from darkSide
    //Always use enlightenAllObjectWithMinimumLight = false for Additional Lights, otherwise there is not a smooth transition when an additionalLight comes close to the shadered object
    float darkSideLight = enlightenDarkSideWithMinimumLight ? minimumLight * darkSideMinimumLightMuliplier : 0.0;
    bandedLighting = diffuse > 0.0 ? bandedLighting : darkSideLight;

    //Highlight Calculations
    float highlight = diffuse > s.highlightThreshold ? s.hightlightIntensity : 0.0;
    
    //Specular Calculations
    float3 h = SafeNormalize(l.direction + s.view);
    float primitiveSpecular = saturate(dot(s.normal, h));
    float specular = primitiveSpecular > s.specularThreshold ? s.specularIntensity : 0.0; //Only Enlighten parts where the primitive specular is over the threshold
    specular = diffuse > 0.0 ? specular : 0.0; //Mask with diffuse (do not enlighten parts where diffuse = 0)
    
    //Rim Calculations
    float primitiveRim = 1 - dot(s.view, s.normal);
    float rim = primitiveRim > s.rimThreshold ? s.rimIntensity : 0.0; //Exact same logic as specular
    rim = diffuse > 0.0 ? rim : 0.0;
    
    //Find the max value among the three AddOns(Highligh, Specular and Rim), as we dont want overlapping AddOns, only the more intense
    float addOn = max(highlight, specular);
    addOn = max(rim, addOn);
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