using Godot;
using GArray = Godot.Collections.Array;
using GDict = Godot.Collections.Dictionary;

namespace HarrowsWake;

/// <summary>
/// Global game state, saves and settings (autoload "Game"; the class is GameState so
/// it doesn't clash with the autoload name). Ported from GDScript.
/// Members use snake_case names on purpose so the GDScript side (main.gd, player.gd,
/// hud.gd, touch.gd, tests) keeps calling them exactly as before: Game.state,
/// Game.flag("x"), Game.settings["brightness"], Game.settings_changed.connect(...).
/// </summary>
public partial class GameState : Node
{
	public string SAVE_PATH => "user://harrows_wake_save.json";
	public string SETTINGS_PATH => "user://settings.cfg";

	public GDict DEFAULTS => new GDict
	{
		{ "brightness", 1.0 },   // gamma lift in the post shader (0.6 - 1.8)
		{ "master", 10 }, { "music", 8 }, { "sfx", 9 },   // 0 - 10
		{ "stick_sens", 1.0 },   // touch stick sensitivity (0.5 - 2.0)
		{ "btn_size", 1.0 },     // touch button scale (0.7 - 1.5)
		{ "btn_opacity", 0.8 },  // touch button opacity (0.2 - 1.0)
		{ "tank", false },
		{ "crt", true },
		{ "invert_y", false },
		{ "shadows", true },     // flashlight shadows
		{ "fps", false },        // FPS counter
		{ "touch", true },       // on-screen controls (touchscreens only)
		{ "doors", true },       // RE-style door scene between rooms (skippable)
	};

	public GDict state = new GDict();
	public string mode = "title";   // title, play, note, menu, struggle, dead, win, endcard
	public bool tank_controls = true;
	public bool skip_title = false;
	public string input_kind = "keyboard";   // keyboard, gamepad, touch
	public bool crt_on = true;
	public GDict settings = new GDict();
	public int smoke_phase = 0;   // lets the smoke test survive a scene reload (death retry)

	[Signal] public delegate void settings_changedEventHandler();

	public override void _Ready()
	{
		_setup_input();
		_setup_buses();
		if (DisplayServer.IsTouchscreenAvailable())
			input_kind = "touch";
		load_settings();
		new_game();
	}

	public override void _Input(InputEvent e)
	{
		if (e is InputEventScreenTouch || e is InputEventScreenDrag)
			input_kind = "touch";
		else if (e is InputEventJoypadButton || (e is InputEventJoypadMotion jm && Mathf.Abs(jm.AxisValue) > 0.4f))
			input_kind = "gamepad";
		else if (e is InputEventKey || e is InputEventMouseButton)
			input_kind = "keyboard";
	}

	// Built once: glyph() runs every frame for the interaction prompt, so it must not allocate.
	static readonly System.Collections.Generic.Dictionary<string, System.Collections.Generic.Dictionary<string, string>> GLYPHS = new()
	{
		["keyboard"] = new() { ["interact"] = "[E]", ["run"] = "[Shift]", ["aim"] = "[K]", ["fire"] = "[J]", ["quick_turn"] = "[Q]", ["inventory"] = "[Tab]", ["cancel"] = "[Esc]", ["flashlight"] = "[F]", ["pause"] = "[Esc]", ["breath"] = "[Shift]" },
		["gamepad"] = new() { ["interact"] = "(A)", ["run"] = "(B)", ["aim"] = "(RB)", ["fire"] = "(X)", ["quick_turn"] = "(Y)", ["inventory"] = "(Back)", ["cancel"] = "(Back)", ["flashlight"] = "(LB)", ["pause"] = "(Start)", ["breath"] = "(B)" },
		["touch"] = new() { ["interact"] = "Tap A", ["run"] = "Hold RUN", ["aim"] = "Hold AIM", ["fire"] = "Tap FIRE", ["quick_turn"] = "Tap TURN", ["inventory"] = "Tap ITEMS", ["cancel"] = "Tap BACK", ["flashlight"] = "Tap LIGHT", ["pause"] = "Tap II", ["breath"] = "Hold RUN" },
	};

