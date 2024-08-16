using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
[VolumeComponentMenuForRenderPipeline("PostToy/Watercolor", typeof(UniversalRenderPipeline))]
public class WatercolorVolume : VolumeComponent, IPostProcessComponent
{
    [Tooltip("纸张纹理")]
    public TextureParameter paperTex = new TextureParameter(null);

    [Tooltip("细节纹理")]
    public TextureParameter secondTex = new TextureParameter(null);

    public bool IsActive() => paperTex.value != null;

    public bool IsTileCompatible() => false;
}
