using Godot;

namespace Konado.Runtime.Resources;

public sealed partial class KonadoScriptCompiler : RefCounted
{
	private static GDScript? _sourceScript;
	private const string SourceScriptPath = "res://addons/konado/language/compiler/konado_script_compiler.gd";
	private GodotObject _source;

	/// <summary>
	/// Create a new instance of the <see cref="KonadoScriptCompiler"/> class.
	/// </summary>
	/// <exception cref="System.InvalidOperationException"></exception>
	public KonadoScriptCompiler()
	{
		_source = LoadSourceScript().New().AsGodotObject();
	}

	public KonadoScriptCompiler(GodotObject source)
	{
		if (source is null || !IsInstanceValid(source))
		{
			throw new System.InvalidOperationException("Source object is not valid!");
		}

		var sourceScript = LoadSourceScript();
		if (source.GetScript().AsGodotObject() != sourceScript)
		{
			throw new System.InvalidOperationException("Source Object is not a valid source!");
		}

		_source = source;
	}

	private static GDScript LoadSourceScript()
	{
		if (!ResourceLoader.Exists(SourceScriptPath))
		{
			throw new System.InvalidOperationException("Source script not found!");
		}

		return _sourceScript ??= ResourceLoader.Load<GDScript>(SourceScriptPath);
	}

	public static class GDScriptMethodName
	{
		public static readonly StringName CompileFile = "compile_file";
		public static readonly StringName CompileLine = "compile_line";
	}

	public KonadoShot? CompileFile(string path)
	{
		var source = _source.Call(GDScriptMethodName.CompileFile, path).As<Resource>();
		return source == null ? null : new KonadoShot(source);
	}

	public KonadoInstruction? CompileLine(string line, long lineNumber, string path = "")
	{
		var source = _source.Call(GDScriptMethodName.CompileLine, line, lineNumber, path)
			.AsGodotObject();
		return source == null ? null : new KonadoInstruction(source);
	}
}
