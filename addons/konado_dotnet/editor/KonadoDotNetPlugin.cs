#if TOOLS
using Godot;
using System;

namespace Konado.Editor;

[Tool]
public partial class KonadoDotNetPlugin : EditorPlugin
{
	private const string AutoloadName = "KonadoApi";
	private const string AutoloadPath = "res://addons/konado_dotnet/runtime/api/KonadoApi.cs";
	private const string CorePluginPath = "res://addons/konado/plugin.cfg";

	public override void _EnterTree()
	{
		if (!FileAccess.FileExists(CorePluginPath))
		{
			GD.PrintErr("Konado.NET requires the Konado core plugin.");
			return;
		}

		var enabledPlugins = ProjectSettings.GetSetting("editor_plugins/enabled")
			.AsStringArray();
		if (!IsCorePluginEnabled(enabledPlugins))
		{
			GD.PrintErr("Enable the Konado core plugin before enabling Konado.NET.");
			return;
		}

		EnsureAutoload();
	}

	internal static bool IsCorePluginEnabled(string[] enabledPlugins)
	{
		return Array.IndexOf(enabledPlugins, CorePluginPath) >= 0;
	}

	public override void _DisablePlugin()
	{
		var settingName = $"autoload/{AutoloadName}";
		if (!ProjectSettings.HasSetting(settingName))
			return;
		if (ResolveAutoloadPath(ProjectSettings.GetSetting(settingName)) == AutoloadPath)
			RemoveAutoloadSingleton(AutoloadName);
	}

	private void EnsureAutoload()
	{
		var settingName = $"autoload/{AutoloadName}";
		if (!ProjectSettings.HasSetting(settingName))
		{
			AddAutoloadSingleton(AutoloadName, AutoloadPath);
			return;
		}

		var configuredPath = ResolveAutoloadPath(ProjectSettings.GetSetting(settingName));
		if (configuredPath != AutoloadPath)
			GD.PrintErr(
				$"Cannot enable Konado.NET: autoload '{AutoloadName}' already points to '{configuredPath}'.");
	}

	private static string ResolveAutoloadPath(Variant value)
	{
		var path = value.AsString().TrimStart('*');
		return path.StartsWith("uid://", StringComparison.Ordinal)
			? ResourceUid.GetIdPath(ResourceUid.TextToId(path))
			: path;
	}
}
#endif
