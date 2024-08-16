using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
// 将这个类添加到渲染管线的后处理组件菜单中，路径为 "Post/Default"
// 指定它属于 UniversalRenderPipeline
[VolumeComponentMenuForRenderPipeline("PostToy/Default", typeof(UniversalRenderPipeline))]
public class Default : VolumeComponent, IPostProcessComponent
{
    [Tooltip("混合颜色")]
    public ColorParameter BlenderColor = new ColorParameter(Color.blue);

    [Tooltip("混合强度")]
    public ClampedFloatParameter Intensity = new ClampedFloatParameter(0.0f, 0.0f, 1.0f);

    // 判断后处理效果是否激活
    public bool IsActive()
    {
        // 如果混合强度不为 0，则认为该效果是激活的
        return Intensity.value != 0.0f;
    }

    public bool IsTileCompatible()
    {
        return false;
    }
}


public class DefaultPass : ScriptableRenderPass
{
    static readonly string renderTarget = "Pass Default Post";

    static readonly int MainTexId = Shader.PropertyToID("_MainTex");
    static readonly int TempTargetId = Shader.PropertyToID("_TempTargetId");

    Default val;
    Material mate;
    RenderTargetIdentifier currTarget;

    public DefaultPass(RenderPassEvent evt)
    {
        renderPassEvent = evt;

        Shader shader = Shader.Find("PostProcessing/Default");
        if(shader == null)
        {
            Debug.LogError("Not Find Shader " + renderTarget);
            return;
        }
        mate = CoreUtils.CreateEngineMaterial(shader);

    }

    public void Setup(RenderTargetIdentifier currTarget)
    {
        this.currTarget = currTarget;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if(mate == null)
        {
            Debug.LogError("Not Create Material " + renderTarget);
            return;
        }

        if(!renderingData.cameraData.postProcessEnabled)
        {
            return;
        }

        var stack = VolumeManager.instance.stack;
        val = stack.GetComponent<Default>();

        if (val != null && val.IsActive())
        {
            CommandBuffer cmd = CommandBufferPool.Get();
            Render(cmd, ref renderingData);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    void Render(CommandBuffer cmd, ref RenderingData renderingData)
    {
        // 获取相机数据的引用
        ref var cameraData = ref renderingData.cameraData;
        // 获取当前的渲染目标
        var source = currTarget;
        // 临时渲染目标的标识符
        int destination = TempTargetId;

        // 计算渲染纹理的宽度和高度（此处未缩放，直接使用相机的像素宽度和高度）
        var w = (int)(cameraData.camera.scaledPixelWidth / 1);
        var h = (int)(cameraData.camera.scaledPixelHeight / 1);

        // 设置材质的颜色和强度属性
        mate.SetColor(Shader.PropertyToID("_BlenderColor"), val.BlenderColor.value);
        mate.SetFloat(Shader.PropertyToID("_Intensity"), val.Intensity.value);

        // 着色器通道（通常用于选择特定的着色器变体）
        int shaderPass = 0;
        // 设置全局纹理，用于着色器访问
        cmd.SetGlobalTexture(MainTexId, source);
        // 分配一个临时渲染目标
        cmd.GetTemporaryRT(destination, w, h, 0, FilterMode.Point, RenderTextureFormat.Default);

        // 将源纹理复制到临时目标
        cmd.Blit(source, destination);

        // 分配一个较小的临时渲染目标（宽高减半）
        cmd.GetTemporaryRT(destination, w / 2, h / 2, 0, FilterMode.Point, RenderTextureFormat.Default);
        // 使用材质和着色器通道将目标渲染到源
        cmd.Blit(destination, source, mate, shaderPass);
        // 再次将源纹理复制到临时目标
        cmd.Blit(source, destination);
    }
}

public class DefaultFeature : ScriptableRendererFeature
{
    DefaultPass pass;

    public override void Create()
    {
        pass = new DefaultPass(RenderPassEvent.BeforeRenderingPostProcessing);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        pass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(pass);
    }
}
