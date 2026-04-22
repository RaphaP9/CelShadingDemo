OVERVIEW
This project is a demo for a Stylized Cel Shading Shader that converts diffuse lighting into discrete lighting bands. 
It extends this with shadows, additional lights, and effects like highlight, specular, and rim lighting. Made in both HLSL and Shadergraph.

DEPENDENCIES
- Unity 6 (6000.0.55f1 used in this project)
- Unity URP (17.0.4 used in this project)
- Forward Renderer (Not Forward+)
- Additional Lights Enabled (if used)
- Shadow support enabled in URP asset (for both main and additional lights)

PERFORMANCE NOTE
- As additional lights are per-pixel, performance scales with addiitonal light count. If neccesary, limit the Additional Lights Per Object Limit to a low number (around 2 or 3)
- Shadowed lights are more expensive than unshadowed ones, as shadow map sampling is introduced by the URP lighting functions
- Light Banding and add-ons (Highlights, Specular and Rim lighting) are very cheap computationaly

SHADOW BEHAVIOR
- Shadows are provided by URP, Shadow visibility depends on URP renderer settings.
- Keywords (such as _ADDITIONAL_LIGHTS, _ADDITIONAL_LIGHT_SHADOWS, etc) used in the .hlsl file (CellShadingFunctions.hlsl) are AUTO-DEFINED BY URP. You SHOULD NOT replicate them 
as ShaderGraph properties, as they are completely driven by URP and should only be read by the .hlsl file.
- Use the boolean properties (UseMainLight, UseMainLightShadows, etc) in the ShaderGraph to control shadows in the shader. These do NOT enable/disable URP shadows, 
only control visual application.

EXTRA NOTES
- When opening the .hlsl file (CellShadingFunctions.hlsl), you might see some errors. These are not actual compilation errors. They are caused by undeclared functions and types 
that are provided by Unity and URP during shader compilation. They can be safely ignored and will not affect the shader.

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

VERY IMPORTANT
- If shadows are not desired and is decided to disable shadows in URP (for main light and/or additional lights), make sure to also disable UseMainLightShadows 
and UseAdditionalLightShadows on the shader material. Otherwise, ON EDITOR, it might lead to unexpected lighting rendering. 
Note that this behavior does not happen on Build (as I tested so far).

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
