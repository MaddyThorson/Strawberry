using System.Collections;
using System;

namespace Strawberry
{
	public class Scene
	{
		public float TimeStarted { get; private set; }

		private List<Entity> entities = new .() ~ delete _;
		private HashSet<Entity> toRemove = new .() ~ delete _;
		private HashSet<Entity> toAdd = new .() ~ delete _;
		private Dictionary<Type, List<Component>> componentTracker = new .() ~ DeleteDictionaryAndValues!(_);

		public this()
		{
			for (let type in Tracker.AssignmentLists.Keys)
				componentTracker.Add(type, new List<Component>());
			for (let type in Tracker.Interfaces)
				componentTracker.Add(type, new List<Component>());
		}

		public ~this()
		{
			for (var e in entities)
				if (e.DeleteOnRemove)
					delete e;

			for (var e in toAdd)
				if (e.DeleteOnRemove)
					delete e;
		}

		public virtual void Started()
		{
			TimeStarted = Time.Elapsed;
		}

		public virtual void Update()
		{
			ForEach<IEarlyUpdate>(scope (u) => u.EarlyUpdate());
			ForEach<IUpdate>(scope (u) => u.Update());
			ForEach<ILateUpdate>(scope (u) => u.LateUpdate());
			UpdateLists();
		}

		public virtual void Draw()
		{
			ForEach<IDraw>(scope (d) => d.Draw());
		}

		/*
			Entities
		*/

		public Entity Add(Entity e)
		{
			if (e.Scene == null)
				toAdd.Add(e);
			return e;
		}

		public Entity Remove(Entity e)
		{
			if (e.Scene == this)
				toRemove.Add(e);
			return e;
		}

		private void UpdateLists()
		{
			if (toRemove.Count > 0)
			{
				for (let e in toRemove)
				{
					entities.Remove(e);
					e.[Friend]Removed();
					if (e.DeleteOnRemove)
						delete e;
				}

				toRemove.Clear();
			}

			if (toAdd.Count > 0)
			{
				for (let e in toAdd)
				{
					entities.Add(e);
					e.[Friend]Added(this);
				}
				toAdd.Clear();
			}

			for (let e in entities)
				e.[Friend]UpdateLists();
			for (let e in entities)
				e.[Friend]AwakeCheck();
		}

		/*
			Tracking
		*/

		private void TrackComponent(Component c)
		{
			for (let t in Tracker.AssignmentLists[c.GetType()]) {
				// If component type not in tracker, add to tracker
				var match = false;
				for (let kvPair in componentTracker) {
					if (kvPair.key == t) {
						match = true;
					}
				}
				if (!match) {
					componentTracker.Add(t, new List<Component>());
				}
				componentTracker[t].Add(c);
			}
		}

		private void UntrackComponent(Component c)
		{
			for (let t in Tracker.AssignmentLists[c.GetType()])
				componentTracker[t].Remove(c);
		}

		/*
			Time
		*/

		public float TimeElapsed =>	Time.Elapsed - TimeStarted;
		public float PreviousTimeElapsed =>	Time.PreviousElapsed - TimeStarted;

		public bool TimeOnInterval(float interval, float offset = 0)
		{
			return (int)((TimeElapsed - offset) / interval) != (int)((PreviousTimeElapsed - offset) / interval);
		}

		public bool TimeBetweenInterval(float interval, float offset = 0)
		{
			return (TimeElapsed - offset) % (interval * 2) >= interval;
		}

		/*
			Finding Components
		*/

		public int Count<T>() where T : Component
		{
			return componentTracker[typeof(T)].Count;
		}

		public int Count<T>(delegate bool(T) condition) where T : Component
		{
			int count = 0;
			for (T c in componentTracker[typeof(T)])
				if (condition(c))
					count++;
			return count;
		}

		public bool Check<T>(delegate bool(T) condition) where T : Component
		{
			for (T c in componentTracker[typeof(T)])
				if (condition(c))
					return true;
			return false;
		}


		public bool Check<T>(Point point) where T : Component, IHasHitbox
		{
			for (T c in componentTracker[typeof(T)])
				if (c.Hitbox.Check(point))
					return true;
			return false;
		}

		public bool Check<T>(Point point, delegate bool(T) condition) where T : Component, IHasHitbox
		{
			for (T c in componentTracker[typeof(T)])
				if (c.Hitbox.Check(point) && condition(c))
					return true;
			return false;
		}

		public bool Check<T>(Rect rect) where T : Component, IHasHitbox
		{
			for (T c in componentTracker[typeof(T)])
				if (c.Hitbox.Check(rect))
					return true;
			return false;
		}

		public bool Check<T>(Rect rect, delegate bool(T) condition) where T : Component, IHasHitbox
		{
			for (T c in componentTracker[typeof(T)])
				if (c.Hitbox.Check(rect) && condition(c))
					return true;
			return false;
		}

		public T First<T>() where T : Component
		{
			for (T c in componentTracker[typeof(T)])
				return c;
			return null;
		}

		public T First<T>(delegate bool(T) condition) where T : Component
		{
			for (T c in componentTracker[typeof(T)])
				if (condition(c))
					return c;
			return null;
		}

		public T First<T>(Point point) where T : Component, IHasHitbox
		{
			for (T c in componentTracker[typeof(T)])
				if (c.Hitbox.Check(point))
					return c as T;
			return null;
		}

		public T First<T>(Point point, delegate bool(T) condition) where T : Component, IHasHitbox
		{
			for (T c in componentTracker[typeof(T)])
				if (c.Hitbox.Check(point) && condition(c))
					return c as T;
			return null;
		}

		public T First<T>(Rect rect) where T : Component, IHasHitbox
		{
			for (T c in componentTracker[typeof(T)])
				if (c.Hitbox.Check(rect))
					return c as T;
			return null;
		}

		public T First<T>(Rect rect, delegate bool(T) condition) where T : Component, IHasHitbox
		{
			for (T c in componentTracker[typeof(T)])
				if (c.Hitbox.Check(rect) && condition(c))
					return c as T;
			return null;
		}

		public List<T> All<T>(List<T> into) where T : Component
		{
			for (T c in componentTracker[typeof(T)])
				into.Add(c as T);
			return into;
		}

		public List<T> All<T>(List<T> into, delegate bool(T) condition) where T : Component
		{
			for (T c in componentTracker[typeof(T)])
				if (condition(c))
					into.Add(c as T);
			return into;
		}

		public List<T> All<T>(Point point, List<T> into) where T : Component, IHasHitbox
		{
			for (T c in componentTracker[typeof(T)])
				if (c.Hitbox.Check(point))
					into.Add(c as T);
			return into;
		}

		public List<T> All<T>(Point point, List<T> into, delegate bool(T) condition) where T : Component, IHasHitbox
		{
			for (T c in componentTracker[typeof(T)])
				if (c.Hitbox.Check(point) && condition(c))
					into.Add(c as T);
			return into;
		}

		public List<T> All<T>(Rect rect, List<T> into, delegate bool(T) condition) where T : Component, IHasHitbox
		{
			for (T c in componentTracker[typeof(T)])
				if (c.Hitbox.Check(rect) && condition(c))
					into.Add(c as T);
			return into;
		}

		public void ForEach<T>(delegate void(T) action) where T : interface
		{
			List<Component> list;
			if (componentTracker.TryGetValue(typeof(T), out list))
				for (let c in list)
					action(c as T);
		}

		public void ForEach<T>(delegate void(T) action) where T : Component
		{
			List<Component> list;
			if (componentTracker.TryGetValue(typeof(T), out list))
				for (T c in list)
					action(c);
		}
	}
}
