using Godot;

namespace Konado.Runtime.Resources;

public partial class KonadoData : Resource
{
	private static GDScript? _sourceScript;
	private const string SourceScriptPath = "res://addons/konado/runtime/konado_data.gd";
	protected GodotObject SourceObject { get; }

	public KonadoData(GodotObject source) : this(source, LoadSourceScript(), "KonadoData")
	{
	}

	protected KonadoData(
		GodotObject source,
		GDScript expectedSourceScript,
		string expectedSourceName)
	{
		if (source is not Resource || !IsInstanceValid(source))
		{
			throw new System.InvalidOperationException("Source object is not a valid Resource!");
		}

		if (!InheritsSourceScript(source, expectedSourceScript))
		{
			throw new System.InvalidOperationException(
				$"Source object is not a {expectedSourceName} resource!");
		}

		SourceObject = source;
	}

	public KonadoData() : this(LoadSourceScript().New().AsGodotObject())
	{
	}

	public Resource SourceResource => (Resource)SourceObject;

	private static GDScript LoadSourceScript()
	{
		if (!ResourceLoader.Exists(SourceScriptPath))
		{
			throw new System.InvalidOperationException("KonadoData source script not found!");
		}

		return _sourceScript ??= ResourceLoader.Load<GDScript>(SourceScriptPath);
	}

	internal static bool InheritsSourceScript(GodotObject source, GDScript sourceScript)
	{
		var script = source.GetScript().AsGodotObject() as Script;
		while (script != null)
		{
			if (script == sourceScript)
				return true;

			script = script.GetBaseScript();
		}

		return false;
	}
}
