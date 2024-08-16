using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
[VolumeComponentMenuForRenderPipeline("PostToy/ImageBlockGlitch", typeof(UniversalRenderPipeline))]
public class ImageBlockGlitchVolume : VolumeComponent, IPostProcessComponent
{
    [Tooltip("强度")]
    public ClampedFloatParameter value = new ClampedFloatParameter(0.0f, 0.0f, 1.0f);

    public bool IsActive() => value.value > 0.0f;

    public bool IsTileCompatible() => false;
}
