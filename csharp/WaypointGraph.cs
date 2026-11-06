using Godot;
using GArray = Godot.Collections.Array;
using GDict = Godot.Collections.Dictionary;

namespace HarrowsWake;

/// <summary>
/// Room-graph pathfinding shared by the Bellman (C#) and the Tallow-folk (GDScript).
/// Each map is a grid of 8 m rooms joined by doorway "links"; a link with a door id is
/// only walkable once Game.flag("door_&lt;id&gt;") is set. Breadth-first search over rooms,
/// returning the next doorway (or the next room's centre once in the doorway).
/// </summary>
[GlobalClass]
public partial class WaypointGraph : RefCounted
{
	GDict _maps = new GDict();
	float _cell = 8f;

	/// maps: {map_name: {"origin": Vector3, "rooms": {Vector2i: {...}}, "links": [[a, b, door_id], ...]}}
	public void setup(GDict maps, float cell)
	{
		_maps = maps;
		_cell = cell;
	}

	GDict Map(string map) => _maps[map].AsGodotDictionary();

	public Vector3 cell_center(string map, Vector2I c)
	{
		var o = Map(map)["origin"].AsVector3();
		return o + new Vector3(c.X * _cell, 0, c.Y * _cell);
	}

	public Vector2I cell_of(string map, Vector3 pos)
	{
		var o = Map(map)["origin"].AsVector3();
		return new Vector2I(Mathf.RoundToInt((pos.X - o.X) / _cell), Mathf.RoundToInt((pos.Z - o.Z) / _cell));
	}

	static GameState Game => (Engine.GetMainLoop() as SceneTree)?.Root.GetNodeOrNull<GameState>("Game");

	public Vector3 next_waypoint(string map, Vector3 from, Vector3 to, GArray blocked)
	{
		var rooms = Map(map)["rooms"].AsGodotDictionary();
		var links = Map(map)["links"].AsGodotArray();
		var a = cell_of(map, from);
		var b = cell_of(map, to);
		if (a == b || !rooms.ContainsKey(a) || !rooms.ContainsKey(b))
			return to;
		var game = Game;
		var prev = new System.Collections.Generic.Dictionary<Vector2I, Vector2I> { [a] = a };
		var q = new System.Collections.Generic.Queue<Vector2I>();
		q.Enqueue(a);
		while (q.Count > 0)
		{
			var c = q.Dequeue();
			if (c == b) break;
			foreach (var lv in links)
			{
				var l = lv.AsGodotArray();
				string door = l[2].AsString();
				if (door != "" && (game == null || !game.flag("door_" + door)))
					continue;
				var l0 = l[0].AsVector2I();
				var l1 = l[1].AsVector2I();
				Vector2I n;
				if (l0 == c) n = l1;
				else if (l1 == c) n = l0;
				else continue;
				if (prev.ContainsKey(n) || (blocked != null && blocked.Contains(n)))
					continue;
				prev[n] = c;
				q.Enqueue(n);
			}
		}
		if (!prev.ContainsKey(b))
			return from;
		var step = b;
		while (prev[step] != a)
			step = prev[step];
		var doorway = (cell_center(map, a) + cell_center(map, step)) / 2f;
		if (new Vector2(doorway.X - from.X, doorway.Z - from.Z).Length() < 0.9f)
			return cell_center(map, step);
		return doorway;
	}
}
