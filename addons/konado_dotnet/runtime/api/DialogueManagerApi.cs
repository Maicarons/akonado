using Godot;
using Konado.Runtime.Resources;

namespace Konado.Runtime.Api;

/// <summary>
/// Konado DialogueManager C# API，用于与 Konado DialogueManager 节点进行交互
/// </summary>
public sealed partial class DialogueManagerApi : Node
{
	private const string DialogueManagerScriptPath = "res://addons/konado/runtime/dialogue/konado_dialogue_manager.gd";

	private Node? _source;
	private bool _sourceHasContract;
	private bool _treeSignalsConnected;

	public bool IsReady => _source != null
		&& IsInstanceValid(_source)
		&& _sourceHasContract;
	public Node? Source => IsReady ? _source : null;

	public override void _Ready()
	{
		ConnectTreeSignals();
		TryBindDialogueManager(null, false);
	}

	public bool BindDialogueManager(Node? source = null)
	{
		return TryBindDialogueManager(source, true);
	}

	private bool TryBindDialogueManager(Node? source, bool reportFailure)
	{
		var target = source ?? FindDialogueManager(GetTree().Root);

		if (target == null || !IsDialogueManager(target))
		{
			ClearSource();
			if (reportFailure)
			{
				GD.PrintErr(source == null
					? "未找到 KonadoDialogueManager 节点。请确保场景中已实例化 Konado 对话管理器。"
					: "指定节点不是有效的 KonadoDialogueManager。");
			}
			return false;
		}

		if (_source != target)
		{
			DisconnectSignals(_source);
			_source = target;
		}
		_sourceHasContract = true;

		ConnectSignals();
		if (reportFailure)
			GD.Print($"Konado.NET 已绑定对话管理器：{target.GetPath()}");
		return true;
	}

	private void ConnectTreeSignals()
	{
		if (_treeSignalsConnected)
			return;
		var tree = GetTree();
		tree.NodeAdded += OnTreeNodeAdded;
		tree.NodeRemoved += OnTreeNodeRemoved;
		_treeSignalsConnected = true;
	}

	private void DisconnectTreeSignals()
	{
		if (!_treeSignalsConnected || !IsInsideTree())
			return;
		var tree = GetTree();
		tree.NodeAdded -= OnTreeNodeAdded;
		tree.NodeRemoved -= OnTreeNodeRemoved;
		_treeSignalsConnected = false;
	}

	private void OnTreeNodeAdded(Node node)
	{
		if (!IsReady && IsDialogueManager(node))
			TryBindDialogueManager(node, false);
	}

	private void OnTreeNodeRemoved(Node node)
	{
		if (node == _source)
			ClearSource();
	}

	private static Node? FindDialogueManager(Node? currentNode)
	{
		if (currentNode == null)
			return null;

		if (IsDialogueManager(currentNode))
			return currentNode;

		foreach (Node child in currentNode.GetChildren())
		{
			var foundNode = FindDialogueManager(child);
			if (foundNode != null)
				return foundNode;
		}

		return null;
	}

	private static bool IsDialogueManager(Node? node)
	{
		if (node == null || !IsInstanceValid(node))
			return false;

		if (ResourceLoader.Exists(DialogueManagerScriptPath))
		{
			var sourceScript = ResourceLoader.Load<GDScript>(DialogueManagerScriptPath);
			if (node.GetScript().AsGodotObject() == sourceScript)
				return true;
		}

		return HasDialogueManagerContract(node);
	}

