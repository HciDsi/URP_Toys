using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class FisheyeRenderFeature : ScriptableRendererFeature
{
    FisheyePass fisheyePass;

    public override void Create()
    {
        fisheyePass = new FisheyePass(RenderPassEvent.BeforeRenderingPostProcessing);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        fisheyePass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(fisheyePass);
    }
}

public class FisheyePass : ScriptableRenderPass
{
    static readonly string renderTags = "Post Fisheye Pass";
    static readonly int MainTexId = Shader.PropertyToID("_MainTex");
    static readonly int TempTargetId = Shader.PropertyToID("_TempTarget");
    static readonly int ValueId = Shader.PropertyToID("_Value");
    static readonly int RadiusId = Shader.PropertyToID("_Radius");

    FisheyeVolume fisheyeVal;
    Material mate;
    RenderTargetIdentifier currTarget;

    public FisheyePass(RenderPassEvent evt)
    {
        renderPassEvent = evt;
        var shader = Shader.Find("Post/Fisheye");
        if (shader == false)
        {
            Debug.LogError("Not Find Shader " + renderTags);
            return;
        }
        mate = CoreUtils.CreateEngineMaterial(shader);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (mate == null)
        {
            Debug.LogError("Not Create Material " + renderTags);
            return;
        }

        if (!renderingData.cameraData.postProcessEnabled)
        {
            return;
        }

        var stack = VolumeManager.instance.stack;
        fisheyeVal = stack.GetComponent<FisheyeVolume>();
        if (fisheyeVal == null && fisheyeVal.IsActive())
        {
            return;
        }

        var cmd = CommandBufferPool.Get(renderTags);
        Render(cmd, ref renderingData);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void Setup(in RenderTargetIdentifier currTarget)
    {
        this.currTarget = currTarget;
    }

    void Render(CommandBuffer cmd, ref RenderingData renderingData)
    {
        ref var cameraData = ref renderingData.cameraData;
        var source = currTarget;
        int destination = TempTargetId;

        var w = (int)(cameraData.camera.scaledPixelWidth / 1);
        var h = (int)(cameraData.camera.scaledPixelHeight / 1);
        //testBlurMaterial.SetFloat(FocusPowerId, testBlur.BiurRadius.value);
        mate.SetFloat(ValueId, fisheyeVal.value.value);
        mate.SetFloat(RadiusId, fisheyeVal.radius.value);

        int shaderPass = 0;
        cmd.SetGlobalTexture(MainTexId, source);
        cmd.GetTemporaryRT(destination, w, h, 0, FilterMode.Point, RenderTextureFormat.Default);

        cmd.Blit(source, destination);

        cmd.GetTemporaryRT(destination, w / 2, h / 2, 0, FilterMode.Point, RenderTextureFormat.Default);
        cmd.Blit(destination, source, mate, shaderPass);
        cmd.Blit(source, destination);
    }
}
