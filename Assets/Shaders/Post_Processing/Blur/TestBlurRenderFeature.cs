using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class TestBlurRenderFeature : ScriptableRendererFeature
{
    TestBlurPass testBlurPass;

    public override void Create()
    {
        testBlurPass = new TestBlurPass(RenderPassEvent.BeforeRenderingPostProcessing);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        testBlurPass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(testBlurPass);
    }
}

public class TestBlurPass : ScriptableRenderPass
{
    static readonly string k_RenderTag = "Render TestBlur Effects";
    static readonly int MainTexId = Shader.PropertyToID("_MainTex");
    static readonly int TempTargetId = Shader.PropertyToID("_TempTargetTestBlur");
    static readonly int FocusPowerId = Shader.PropertyToID("_FocusPower");
    static readonly int FocusDetailId = Shader.PropertyToID("_FocusDetail");
    static readonly int FocusScreenPositionId = Shader.PropertyToID("_FocusScreenPosition");
    static readonly int ReferenceResolutionXId = Shader.PropertyToID("_ReferenceResolutionX");
    TestBlur testBlur;
    Material testBlurMaterial;
    RenderTargetIdentifier currentTarget;

    public TestBlurPass(RenderPassEvent evt)
    {
        renderPassEvent = evt;
        var shader = Shader.Find("PostEffect/TestBlur");
        if (shader == null)
        {
            Debug.LogError("Shader not found.");
            return;
        }
        testBlurMaterial = CoreUtils.CreateEngineMaterial(shader);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (testBlurMaterial == null)
        {
            Debug.LogError("Material not created.");
            return;
        }

        if (!renderingData.cameraData.postProcessEnabled) return;

        var stack = VolumeManager.instance.stack;
        testBlur = stack.GetComponent<TestBlur>();
        if (testBlur == null) { return; }
        if (!testBlur.IsActive()) { return; }

        var cmd = CommandBufferPool.Get(k_RenderTag);
        Render(cmd, ref renderingData);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void Setup(in RenderTargetIdentifier currentTarget)
    {
        this.currentTarget = currentTarget;
    }

    void Render(CommandBuffer cmd, ref RenderingData renderingData)
    {
        ref var cameraData = ref renderingData.cameraData;
        var source = currentTarget;
        int destination = TempTargetId;

        var w = (int)(cameraData.camera.scaledPixelWidth / testBlur.downSample.value);
        var h = (int)(cameraData.camera.scaledPixelHeight / testBlur.downSample.value);
        testBlurMaterial.SetFloat(FocusPowerId, testBlur.BiurRadius.value);

        int shaderPass = 0;
        cmd.SetGlobalTexture(MainTexId, source);
        cmd.GetTemporaryRT(destination, w, h, 0, FilterMode.Point, RenderTextureFormat.Default);

        cmd.Blit(source, destination);
        for (int i = 0; i < testBlur.Iteration.value; i++)
        {
            cmd.GetTemporaryRT(destination, w / 2, h / 2, 0, FilterMode.Point, RenderTextureFormat.Default);
            cmd.Blit(destination, source, testBlurMaterial, shaderPass);
            cmd.Blit(source, destination);
            cmd.Blit(destination, source, testBlurMaterial, shaderPass + 1);
            cmd.Blit(source, destination);
        }
        for (int i = 0; i < testBlur.Iteration.value; i++)
        {
            cmd.GetTemporaryRT(destination, w * 2, h * 2, 0, FilterMode.Point, RenderTextureFormat.Default);
            cmd.Blit(destination, source, testBlurMaterial, shaderPass);
            cmd.Blit(source, destination);
            cmd.Blit(destination, source, testBlurMaterial, shaderPass + 1);
            cmd.Blit(source, destination);
        }

        cmd.Blit(destination, destination, testBlurMaterial, 0);
    }
}