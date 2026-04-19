#ifndef CELL_SHADING_FUNCTIONS
#define CELL_SHADING_FUNCTIONS

#ifndef SHADERGRAPH_PREVIEW
struct SurfaceVariables
{
    float3 normal;
    float lightingBands;
    float bandsPowerShift;
    bool useHighlight;
    float highlightEdge;
    float hightlightIntensity;
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
    
    if (s.useHighlight) //Use Hightlight if desired
    {
        if (diffuse >= s.highlightEdge)
        {
            bandedLighting += s.hightlightIntensity;
        }
    }   
    
    bandedLighting = pow(bandedLighting, s.bandsPowerShift); //Power the lighting to get a nice effect (enlightening if bandsPowershift < 1, darkening if bandsPowershift > 1)
    
    return l.color * bandedLighting;
}
#endif

void LightingCelShaded_float(
    float3 Position,
    float3 Normal,
    float LightingBands,
    float MinimumMainLight,
    float MinimumAdditionalLight,
    float BandsPowerShift,
    bool UseHighlight,
    float HightlightEdge,
    float HightlightIntensity,
    out float3 Color
)
{
#if defined(SHADERGRAPH_PREVIEW)
    Color = float3(0.5f,0.5f,0.5f);
#else
    SurfaceVariables s;
    s.normal = normalize(Normal);
    s.lightingBands = LightingBands;
    s.bandsPowerShift = BandsPowerShift;
    s.useHighlight = UseHighlight;
    s.highlightEdge = HightlightEdge;
    s.hightlightIntensity = HightlightIntensity;
    
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