using Godot;

namespace Konado.Runtime.Resources;

/// <summary>Read-only view over one instruction in a compiled Konado Program.</summary>
public sealed class KonadoInstruction
{
	internal KonadoInstruction(GodotObject source)
	{
		if (source is null || !GodotObject.IsInstanceValid(source))
			throw new System.InvalidOperationException("Invalid KonadoInstruction source.");
		Source = source;
	}

	internal GodotObject Source { get; }
	public int Opcode => Source.Call(MethodName.Opcode).AsInt32();
	public string StableKey => Source.Call(MethodName.StableKey).AsString();
	public int SourceLine => Source.Call(MethodName.SourceLine).AsInt32();
	public int NextPc => Source.Call(MethodName.NextPc).AsInt32();
	public int TruePc => Source.Call(MethodName.TruePc).AsInt32();
	public int FalsePc => Source.Call(MethodName.FalsePc).AsInt32();

	public Variant GetValue(string name, Variant defaultValue = default)
	{
		System.ArgumentException.ThrowIfNullOrWhiteSpace(name);
		return Source.Call(MethodName.Value, name, defaultValue);
	}

	private static class MethodName
	{
		public static readonly StringName Opcode = "opcode";
		public static readonly StringName StableKey = "stable_key";
		public static readonly StringName SourceLine = "source_line";
		public static readonly StringName NextPc = "next_pc";
		public static readonly StringName TruePc = "true_pc";
		public static readonly StringName FalsePc = "false_pc";
		public static readonly StringName Value = "value";
	}
}
