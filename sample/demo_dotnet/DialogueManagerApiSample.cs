using Godot;
using Konado.Runtime.Api;
using Konado.Runtime.Resources;

namespace Konado.Sample;

/// <summary>
/// 这个是DialogueManagerApi的使用示例
/// </summary>
public partial class DialogueManagerApiSample : Node
{
	public override void _Ready()
	{
		var compiler = new KonadoScriptCompiler();
		var shot = compiler.CompileFile("res://sample/demo/demo_01.ks");
		if (shot == null)
		{
			GD.PushError("解析示例脚本失败。");
			return;
		}

		GD.Print($"Compiled {shot.InstructionCount} KonadoScript instructions.");

		var dialogueManagerApi = KonadoApi.DialogueManagerApi;
		if (dialogueManagerApi == null)
			return;
		if (!dialogueManagerApi.IsReady && !dialogueManagerApi.BindDialogueManager())
			return;

		GD.Print("Ready");
		StartDialogue(dialogueManagerApi, shot);
	}

	private static void StartDialogue(DialogueManagerApi dialogueManagerApi, KonadoShot shot)
	{
		dialogueManagerApi.ShotStart += () =>
		{
			GD.Print("Shot Start");
		};

		dialogueManagerApi.ShotEnd += () =>
		{
			GD.Print("Shot End");
		};
		dialogueManagerApi.DialogueLineStart += (string instructionId) =>
		{
			GD.Print(instructionId);
		};
		dialogueManagerApi.DialogueLineEnd += (string instructionId) =>
		{
			GD.Print(instructionId);
		};

		if (KonadoApi.Instance?.IsApiReady != true)
			return;

		GD.Print("API Ready");
		dialogueManagerApi.SetShot(shot);
		dialogueManagerApi.InitDialogue();
		dialogueManagerApi.StartDialogue();
	}
}
