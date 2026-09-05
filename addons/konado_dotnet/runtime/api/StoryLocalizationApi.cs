using Godot;
using Konado.Runtime.Resources;

namespace Konado.Runtime.Api;

/// <summary>
/// KonadoScript-specific localization operations.
/// Locale selection and UI translation intentionally use Godot's
/// <see cref="TranslationServer"/> directly.
/// </summary>
public sealed partial class StoryLocalizationApi : Node
{
	private const string AutoloadName = "KonadoStoryLocalization";

	private Node? _source;

	public bool IsReady => _source != null
		&& IsInstanceValid(_source)
		&& HasStoryLocalizationContract(_source);

	public Node? Source => IsReady ? _source : null;

	public override void _Ready()
	{
		Bind();
	}

	public override void _ExitTree()
	{
		_source = null;
	}

	public bool Bind(Node? source = null)
	{
		var target = source ?? GetTree().Root.GetNodeOrNull<Node>(AutoloadName);
		_source = target != null && HasStoryLocalizationContract(target) ? target : null;
		return IsReady;
	}

	public string ResolveScriptPath(
		string scriptPath,
		string locale = "",
		bool warnOnFallback = true)
	{
		var source = GetReadySource();
		return source == null
			? string.Empty
			: source.Call(
				GDScriptMethodName.ResolveScriptPath,
				scriptPath,
				locale,
				warnOnFallback).As<string>();
	}

	public KonadoShot? LoadLocalizedScript(
		string scriptPath,
		string locale = "",
		bool warnOnFallback = true)
	{
		var source = GetReadySource();
		if (source == null)
			return null;
		var shot = source.Call(
			GDScriptMethodName.LoadLocalizedScript,
			scriptPath,
			locale,
			warnOnFallback).As<Resource>();
		return shot == null ? null : new KonadoShot(shot);
	}

	private Node? GetReadySource()
	{
		return Source ?? (Bind() ? Source : null);
	}

	private static bool HasStoryLocalizationContract(Node source)
	{
		return IsInstanceValid(source)
			&& source.HasMethod(GDScriptMethodName.ResolveScriptPath)
			&& source.HasMethod(GDScriptMethodName.LoadLocalizedScript);
	}

	private static class GDScriptMethodName
	{
		public static readonly StringName ResolveScriptPath = "resolve_script_path";
		public static readonly StringName LoadLocalizedScript = "load_localized_script";
	}
}
