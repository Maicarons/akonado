using Godot;

namespace Konado.Runtime.Resources;

public partial class KonadoShot : KonadoData
{
	private static GDScript? _sourceScript;
	private const string SourceScriptPath = "res://addons/konado/runtime/dialogue/konado_shot.gd";

	public KonadoShot(GodotObject source) : base(source, LoadSourceScript(), "KonadoShot")
	{
	}

	public KonadoShot() : this(LoadSourceScript().New().AsGodotObject())
	{
	}

	private static GDScript LoadSourceScript()
	{
		if (!ResourceLoader.Exists(SourceScriptPath))
		{
			throw new System.InvalidOperationException("KonadoShot source script not found!");
		}

		return _sourceScript ??= ResourceLoader.Load<GDScript>(SourceScriptPath);
	}

	public static class GDScriptPropertyName
	{
		public static readonly StringName SourcePath = "source_path";
		public static readonly StringName ShotId = "shot_id";
		public static readonly StringName Program = "program";
		public static readonly StringName DependentCharacters = "dependent_characters";
	}

	public string SourcePath
	{
		get => SourceObject.Get(GDScriptPropertyName.SourcePath).As<string>();
		set => SourceObject.Set(GDScriptPropertyName.SourcePath, value);
	}

	public string ShotId
	{
		get => SourceObject.Get(GDScriptPropertyName.ShotId).As<string>();
		set => SourceObject.Set(GDScriptPropertyName.ShotId, value);
	}

	public KonadoProgram? Program
	{
		get
		{
			if (!EnsureScriptReady())
				return null;
			var source = SourceObject.Get(GDScriptPropertyName.Program).AsGodotObject();
			return source == null ? null : new KonadoProgram(source);
		}
	}

	public int InstructionCount =>
		SourceObject.Call(GDScriptMethodName.InstructionCount).AsInt32();
	public int EntryPc => SourceObject.Call(GDScriptMethodName.EntryPc).AsInt32();
	public string ProgramFingerprint =>
		SourceObject.Call(GDScriptMethodName.ProgramFingerprint).AsString();

	public Godot.Collections.Array<string> DependentCharacters
	{
		get => SourceObject.Get(GDScriptPropertyName.DependentCharacters).AsGodotArray<string>();
		set => SourceObject.Set(GDScriptPropertyName.DependentCharacters, value);
	}

	public KonadoInstruction? InstructionAt(int pc)
	{
		var result = SourceObject.Call(GDScriptMethodName.InstructionAt, pc).AsGodotObject();
		return result == null ? null : new KonadoInstruction(result);
	}

	public bool EnsureScriptReady() =>
		SourceObject.Call(GDScriptMethodName.EnsureScriptReady).AsBool();

	private static class GDScriptMethodName
	{
		public static readonly StringName InstructionCount = "instruction_count";
		public static readonly StringName EntryPc = "entry_pc";
		public static readonly StringName InstructionAt = "instruction_at";
		public static readonly StringName ProgramFingerprint = "program_fingerprint";
		public static readonly StringName EnsureScriptReady = "ensure_script_ready";
	}
}
