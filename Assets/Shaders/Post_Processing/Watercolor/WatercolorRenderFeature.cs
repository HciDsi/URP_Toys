using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class WatercolorRenderFeature : ScriptableRendererFeature
{
    WatercolorPass WatercolorPass;

    public override void Create()
    {
        WatercolorPass = new WatercolorPass(RenderPassEvent.BeforeRenderingPostProcessing);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        WatercolorPass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(WatercolorPass);
    }
}

public class WatercolorPass : ScriptableRenderPass
{
    static readonly string renderTags = "Post Watercolor Pass";
    static readonly int MainTexId = Shader.PropertyToID("_MainTex");
    static readonly int TempTargetId = Shader.PropertyToID("_TempTarget");
    static readonly int PaperTexId = Shader.PropertyToID("_PaperTex");
    static readonly int SecondTexId = Shader.PropertyToID("_SecondTex");

    WatercolorVolume watercolorVal;
    Material mate;
    RenderTargetIdentifier currTarget;

    public WatercolorPass(RenderPassEvent evt)
    {
        renderPassEvent = evt;
        var shader = Shader.Find("Post/Watercolor");
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
        watercolorVal = stack.GetComponent<WatercolorVolume>();
        if (watercolorVal == null && watercolorVal.IsActive())
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
        //mate.SetFloat(ValueId, WatercolorVal.value.value);
        //mate.SetFloat(RadiusId, WatercolorVal.radius.value);
        mate.SetTexture(PaperTexId, watercolorVal.paperTex.value);
        mate.SetTexture(SecondTexId, watercolorVal.secondTex.value);

        int shaderPass = 0;
        cmd.SetGlobalTexture(MainTexId, source);
        cmd.GetTemporaryRT(destination, w, h, 0, FilterMode.Point, RenderTextureFormat.Default);

        cmd.Blit(source, destination);

        cmd.GetTemporaryRT(destination, w / 2, h / 2, 0, FilterMode.Point, RenderTextureFormat.Default);
        cmd.Blit(destination, source, mate, shaderPass);
        cmd.Blit(source, destination);
    }
}