	private static bool HasDialogueManagerContract(Node? node)
	{
		return node != null
			&& IsInstanceValid(node)
			&& node.HasSignal(GDScriptSignalName.ShotStart)
			&& node.HasSignal(GDScriptSignalName.ShotEnd)
			&& node.HasSignal(GDScriptSignalName.DialogueLineStart)
			&& node.HasSignal(GDScriptSignalName.DialogueLineEnd)
			&& node.HasSignal(GDScriptSignalName.CustomSignal)
			&& node.HasSignal(GDScriptSignalName.RuntimeFailed)
			&& node.HasSignal(GDScriptSignalName.RuntimeFailureReported)
			&& node.HasSignal(GDScriptSignalName.RuntimeFailureResolved)
			&& node.HasMethod(GDScriptMethodName.InitDialogue)
			&& node.HasMethod(GDScriptMethodName.SetShot)
			&& node.HasMethod(GDScriptMethodName.StartDialogue)
			&& node.HasMethod(GDScriptMethodName.StopDialogue)
			&& node.HasMethod(GDScriptMethodName.StartAutoplay)
			&& node.HasMethod(GDScriptMethodName.GetDialogueVariable)
			&& node.HasMethod(GDScriptMethodName.SaveGame)
			&& node.HasMethod(GDScriptMethodName.LoadGame)
			&& node.HasMethod(GDScriptMethodName.DeleteSave)
			&& node.HasMethod(GDScriptMethodName.GetSaveInfo)
			&& node.HasMethod(GDScriptMethodName.GetAllSaveInfo)
			&& node.HasMethod(GDScriptMethodName.ReloadLocalizedScript)
			&& node.HasMethod(GDScriptMethodName.EmitWaitSignal)
			&& HasProperty(node, GDScriptPropertyName.PendingRuntimeFailure)
			&& node.HasMethod(GDScriptMethodName.ResolveRuntimeFailure)
			&& node.HasMethod(GDScriptMethodName.CanRollback)
			&& node.HasMethod(GDScriptMethodName.Rollback)
			&& node.HasMethod(GDScriptMethodName.GetExecutionHistory)
			&& node.HasMethod(GDScriptMethodName.ClearExecutionHistory)
			&& node.HasMethod(GDScriptMethodName.CreateCheckpoint)
			&& node.HasMethod(GDScriptMethodName.RestoreCheckpoint);
	}

	private static bool HasProperty(Node node, StringName propertyName)
	{
		foreach (var property in node.GetPropertyList())
		{
			if (property.ContainsKey("name") && property["name"].AsStringName() == propertyName)
				return true;
		}
		return false;
	}

	private Node? GetReadySource()
	{
		var source = Source;
		if (source != null)
			return source;

		ClearSource();
		return BindDialogueManager() ? Source : null;
	}

	private void ClearSource()
	{
		DisconnectSignals(_source);
		_source = null;
		_sourceHasContract = false;
	}

	private static bool HasCallable(Callable callable)
		=> callable.Delegate != null || callable.Target != null;

	private static void ConnectSignal(Node? source, StringName signalName, Callable callable)
	{
		if (source == null
			|| !IsInstanceValid(source)
			|| !source.HasSignal(signalName)
			|| !HasCallable(callable)
			|| source.IsConnected(signalName, callable))
		{
			return;
		}

		source.Connect(signalName, callable);
	}

	private static void DisconnectSignal(Node? source, StringName signalName, Callable callable)
	{
		if (source == null
			|| !IsInstanceValid(source)
			|| !HasCallable(callable)
			|| !source.IsConnected(signalName, callable))
		{
			return;
		}

		source.Disconnect(signalName, callable);
	}

