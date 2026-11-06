using Godot;
using GArray = Godot.Collections.Array;
using GDict = Godot.Collections.Dictionary;

namespace HarrowsWake;

/// <summary>
/// The Bellman: unkillable stalker. Sees (cone, longer when your flashlight is on),
/// hears, telegraphs before a chase, searches, notices if you hid in front of him,
/// can be stunned. Ported from bellman.gd. Talks to the GDScript side (main.gd, the
/// actor model, the player) through Call/Get; members are snake_case so main.gd and
/// the tests use him exactly as before (bellman.state == bellman.S.CHASE, bellman.stun(4.5)).
/// </summary>
[GlobalClass]
public partial class Bellman : CharacterBody3D
{
	public const int DORMANT = 0, PATROL = 1, INVESTIGATE = 2, CHASE = 3, SEARCH = 4, FOUND = 5, STUNNED = 6, LEAVE = 7, NOTICE = 8;

	/// Enum mirror for GDScript: bellman.S.CHASE etc. Built once (main.gd reads it
	/// every frame inside the light loop, so it must not allocate a new dictionary).
	GDict _s = null;
	public GDict S => _s ??= new GDict
	{
		{ "DORMANT", DORMANT }, { "PATROL", PATROL }, { "INVESTIGATE", INVESTIGATE }, { "CHASE", CHASE },
		{ "SEARCH", SEARCH }, { "FOUND", FOUND }, { "STUNNED", STUNNED }, { "LEAVE", LEAVE }, { "NOTICE", NOTICE },
	};

	public int state = DORMANT;
	public Node main = null;
	public string map = "jenny";
	public Vector3 target = Vector3.Zero;
	public Vector3 last_seen = Vector3.Zero;
	public float lost_t = 0f;
	public float timer = 0f;
	public float think_t = 0f;
	public float bell_t = 2f;
	public float dormant_t = 14f;
	public bool sees = false;
	public GArray patrol_cells = new GArray { new Vector2I(0, 0), new Vector2I(1, 0), new Vector2I(2, 0), new Vector2I(1, -1) };
	public GArray blocked = new GArray { new Vector2I(1, 1) };   // he never enters the Mail Room
	public Vector2I home_cell = new Vector2I(2, 0);
	public Node3D mesh_root = null;
	public float t = 0f;
	public float step_t = 0f;
	public float notice_t = 0f;
	public float grab_cd = 0f;
	public float grabbing_t = 0f;
	// Stuck watchdog: a target he can't reach (locked door, a prop in the way, a cell
	// he won't enter) used to freeze him in place forever, bell ringing.
	public float stuck_t = 0f;
	public int stuck_n = 0;
	Vector3 _stuck_pos = Vector3.Zero;
	// Waypoint cache: the room-graph search runs a few times a second, not every tick.
	Vector3 _wp = Vector3.Zero;
	Vector3 _wp_for = new Vector3(1e6f, 0, 0);
	float _wp_t = 0f;

	GameState _game = null;
	GameState Game => _game ??= GetNode<GameState>("/root/Game");

	Node3D _player = null;
	Node3D Player
	{
		get
		{
			if (_player == null || !IsInstanceValid(_player))
				_player = main.Get("players").AsGodotDictionary()[map].As<Node3D>();
			return _player;
		}
	}

