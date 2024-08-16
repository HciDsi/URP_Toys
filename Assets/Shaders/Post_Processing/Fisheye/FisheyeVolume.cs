using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
[VolumeComponentMenuForRenderPipeline("PostToy/Fisheye", typeof(UniversalRenderPipeline))]
public class FisheyeVolume : VolumeComponent,IPostProcessComponent
{

    [Tooltip("质量")]
    public ClampedFloatParameter value = new ClampedFloatParameter(0.0f, 0.0f, 1.0f);

    [Tooltip("扭曲半径")]
    public ClampedFloatParameter radius = new ClampedFloatParameter(0.0f, 0.0f, 5.0f);

    public bool IsActive() => value.value > 0;

    public bool IsTileCompatible() => false;
}