	private void ConnectSignals()
	{
		var source = Source;
		if (source == null)
			return;

		if (_shotStartSignal != null)
		{
			if (!HasCallable(_shotStartSignalCallable))
				_shotStartSignalCallable = Callable.From(() => _shotStartSignal?.Invoke());
			ConnectSignal(source, GDScriptSignalName.ShotStart, _shotStartSignalCallable);
		}

		if (_shotEndSignal != null)
		{
			if (!HasCallable(_shotEndSignalCallable))
				_shotEndSignalCallable = Callable.From(() => _shotEndSignal?.Invoke());
			ConnectSignal(source, GDScriptSignalName.ShotEnd, _shotEndSignalCallable);
		}

		if (_dialogueLineStartSignal != null)
		{
			if (!HasCallable(_dialogueLineStartSignalCallable))
				_dialogueLineStartSignalCallable = Callable.From(
					(string nodeId) => _dialogueLineStartSignal?.Invoke(nodeId));
			ConnectSignal(source, GDScriptSignalName.DialogueLineStart, _dialogueLineStartSignalCallable);
		}

		if (_dialogueLineEndSignal != null)
		{
			if (!HasCallable(_dialogueLineEndSignalCallable))
				_dialogueLineEndSignalCallable = Callable.From(
					(string nodeId) => _dialogueLineEndSignal?.Invoke(nodeId));
			ConnectSignal(source, GDScriptSignalName.DialogueLineEnd, _dialogueLineEndSignalCallable);
		}

		if (_customSignal != null)
		{
			if (!HasCallable(_customSignalCallable))
				_customSignalCallable = Callable.From(
					(string content) => _customSignal?.Invoke(content));
			ConnectSignal(source, GDScriptSignalName.CustomSignal, _customSignalCallable);
		}

		if (_runtimeFailedSignal != null)
		{
			if (!HasCallable(_runtimeFailedSignalCallable))
				_runtimeFailedSignalCallable = Callable.From(
					(string message, string instructionId, int sourceLine) =>
						_runtimeFailedSignal?.Invoke(message, instructionId, sourceLine));
			ConnectSignal(source, GDScriptSignalName.RuntimeFailed, _runtimeFailedSignalCallable);
		}

		if (_runtimeFailureReportedSignal != null && source.HasSignal(GDScriptSignalName.RuntimeFailureReported))
		{
			if (!HasCallable(_runtimeFailureReportedSignalCallable))
				_runtimeFailureReportedSignalCallable = Callable.From(
					(Godot.Collections.Dictionary failure) =>
						_runtimeFailureReportedSignal?.Invoke(failure));
			ConnectSignal(
				source,
				GDScriptSignalName.RuntimeFailureReported,
				_runtimeFailureReportedSignalCallable);
		}

		if (_runtimeFailureResolvedSignal != null && source.HasSignal(GDScriptSignalName.RuntimeFailureResolved))
		{
			if (!HasCallable(_runtimeFailureResolvedSignalCallable))
				_runtimeFailureResolvedSignalCallable = Callable.From(
					(Godot.Collections.Dictionary failure, StringName resolution) =>
						_runtimeFailureResolvedSignal?.Invoke(failure, resolution));
			ConnectSignal(
				source,
				GDScriptSignalName.RuntimeFailureResolved,
				_runtimeFailureResolvedSignalCallable);
		}
	}

	private void DisconnectSignals(Node? source)
	{
		DisconnectSignal(source, GDScriptSignalName.ShotStart, _shotStartSignalCallable);
		DisconnectSignal(source, GDScriptSignalName.ShotEnd, _shotEndSignalCallable);
		DisconnectSignal(source, GDScriptSignalName.DialogueLineStart, _dialogueLineStartSignalCallable);
		DisconnectSignal(source, GDScriptSignalName.DialogueLineEnd, _dialogueLineEndSignalCallable);
		DisconnectSignal(source, GDScriptSignalName.CustomSignal, _customSignalCallable);
		DisconnectSignal(source, GDScriptSignalName.RuntimeFailed, _runtimeFailedSignalCallable);
		DisconnectSignal(
			source,
			GDScriptSignalName.RuntimeFailureReported,
			_runtimeFailureReportedSignalCallable);
		DisconnectSignal(
			source,
			GDScriptSignalName.RuntimeFailureResolved,
			_runtimeFailureResolvedSignalCallable);
	}

	public override void _ExitTree()
	{
		DisconnectTreeSignals();
		ClearSource();
	}

	public static class GDScriptSignalName
	{
		public static readonly StringName ShotStart = "shot_start";
		public static readonly StringName ShotEnd = "shot_end";
		public static readonly StringName DialogueLineStart = "dialogue_line_start";
		public static readonly StringName DialogueLineEnd = "dialogue_line_end";
		public static readonly StringName CustomSignal = "custom_signal";
		public static readonly StringName RuntimeFailed = "runtime_failed";
		public static readonly StringName RuntimeFailureReported = "runtime_failure_reported";
		public static readonly StringName RuntimeFailureResolved = "runtime_failure_resolved";
	}