	public override void _PhysicsProcess(double dd)
	{
		float delta = (float)dd;
		var v = Velocity;
		if (!IsOnFloor())
			v.Y -= 9.8f * delta;
		if (Game.mode != "play" || Game.state["active"].AsString() != map)
		{
			v.X = 0; v.Z = 0;
			Velocity = v;
			MoveAndSlide();
			return;
		}
		Velocity = v;
		t += delta;
		grab_cd = Mathf.Max(0f, grab_cd - delta);
		grabbing_t = Mathf.Max(0f, grabbing_t - delta);
		var p = Player;
		think_t -= delta;
		if (think_t <= 0f)
		{
			think_t = 0.15f;
			_perceive(p);
		}

		float spd = 0f;
		switch (state)
		{
			case DORMANT:
				dormant_t -= delta;
				if (dormant_t <= 0f) _pick_patrol();
				break;
			case PATROL:
				spd = 1.35f;
				if (_arrived(target))
				{
					spd = 0f;
					timer -= delta;
					if (timer <= 0f) _pick_patrol();
				}
				break;
			case INVESTIGATE:
				spd = 2.1f;
				if (_arrived(target)) { state = SEARCH; timer = 4f; }
				break;
			case NOTICE:
			{
				// Readable telegraph: he stops, turns to you, the bell shrieks - then comes.
				notice_t -= delta;
				var to = p.GlobalPosition - GlobalPosition;
				var r = Rotation;
				r.Y = Mathf.LerpAngle(r.Y, Mathf.Atan2(-to.X, -to.Z), 8f * delta);
				Rotation = r;
				if (notice_t <= 0f) { state = CHASE; lost_t = 0f; }
				break;
			}
			case CHASE:
				spd = p.Get("exhausted").AsBool() ? 2.7f : 3.0f;
				target = last_seen;
				if (sees) lost_t = 0f; else lost_t += delta;
				if (lost_t > 3f || (_arrived(target) && !sees)) { state = SEARCH; timer = 5f; }
				if (sees && _flat_dist(p.GlobalPosition) < 1.3f && grab_cd <= 0f)
				{
					grabbing_t = 0.6f;
					main.Call("bellman_grab", 1.0);
				}
				break;
			case SEARCH:
				spd = 1.6f;
				if (_arrived(target))
				{
					spd = 0f;
					timer -= delta;
					var r = Rotation; r.Y += delta * 1.6f; Rotation = r;
					if (timer <= 0f) _pick_patrol();
				}
				break;
			case FOUND:
				spd = 2.6f;
				target = p.GlobalPosition;
				// He knows where you are - but not forever. If you got away (out of sight,
				// not hiding, or into the Mail Room he won't enter) he gives up and searches.
				if (sees || p.Get("hidden_in").AsString() != "") lost_t = 0f; else lost_t += delta;
				if (lost_t > 4f || blocked.Contains((Vector2I)main.Call("cell_of", map, p.GlobalPosition)))
				{
					state = SEARCH;
					target = last_seen;
					timer = 4f;
					break;
				}
				if (_flat_dist(p.GlobalPosition) < 1.6f && grab_cd <= 0f)
				{
					grabbing_t = 0.6f;
					main.Call("bellman_grab", 1.6);
				}
				break;
			case STUNNED:
				timer -= delta;
				if (timer <= 0f)
				{
					state = LEAVE;
					target = (Vector3)main.Call("cell_center", map, home_cell);
				}
				break;
			case LEAVE:
				spd = 1.5f;
				if (_arrived(target)) { state = DORMANT; dormant_t = (float)GD.RandRange(12.0, 20.0); }
				break;
		}

		v = Velocity;
		v.X = 0; v.Z = 0;
		_watchdog(delta, spd > 0f && !_arrived(target));
		if (spd > 0f && !_arrived(target))
		{
			_wp_t -= delta;
			if (_wp_t <= 0f || _wp_for.DistanceTo(target) > 0.5f || _flat_dist(_wp) < 0.9f)
			{
				_wp = (Vector3)main.Call("next_waypoint", map, GlobalPosition, target, blocked);
				_wp_for = target;
				_wp_t = 0.2f;
			}
			var wp = _wp;
			var dir = wp - GlobalPosition;
			dir.Y = 0;
			if (dir.Length() > 0.05f)
			{
				dir = dir.Normalized();
				v.X = dir.X * spd;
				v.Z = dir.Z * spd;
				var r = Rotation;
				r.Y = Mathf.LerpAngle(r.Y, Mathf.Atan2(-dir.X, -dir.Z), 6f * delta);
				Rotation = r;
			}
		}
		Velocity = v;
		MoveAndSlide();

		// The bell: you hear him before you see him.
		bell_t -= delta;
		if (bell_t <= 0f)
		{
			float interval = state switch
			{
				CHASE or FOUND or NOTICE => 0.85f,
				INVESTIGATE or SEARCH => 1.8f,
				DORMANT => 7f,
				STUNNED => 99f,
				_ => 3.2f,
			};
			bell_t = interval;
			main.Call("play_sfx", "bell", GlobalPosition + new Vector3(0, 1.8f, 0), 0.0);
		}

		// Heavy, unhurried footsteps - audible through walls before he's in view.
		float hs = new Vector2(Velocity.X, Velocity.Z).Length();
		if (hs > 0.2f)
		{
			step_t += delta * hs;
			if (step_t > 1.05f)
			{
				step_t = 0f;
				main.Call("play_step", GlobalPosition, main.Call("floor_at", map, GlobalPosition), 2.0, 0.62, 16.0);
			}
		}
		_animate(hs);
	}

	void _animate(float hs)
	{
		if (mesh_root == null) return;
		float lean = mesh_root.Get("lean").AsSingle();
		if (state == STUNNED)
		{
			mesh_root.Call("play_anim", "Hit_Chest", 0.1, 0.5);
			mesh_root.Set("lean", Mathf.Lerp(lean, 0.35f, 0.1f));
			return;
		}
		mesh_root.Set("lean", Mathf.Lerp(lean, 0.06f, 0.1f));   // slight forward stoop
		if (grabbing_t > 0f)
			mesh_root.Call("play_anim", "Punch_Cross", 0.05, 1.3);
		else if (state == NOTICE)
			mesh_root.Call("play_anim", "Idle_Torch", 0.1, 2.5);   // raises the bell
		else if (hs > 0.2f)
			mesh_root.Call("play_anim", "Walk_Formal", 0.25, Mathf.Clamp(hs / 1.05f, 0.6f, 3.0f));   // stride-matched
		else
			mesh_root.Call("play_anim", "Idle_Torch", 0.3, 0.6);
	}