	/// Button name for prompts, matching the device the player is using right now.
	public string glyph(string action)
	{
		var table = GLYPHS.TryGetValue(input_kind, out var tb) ? tb : GLYPHS["keyboard"];
		return table.TryGetValue(action, out var g) ? g : action;
	}

	// ------------------------------------------------------------ settings

	void _setup_buses()
	{
		foreach (var b in new[] { "Music", "SFX" })
		{
			if (AudioServer.GetBusIndex(b) >= 0) continue;
			AudioServer.AddBus();
			int i = AudioServer.BusCount - 1;
			AudioServer.SetBusName(i, b);
			AudioServer.SetBusSend(i, "Master");
		}
	}

	public void load_settings()
	{
		settings = DEFAULTS.Duplicate();
		// Phones: camera-relative movement and no shadows by default (60 fps target).
		if (DisplayServer.IsTouchscreenAvailable())
			settings["shadows"] = false;
		else
			settings["tank"] = true;
		var cf = new ConfigFile();
		if (cf.Load(SETTINGS_PATH) == Error.Ok)
		{
			foreach (var k in DEFAULTS.Keys)
			{
				string key = k.AsString();
				if (cf.HasSectionKey("settings", key))
					settings[key] = cf.GetValue("settings", key);
			}
		}
		apply_settings();
	}

	public void save_settings()
	{
		var cf = new ConfigFile();
		foreach (var k in settings.Keys)
			cf.SetValue("settings", k.AsString(), settings[k]);
		cf.Save(SETTINGS_PATH);
	}

	public void set_setting(string k, Variant v)
	{
		settings[k] = v;
		apply_settings();
		save_settings();
	}

	public void apply_settings()
	{
		tank_controls = settings["tank"].AsBool();
		crt_on = settings["crt"].AsBool();
		_vol("Master", settings["master"].AsInt32());
		_vol("Music", settings["music"].AsInt32());
		_vol("SFX", settings["sfx"].AsInt32());
		EmitSignal(SignalName.settings_changed);
	}

	void _vol(string bus, int v)
	{
		int i = AudioServer.GetBusIndex(bus);
		if (i < 0) return;
		AudioServer.SetBusMute(i, v <= 0);
		AudioServer.SetBusVolumeDb(i, v > 0 ? Mathf.LinearToDb(Mathf.Clamp(v / 10f, 0f, 1f)) : -80f);
	}

	// ------------------------------------------------------------ state

	static GDict Pair(Variant dana, Variant jenny) => new GDict { { "dana", dana }, { "jenny", jenny } };

	public void new_game()
	{
		state = new GDict
		{
			{ "active", "jenny" },
			{ "inv", Pair(new GArray { "Handgun", "Green Herb" }, new GArray()) },
			{ "ammo", 10 },
			{ "hp", Pair(5, 3) },
			{ "tube", Pair(new GArray(), new GArray()) },
			{ "pos", Pair(new GArray(), new GArray()) },
			{ "rot", Pair(0.0, 0.0) },
			{ "flags", new GDict() },
			{ "light", Pair(false, false) },
			{ "saves", 0 },
			{ "time", 0.0 },
			{ "files", new GArray() },
		};
	}

	GArray Inv(string who) => state["inv"].AsGodotDictionary()[who].AsGodotArray();

	public bool has_item(string who, string item) => Inv(who).Contains(item);
	public void give(string who, string item) => Inv(who).Add(item);
	public void take(string who, string item) => Inv(who).Remove(item);

	public bool flag(string name)
	{
		var f = state["flags"].AsGodotDictionary();
		return f.ContainsKey(name) && f[name].AsBool();
	}

	public void set_flag(string name) => state["flags"].AsGodotDictionary()[name] = true;

	public bool has_save() => FileAccess.FileExists(SAVE_PATH);

	public void save_game()
	{
		state["saves"] = state["saves"].AsInt32() + 1;
		using var f = FileAccess.Open(SAVE_PATH, FileAccess.ModeFlags.Write);
		f?.StoreString(Json.Stringify(state));
	}