	public delegate void ShotStartSignalHandler();
	private ShotStartSignalHandler? _shotStartSignal;
	private Callable _shotStartSignalCallable;
	public event ShotStartSignalHandler ShotStart
	{
		add
		{
			_shotStartSignal += value;
			if (GetReadySource() != null)
				ConnectSignals();
		}
		remove
		{
			_shotStartSignal -= value;
			if (_shotStartSignal is not null) return;
			DisconnectSignal(_source, GDScriptSignalName.ShotStart, _shotStartSignalCallable);
			_shotStartSignalCallable = default;
		}
	}

	public delegate void ShotEndSignalHandler();
	private ShotEndSignalHandler? _shotEndSignal;
	private Callable _shotEndSignalCallable;
	public event ShotEndSignalHandler ShotEnd
	{
		add
		{
			_shotEndSignal += value;
			if (GetReadySource() != null)
				ConnectSignals();
		}
		remove
		{
			_shotEndSignal -= value;
			if (_shotEndSignal is not null) return;
			DisconnectSignal(_source, GDScriptSignalName.ShotEnd, _shotEndSignalCallable);
			_shotEndSignalCallable = default;
		}

	}

	public delegate void DialogueLineStartSignalHandler(string instructionId);
	private DialogueLineStartSignalHandler? _dialogueLineStartSignal;
	private Callable _dialogueLineStartSignalCallable;
	public event DialogueLineStartSignalHandler DialogueLineStart
	{
		add
		{
			_dialogueLineStartSignal += value;
			if (GetReadySource() != null)
				ConnectSignals();
		}
		remove
		{
			_dialogueLineStartSignal -= value;
			if (_dialogueLineStartSignal is not null) return;
			DisconnectSignal(_source, GDScriptSignalName.DialogueLineStart, _dialogueLineStartSignalCallable);
			_dialogueLineStartSignalCallable = default;
		}
	}

	public delegate void DialogueLineEndSignalHandler(string instructionId);
	private DialogueLineEndSignalHandler? _dialogueLineEndSignal;
	private Callable _dialogueLineEndSignalCallable;
	public event DialogueLineEndSignalHandler DialogueLineEnd
	{
		add
		{
			_dialogueLineEndSignal += value;
			if (GetReadySource() != null)
				ConnectSignals();
		}
		remove
		{
			_dialogueLineEndSignal -= value;
			if (_dialogueLineEndSignal is not null) return;
			DisconnectSignal(_source, GDScriptSignalName.DialogueLineEnd, _dialogueLineEndSignalCallable);
			_dialogueLineEndSignalCallable = default;
		}
	}

	public delegate void CustomSignalHandler(string content);
	private CustomSignalHandler? _customSignal;
	private Callable _customSignalCallable;
	public event CustomSignalHandler CustomSignal
	{
		add
		{
			_customSignal += value;
			if (GetReadySource() != null)
				ConnectSignals();
		}
		remove
		{
			_customSignal -= value;
			if (_customSignal is not null) return;
			DisconnectSignal(_source, GDScriptSignalName.CustomSignal, _customSignalCallable);
			_customSignalCallable = default;
		}
	}

	public delegate void RuntimeFailedSignalHandler(
		string message,
		string instructionId,
		int sourceLine);
	private RuntimeFailedSignalHandler? _runtimeFailedSignal;
	private Callable _runtimeFailedSignalCallable;
	public event RuntimeFailedSignalHandler RuntimeFailed
	{
		add
		{
			_runtimeFailedSignal += value;
			if (GetReadySource() != null)
				ConnectSignals();
		}
		remove
		{
			_runtimeFailedSignal -= value;
			if (_runtimeFailedSignal is not null) return;
			DisconnectSignal(_source, GDScriptSignalName.RuntimeFailed, _runtimeFailedSignalCallable);
			_runtimeFailedSignalCallable = default;
		}
	}

