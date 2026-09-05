using Godot;
#if TOOLS
using Konado.Editor;
#endif
using Konado.Runtime.Api;
using Konado.Runtime.Resources;
using System;

namespace Konado.Tests;

public sealed partial class KonadoRuntimeTests : Node
{
	private int _failures;

	public override async void _Ready()
	{
		try
		{
			await RunTests();
		}
		catch (Exception exception)
		{
			GD.PrintErr(exception);
			_failures++;
		}

		GD.Print($"Konado.NET runtime tests: {_failures} failure(s)");
		GetTree().Quit(_failures == 0 ? 0 : 1);
	}

	private async System.Threading.Tasks.Task RunTests()
	{
#if TOOLS
		Check(
			KonadoDotNetPlugin.IsCorePluginEnabled(
				["res://addons/konado/plugin.cfg"]),
			"Konado.NET must recognize the core plugin in Godot's PackedStringArray setting.");
		Check(
			!KonadoDotNetPlugin.IsCorePluginEnabled([]),
			"Konado.NET must reject an editor plugin list without the core plugin.");
#endif

		var api = new DialogueManagerApi();
		AddChild(api);
		Check(!api.IsReady, "API must remain unbound before a manager enters the tree.");

		var managerScript = GD.Load<GDScript>(
			"res://tests/dotnet/fake_dialogue_manager.gd");
		var manager = managerScript.New().As<Node>();
		manager.Name = "AnyNodeName";
		AddChild(manager);
		await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
		Check(api.IsReady, "API must bind a manager added after its own _Ready().");
		Godot.Collections.Dictionary? reportedFailure = null;
		api.RuntimeFailureReported += failure => reportedFailure = failure;
		manager.EmitSignal(
			"runtime_failure_reported",
			new Godot.Collections.Dictionary { ["code"] = "camera.move_rejected" });
		Check(
			reportedFailure?["code"].AsString() == "camera.move_rejected",
			"DialogueManagerApi must forward structured runtime failure reports.");
		var resolvedAs = string.Empty;
		api.RuntimeFailureResolved += (_, resolution) => resolvedAs = resolution.ToString();
		manager.EmitSignal(
			"runtime_failure_resolved",
			new Godot.Collections.Dictionary { ["code"] = "camera.move_rejected" },
			new StringName("retry"));
		Check(
			resolvedAs == "retry",
			"DialogueManagerApi must forward the exact runtime recovery resolution.");
		Check(
			api.GetPendingRuntimeFailure()["code"].AsString() == "test.failure",
			"DialogueManagerApi must expose the pending structured failure.");
		Check(
			Array.IndexOf(api.GetRuntimeRecoveryActions(), "skip") >= 0,
			"DialogueManagerApi must expose the safe recovery action set.");
		Check(api.RetryFailedInstruction(), "DialogueManagerApi must forward Retry.");
		Check(
			manager.Get("recovery_action").AsString() == "retry",
			"Retry must retain its stable action identifier.");
		Check(api.SkipFailedInstruction(), "DialogueManagerApi must forward Skip.");
		Check(
			api.ContinueFailedCondition(false),
			"DialogueManagerApi must forward an explicit condition branch.");
		Check(
			manager.Get("recovery_action").AsString() == "continue_false",
			"Condition recovery must preserve the selected branch.");
		Check(api.StopAfterRuntimeFailure(), "DialogueManagerApi must forward Stop.");
		var forwardedShot = new KonadoShot();
		api.SetShot(forwardedShot);
		Check(
			manager.Get("last_shot").AsGodotObject() == forwardedShot.SourceResource,
			"DialogueManagerApi must forward KonadoShot resources to set_shot().");
		var characterList = new Resource();
		api.CharacterList = characterList;
		Check(
			manager.Get("character_list").AsGodotObject() == characterList,
			"DialogueManagerApi resource properties must map to the manager contract.");
		Check(api.CanRollback(), "DialogueManagerApi must expose rollback capability.");
		Check(api.Rollback(), "DialogueManagerApi must forward rollback requests.");
		Check(
			manager.Get("rollback_calls").AsInt32() == 1,
			"DialogueManagerApi must preserve the requested rollback distance.");
		Check(
			api.GetExecutionHistory().Count == 1,
			"DialogueManagerApi must expose immutable execution history records.");
		api.ClearExecutionHistory();
		Check(
			manager.Get("history_cleared").AsBool(),
			"DialogueManagerApi must forward history clearing.");
		var checkpoint = api.CreateCheckpoint("dotnet");
		Check(checkpoint == "checkpoint:dotnet", "Checkpoint identifiers must round-trip.");
		Check(api.RestoreCheckpoint(checkpoint), "Checkpoint restore must be forwarded.");

		manager.QueueFree();
		await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
		Check(!api.IsReady, "API must clear a freed manager.");

		var incompleteManager = new Node();
		AddChild(incompleteManager);
		Check(
			!api.BindDialogueManager(incompleteManager),
			"An incomplete forwarding contract must be rejected.");
		incompleteManager.QueueFree();

		var compiler = new KonadoScriptCompiler();
		var compiledShot = compiler.CompileFile(
			"res://sample/demo/demo_01.ks");
		Check(
			compiledShot != null,
			"Konado.NET must wrap compiler-produced KonadoShot script resources.");
		if (compiledShot != null)
		{
			Check(
				compiledShot.Program is { IsValid: true }
					&& compiledShot.InstructionCount > 0,
				"Compiler-produced KonadoShot wrappers must expose a valid Program.");
			var easingInstruction = compiler.CompileLine(
				"asyncam move cam1 ease_in_out 1.0",
				1,
				"res://tests/dotnet/easing.ks");
			Check(
				easingInstruction?.GetValue("transition").AsString() == "ease_in_out",
				"Konado.NET must expose typed instruction operands.");
			var instructionWithoutPath = compiler.CompileLine("end", 2);
			Check(
				instructionWithoutPath != null,
				"CompileLine must support the optional source path used by GDScript.");
		}

		var protectedShot = compiler.CompileFile(
			"res://sample/demo/demo_01.ks");
		Check(protectedShot != null, "Protection fixture must compile.");
		var expectedFirstLine = protectedShot == null
			? string.Empty
			: FindFirstDialogueContent(protectedShot);
		var buildKey = new byte[32];
		for (var index = 0; index < buildKey.Length; index++)
			buildKey[index] = (byte)index;
		Check(
			protectedShot != null
				&& protectedShot.SourceResource.Call("protect_script_for_export", buildKey).AsBool(),
			"Konado.NET test shot must accept export-time protection.");
		Check(
			protectedShot != null
				&& protectedShot.SourceResource.Call("is_script_protected").AsBool(),
			"Konado.NET test shot must enter the protected state.");
		Check(
			protectedShot != null
				&& expectedFirstLine.Length > 0
				&& FindFirstDialogueContent(protectedShot) == expectedFirstLine,
			"Konado.NET wrappers must transparently restore protected Programs.");
		Check(
			protectedShot != null
				&& !protectedShot.SourceResource.Call("is_script_protected").AsBool(),
			"Konado.NET wrappers must release protected buffers after restoration.");

		var storyLocalization = new StoryLocalizationApi();
		AddChild(storyLocalization);
		Check(
			storyLocalization.IsReady,
			"Story localization API must bind the KonadoStoryLocalization autoload.");
		var localizedShot = storyLocalization.LoadLocalizedScript(
			"res://sample/demo/demo_01.ks",
			"en",
			false);
		Check(
			localizedShot != null && localizedShot.InstructionCount > 0,
			"Internationalization API must wrap localized KonadoShot script resources.");
	}

	private static string FindFirstDialogueContent(KonadoShot shot)
	{
		for (var pc = 0; pc < shot.InstructionCount; pc++)
		{
			var instruction = shot.InstructionAt(pc);
			var content = instruction?.GetValue("content").AsString() ?? string.Empty;
			if (content.Length > 0)
				return content;
		}
		return string.Empty;
	}

	private void Check(bool condition, string message)
	{
		if (condition)
			return;
		GD.PrintErr($"ASSERTION FAILED: {message}");
		_failures++;
	}
}