	public bool load_game()
	{
		if (!has_save()) return false;
		using var f = FileAccess.Open(SAVE_PATH, FileAccess.ModeFlags.Read);
		if (f == null) return false;
		var data = Json.ParseString(f.GetAsText());
		if (data.VariantType != Variant.Type.Dictionary) return false;
		state = data.AsGodotDictionary();
		if (!state.ContainsKey("files")) state["files"] = new GArray();
		return true;
	}

	/// Back to the title screen with a fresh state. The level is built from Game.state,
	/// so returning with the finished/dead run's flags would rebuild the world with the
	/// fuse and key already taken and NEW GAME would softlock (fixed in build-9).
	public void go_to_title()
	{
		new_game();
		skip_title = false;
		mode = "title";
		GetTree().ReloadCurrentScene();
	}

	public void restart(bool from_save)
	{
		if (!(from_save && load_game()))
			new_game();
		skip_title = true;
		GetTree().ReloadCurrentScene();
	}

	// ------------------------------------------------------------ input map

	static void _add_key(string action, params Key[] keys)
	{
		if (!InputMap.HasAction(action)) InputMap.AddAction(action, 0.25f);
		foreach (var k in keys)
			InputMap.ActionAddEvent(action, new InputEventKey { PhysicalKeycode = k });
	}

	static void _add_joy_button(string action, JoyButton b) =>
		InputMap.ActionAddEvent(action, new InputEventJoypadButton { ButtonIndex = b });

	static void _add_joy_axis(string action, JoyAxis a, float v) =>
		InputMap.ActionAddEvent(action, new InputEventJoypadMotion { Axis = a, AxisValue = v });

	static void _add_mouse(string action, MouseButton b) =>
		InputMap.ActionAddEvent(action, new InputEventMouseButton { ButtonIndex = b });

	void _setup_input()
	{
		_add_key("move_forward", Key.W, Key.Up);
		_add_key("move_back", Key.S, Key.Down);
		_add_key("move_left", Key.A, Key.Left);
		_add_key("move_right", Key.D, Key.Right);
		_add_key("run", Key.Shift);
		_add_key("interact", Key.E, Key.Space, Key.Enter);
		_add_key("aim", Key.K);
		_add_key("fire", Key.J);
		_add_key("quick_turn", Key.Q);
		_add_key("inventory", Key.Tab, Key.I);
		_add_key("cancel", Key.Escape, Key.Backspace);
		_add_key("pause", Key.Escape, Key.P);
		_add_key("flashlight", Key.F);
		_add_key("toggle_controls", Key.F1);
		_add_key("toggle_crt", Key.F2);
		_add_key("continue_game", Key.C);
		_add_joy_axis("move_forward", JoyAxis.LeftY, -1f);
		_add_joy_axis("move_back", JoyAxis.LeftY, 1f);
		_add_joy_axis("move_left", JoyAxis.LeftX, -1f);
		_add_joy_axis("move_right", JoyAxis.LeftX, 1f);
		_add_joy_button("move_forward", JoyButton.DpadUp);
		_add_joy_button("move_back", JoyButton.DpadDown);
		_add_joy_button("move_left", JoyButton.DpadLeft);
		_add_joy_button("move_right", JoyButton.DpadRight);
		_add_joy_button("interact", JoyButton.A);
		_add_joy_button("run", JoyButton.B);
		_add_joy_button("aim", JoyButton.RightShoulder);
		_add_joy_button("fire", JoyButton.X);
		_add_joy_button("quick_turn", JoyButton.Y);
		_add_joy_button("inventory", JoyButton.Back);
		_add_joy_button("pause", JoyButton.Start);
		_add_joy_button("flashlight", JoyButton.LeftShoulder);
		_add_joy_button("cancel", JoyButton.Back);
		_add_joy_button("continue_game", JoyButton.Y);
		_add_mouse("aim", MouseButton.Right);
		_add_mouse("fire", MouseButton.Left);
	}
}