	/// <summary>
	/// Detailed atomic-runtime failure data, including the stable code, operation,
	/// resource, source path, source line, instruction ID and program counter.
	/// </summary>
	public delegate void RuntimeFailureReportedSignalHandler(
		Godot.Collections.Dictionary failure);
	private RuntimeFailureReportedSignalHandler? _runtimeFailureReportedSignal;
	private Callable _runtimeFailureReportedSignalCallable;
	public event RuntimeFailureReportedSignalHandler RuntimeFailureReported
	{
		add
		{
			_runtimeFailureReportedSignal += value;
			if (GetReadySource() != null)
				ConnectSignals();
		}
		remove
		{
			_runtimeFailureReportedSignal -= value;
			if (_runtimeFailureReportedSignal is not null) return;
			DisconnectSignal(
				_source,
				GDScriptSignalName.RuntimeFailureReported,
				_runtimeFailureReportedSignalCallable);
			_runtimeFailureReportedSignalCallable = default;
		}
	}

	/// <summary>
	/// Raised after a paused runtime failure has been settled by a recovery action,
	/// timeline restore, shot replacement, reinitialization, or playback stop.
	/// </summary>
	public delegate void RuntimeFailureResolvedSignalHandler(
		Godot.Collections.Dictionary failure,
		StringName resolution);
	private RuntimeFailureResolvedSignalHandler? _runtimeFailureResolvedSignal;
	private Callable _runtimeFailureResolvedSignalCallable;
	public event RuntimeFailureResolvedSignalHandler RuntimeFailureResolved
	{
		add
		{
			_runtimeFailureResolvedSignal += value;
			if (GetReadySource() != null)
				ConnectSignals();
		}
		remove
		{
			_runtimeFailureResolvedSignal -= value;
			if (_runtimeFailureResolvedSignal is not null) return;
			DisconnectSignal(
				_source,
				GDScriptSignalName.RuntimeFailureResolved,
				_runtimeFailureResolvedSignalCallable);
			_runtimeFailureResolvedSignalCallable = default;
		}
	}

	public static class GDScriptMethodName
	{
		public static readonly StringName InitDialogue = "init_dialogue";
		public static readonly StringName SetShot = "set_shot";
		public static readonly StringName StartDialogue = "start_dialogue";
		public static readonly StringName StopDialogue = "stop_dialogue";
		public static readonly StringName StartAutoplay = "start_autoplay";
		public static readonly StringName GetDialogueVariable = "get_dialogue_variable";
		public static readonly StringName SaveGame = "save_game";
		public static readonly StringName LoadGame = "load_game";
		public static readonly StringName DeleteSave = "delete_save";
		public static readonly StringName GetSaveInfo = "get_save_info";
		public static readonly StringName GetAllSaveInfo = "get_all_save_info";
		public static readonly StringName ReloadLocalizedScript = "reload_localized_script";
		public static readonly StringName EmitWaitSignal = "emit_wait_signal";
		public static readonly StringName ResolveRuntimeFailure = "resolve_runtime_failure";
		public static readonly StringName CanRollback = "can_rollback";
		public static readonly StringName Rollback = "rollback";
		public static readonly StringName GetExecutionHistory = "get_execution_history";
		public static readonly StringName ClearExecutionHistory = "clear_execution_history";
		public static readonly StringName CreateCheckpoint = "create_checkpoint";
		public static readonly StringName RestoreCheckpoint = "restore_checkpoint";
	}

	public static class GDScriptPropertyName
	{
		public static readonly StringName CharacterList = "character_list";
		public static readonly StringName BackgroundList = "background_list";
		public static readonly StringName BgmList = "background_music_list";
		public static readonly StringName VoiceList = "voice_list";
		public static readonly StringName SoundEffectList = "sound_effect_list";
		public static readonly StringName VariableStore = "variable_store";
		public static readonly StringName PendingRuntimeFailure = "pending_runtime_failure";
	}

