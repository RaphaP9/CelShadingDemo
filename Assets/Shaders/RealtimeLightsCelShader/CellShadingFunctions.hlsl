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
    return floor(Lighting * LightingBands) / LightingBands;
}

float3 CalculateCelShading(Light l, SurfaceVariables s, float minimumLight, bool enlightenAllObjectWithMinimumLight)
{
    float diffuse = saturate(dot(s.normal, l.direction));
    //float diffuse = dot(s.normal, l.direction) * 0.5 + 0.5; //Remaping to 0 - 1 //Makes Object enlighten more in zones that otherwise would not enlighten, Also produces artifacts
    float attenuation = l.distanceAttenuation * l.shadowAttenuation;
    attenuation = saturate(attenuation); //Need to saturate attenuation, otherwise it can increase the number of shade levels when attenuation (specifically distance Attenuation) goes over 1
    
    diffuse *= attenuation;  
    float bandedLighting = PlaceLightingInBand(diffuse, s.lightingBands); //Place Lighting in bands
    
    bandedLighting = lerp(minimumLight, 1.0, bandedLighting); //Remapping
      
    if (!enlightenAllObjectWithMinimumLight)
    {
        float mask = (diffuse > 0.0001) ? 1.0 : 0.0; //Define a mask to only enlighten parts where diffuse has a value over 0 (0.0001)
        bandedLighting = lerp(0.0, bandedLighting, mask); //BandedLighting becomes 0 if diffuse was 0
    }
    
    float highlight = diffuse >= s.highlightThreshold ? s.hightlightIntensity : 0.0;
    
    float3 h = SafeNormalize(l.direction + s.view);
    float primitiveSpecular = saturate(dot(s.normal, h));
    float specular = primitiveSpecular >= s.specularThreshold ? s.specularIntensity : 0.0;
    specular = diffuse > 0.0001 ? specular : 0.0;
    
    float primitiveRim = 1 - dot(s.view, s.normal);
    float rim = primitiveRim >= s.rimThreshold ? s.rimIntensity : 0.0;
    rim = diffuse > 0.0001 ? rim : 0.0;
    
    bandedLighting = pow(bandedLighting, s.bandsPowerShift); //Power the lighting to get a nice effect
    
    float addOn = max(highlight, specular);
    addOn = max(rim, addOn);
    
    return l.color * (bandedLighting + addOn);
}
#endif

void LightingCelShaded_float(
    float3 Position,
    float3 Normal,
    float3 View,
    float LightingBands,
    float MinimumMainLight,
    float MinimumAdditionalLight,
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
    Color = CalculateCelShading(light, s, MinimumMainLight, true);
    
    #if _ADDITIONAL_LIGHTS
    int pixelLightCount = GetAdditionalLightsCount();
    
    for (int i = 0; i < pixelLightCount; i++)
    {
        light = GetAdditionalLight(i, Position, 1);
        Color += CalculateCelShading(light, s, MinimumAdditionalLight, false);
    }
    #endif
    
#endif
}

#endif