	/// If he has been trying to move for ~3 s but has barely moved, give up on the target.
	void _watchdog(float delta, bool moving)
	{
		if (!moving)
		{
			stuck_t = 0f; stuck_n = 0; _stuck_pos = GlobalPosition;
			return;
		}
		stuck_t += delta;
		if (stuck_t < 1f) return;
		stuck_t = 0f;
		stuck_n = _flat_dist(_stuck_pos) < 0.25f ? stuck_n + 1 : 0;
		_stuck_pos = GlobalPosition;
		if (stuck_n < 3) return;
		stuck_n = 0;
		unstick();
	}

	public void unstick()
	{
		_wp_t = 0f;
		switch (state)
		{
			case CHASE:
			case FOUND:
				state = SEARCH; target = GlobalPosition; timer = 3f; break;
			case LEAVE:
				state = DORMANT; dormant_t = (float)GD.RandRange(8.0, 14.0); break;
			default:
				_pick_patrol(); break;
		}
	}

	bool _los(Node3D p) => main.Call("los", GlobalPosition + new Vector3(0, 1.7f, 0), p.GlobalPosition + new Vector3(0, 1f, 0)).AsBool();

	void _perceive(Node3D p)
	{
		sees = false;
		if (p.Get("hidden_in").AsString() != "" || state == STUNNED || state == LEAVE)
			return;
		var pc = (Vector2I)main.Call("cell_of", map, p.GlobalPosition);
		if (blocked.Contains(pc)) return;
		var to = p.GlobalPosition - GlobalPosition;
		to.Y = 0;
		float d = to.Length();
		float rng = p.Get("light_on").AsBool() ? 16f : 11f;   // a lit flashlight gives you away
		if (d > rng) return;
		var fwd = -GlobalTransform.Basis.Z;
		float ang = d > 0.01f ? Mathf.RadToDeg(fwd.AngleTo(to.Normalized())) : 0f;
		if ((ang < 60f || d < 2.5f) && _los(p))
		{
			sees = true;
			last_seen = p.GlobalPosition;
			if (state != CHASE && state != FOUND && state != NOTICE)
			{
				state = NOTICE;
				notice_t = d > 3f ? 0.9f : 0.45f;
				lost_t = 0f;
				main.Call("on_chase_start");
			}
		}
	}

	public void hear(Vector3 pos, float radius)
	{
		if (state == CHASE || state == FOUND || state == STUNNED || state == LEAVE || state == NOTICE)
			return;
		if (blocked.Contains((Vector2I)main.Call("cell_of", map, pos)))
			return;
		if (GlobalPosition.DistanceTo(pos) < radius)
		{
			state = INVESTIGATE;
			target = pos;
		}
	}

	public void on_player_hide(Node3D p)
	{
		if (state == CHASE || state == NOTICE)
		{
			bool close = _flat_dist(p.GlobalPosition) < 7f;
			if (close && lost_t < 0.6f && _los(p))
			{
				state = FOUND;
				lost_t = 0f;
				main.Call("show_message", "He saw you hide...", 3.5);
			}
			else
			{
				state = SEARCH;
				target = last_seen;
				timer = 5f;
			}
		}
	}

	public void on_scream()
	{
		if (state != STUNNED && state != LEAVE)
		{
			state = FOUND;
			lost_t = 0f;
		}
	}

	public void stun(float duration = 4f)
	{
		state = STUNNED;
		timer = duration;
		sees = false;
		grab_cd = duration + 2.5f;
	}

	public bool is_hunting() => state == CHASE || state == FOUND || state == NOTICE;

	void _pick_patrol()
	{
		state = PATROL;
		var c = patrol_cells[(int)(GD.Randi() % (uint)patrol_cells.Count)].AsVector2I();
		target = (Vector3)main.Call("cell_center", map, c) + new Vector3((float)GD.RandRange(-2.0, 2.0), 0, (float)GD.RandRange(-2.0, 2.0));
		timer = (float)GD.RandRange(1.5, 3.5);
	}

	bool _arrived(Vector3 pos) => _flat_dist(pos) < 0.7f;

	float _flat_dist(Vector3 pos) => new Vector2(pos.X - GlobalPosition.X, pos.Z - GlobalPosition.Z).Length();
}