	/// <summary>
	/// 初始化对话，调用 Konado DialogueManager 节点的 init_dialogue 方法
	/// </summary>
	public void InitDialogue()
	{
		GetReadySource()?.Call(GDScriptMethodName.InitDialogue);
	}

	public void InitDialogue(Callable callback)
	{
		GetReadySource()?.Call(GDScriptMethodName.InitDialogue, callback);
	}

	public void SetShot(Resource shot)
	{
		System.ArgumentNullException.ThrowIfNull(shot);
		GetReadySource()?.Call(GDScriptMethodName.SetShot, shot);
	}

	public void SetShot(KonadoShot shot)
	{
		System.ArgumentNullException.ThrowIfNull(shot);
		SetShot(shot.SourceResource);
	}

	/// <summary>
	/// 开始对话，调用 Konado DialogueManager 节点的 start_dialogue 方法
	/// </summary>
	public void StartDialogue()
	{
		GetReadySource()?.Call(GDScriptMethodName.StartDialogue);
	}

	/// <summary>
	/// 停止对话，调用 Konado DialogueManager 节点的 stop_dialogue 方法
	/// </summary>
	public void StopDialogue()
	{
		GetReadySource()?.Call(GDScriptMethodName.StopDialogue);
	}

	public void StartAutoplay(bool value)
	{
		GetReadySource()?.Call(GDScriptMethodName.StartAutoplay, value);
	}

	public Resource? CharacterList
	{
		get => GetReadySource()?.Get(GDScriptPropertyName.CharacterList).As<Resource>();
		set => SetResourceProperty(GDScriptPropertyName.CharacterList, value);
	}

	public Resource? BackgroundList
	{
		get => GetReadySource()?.Get(GDScriptPropertyName.BackgroundList).As<Resource>();
		set => SetResourceProperty(GDScriptPropertyName.BackgroundList, value);
	}

	public Resource? BgmList
	{
		get => GetReadySource()?.Get(GDScriptPropertyName.BgmList).As<Resource>();
		set => SetResourceProperty(GDScriptPropertyName.BgmList, value);
	}

	public Resource? VoiceList
	{
		get => GetReadySource()?.Get(GDScriptPropertyName.VoiceList).As<Resource>();
		set => SetResourceProperty(GDScriptPropertyName.VoiceList, value);
	}

	public Resource? SoundEffectList
	{
		get => GetReadySource()?.Get(GDScriptPropertyName.SoundEffectList).As<Resource>();
		set => SetResourceProperty(GDScriptPropertyName.SoundEffectList, value);
	}

	public Resource? VariableStore
	{
		get => GetReadySource()?.Get(GDScriptPropertyName.VariableStore).As<Resource>();
		set => SetResourceProperty(GDScriptPropertyName.VariableStore, value);
	}

	private void SetResourceProperty(StringName propertyName, Resource? value)
	{
		var source = GetReadySource();
		if (source == null)
			return;
		if (value == null)
			source.Set(propertyName, default);
		else
			source.Set(propertyName, value);
	}

	public Godot.Collections.Dictionary GetDialogueVariable(string key)
	{
		var source = GetReadySource();
		return source == null
			? new Godot.Collections.Dictionary()
			: source.Call(GDScriptMethodName.GetDialogueVariable, key).AsGodotDictionary();
	}

	public bool SaveGame(int saveId)
	{
		var source = GetReadySource();
		return source != null && source.Call(GDScriptMethodName.SaveGame, saveId).As<bool>();
	}

	public bool LoadGame(int saveId)
	{
		var source = GetReadySource();
		return source != null && source.Call(GDScriptMethodName.LoadGame, saveId).As<bool>();
	}

	public bool DeleteSave(int saveId)
	{
		var source = GetReadySource();
		return source != null && source.Call(GDScriptMethodName.DeleteSave, saveId).As<bool>();
	}

