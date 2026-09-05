using Godot;

namespace Konado.Runtime.Api;

public sealed partial class KonadoApi : Node
{
	public bool IsApiReady { get; private set; }
	public static KonadoApi? Instance { get; private set; }
	public static DialogueManagerApi? DialogueManagerApi { get; private set; }
	public static StoryLocalizationApi? StoryLocalizationApi { get; private set; }

	public override void _Ready()
	{
		Instance = this;

		DialogueManagerApi = GetNodeOrNull<DialogueManagerApi>("DialogueManagerApi");
		if (DialogueManagerApi == null)
		{
			DialogueManagerApi = new DialogueManagerApi
			{
				Name = "DialogueManagerApi",
			};
			AddChild(DialogueManagerApi);
		}

		StoryLocalizationApi = GetNodeOrNull<StoryLocalizationApi>(
			"StoryLocalizationApi");
		if (StoryLocalizationApi == null)
		{
			StoryLocalizationApi = new StoryLocalizationApi
			{
				Name = "StoryLocalizationApi",
			};
			AddChild(StoryLocalizationApi);
		}

		IsApiReady = true;
	}

	public override void _ExitTree()
	{
		IsApiReady = false;
		if (Instance != this)
			return;
		Instance = null;
		DialogueManagerApi = null;
		StoryLocalizationApi = null;
	}
}