	public Godot.Collections.Dictionary GetSaveInfo(int saveId)
	{
		var source = GetReadySource();
		return source == null
			? new Godot.Collections.Dictionary()
			: source.Call(GDScriptMethodName.GetSaveInfo, saveId).AsGodotDictionary();
	}

	public Godot.Collections.Array<Godot.Collections.Dictionary> GetAllSaveInfo()
	{
		var source = GetReadySource();
		return source == null
			? new Godot.Collections.Array<Godot.Collections.Dictionary>()
			: source.Call(GDScriptMethodName.GetAllSaveInfo)
				.AsGodotArray<Godot.Collections.Dictionary>();
	}

	public bool ReloadLocalizedScript(string locale)
	{
		var source = GetReadySource();
		return source != null
			&& source.Call(GDScriptMethodName.ReloadLocalizedScript, locale).As<bool>();
	}

	public void EmitWaitSignal(string signalName)
	{
		GetReadySource()?.Call(GDScriptMethodName.EmitWaitSignal, signalName);
	}

	public Godot.Collections.Dictionary GetPendingRuntimeFailure()
	{
		var source = GetReadySource();
		return source == null
			? new Godot.Collections.Dictionary()
			: source.Get(GDScriptPropertyName.PendingRuntimeFailure).AsGodotDictionary();
	}

	public string[] GetRuntimeRecoveryActions()
	{
		var failure = GetPendingRuntimeFailure();
		return failure.ContainsKey("recovery_actions")
			? failure["recovery_actions"].AsStringArray()
			: [];
	}

	public bool ResolveRuntimeFailure(string action)
	{
		System.ArgumentException.ThrowIfNullOrWhiteSpace(action);
		var source = GetReadySource();
		return source != null
			&& source.Call(GDScriptMethodName.ResolveRuntimeFailure, new StringName(action)).AsBool();
	}

	public bool RetryFailedInstruction()
	{
		return ResolveRuntimeFailure("retry");
	}

	public bool SkipFailedInstruction()
	{
		return ResolveRuntimeFailure("skip");
	}

	public bool ContinueFailedCondition(bool useTrueBranch)
	{
		return ResolveRuntimeFailure(useTrueBranch ? "continue_true" : "continue_false");
	}

	public bool StopAfterRuntimeFailure()
	{
		return ResolveRuntimeFailure("stop");
	}

	public bool CanRollback(int steps = 1)
	{
		System.ArgumentOutOfRangeException.ThrowIfLessThan(steps, 1);
		var source = GetReadySource();
		return source != null && source.Call(GDScriptMethodName.CanRollback, steps).AsBool();
	}

	public bool Rollback(int steps = 1)
	{
		System.ArgumentOutOfRangeException.ThrowIfLessThan(steps, 1);
		var source = GetReadySource();
		return source != null && source.Call(GDScriptMethodName.Rollback, steps).AsBool();
	}

	public Godot.Collections.Array<Godot.Collections.Dictionary> GetExecutionHistory(int limit = 0)
	{
		System.ArgumentOutOfRangeException.ThrowIfNegative(limit);
		var source = GetReadySource();
		return source == null
			? new Godot.Collections.Array<Godot.Collections.Dictionary>()
			: source.Call(GDScriptMethodName.GetExecutionHistory, limit)
				.AsGodotArray<Godot.Collections.Dictionary>();
	}

	public void ClearExecutionHistory()
	{
		GetReadySource()?.Call(GDScriptMethodName.ClearExecutionHistory);
	}

	public string CreateCheckpoint(string label = "")
	{
		var source = GetReadySource();
		return source == null
			? string.Empty
			: source.Call(GDScriptMethodName.CreateCheckpoint, label).AsString();
	}

	public bool RestoreCheckpoint(string checkpointId)
	{
		System.ArgumentException.ThrowIfNullOrWhiteSpace(checkpointId);
		var source = GetReadySource();
		return source != null
			&& source.Call(GDScriptMethodName.RestoreCheckpoint, checkpointId).AsBool();
	}
}
