using SDL2;
using System;
using System.Collections;
using System.Reflection;
using System.IO;
using System.Diagnostics;
using System.Threading;

namespace Strawberry
{
	static
	{
		static public Game Game;
	}

	public class Game
	{
		public readonly List<VirtualInput> VirtualInputs;
		public readonly String Title;
		public readonly int Width;
		public readonly int Height;
		
		private Scene scene;
		private Scene switchToScene;
		private bool updating;

		public SDL.Renderer* Renderer { get; private set; }

		private SDL.Rect screenRect;
		private SDL.Window* window;
		private SDL.Surface* screen;
		private bool* keyboardState;
		private SDL.SDL_GameController* gamepad;
		private int32 updateCounter;

		public this(String windowTitle, int32 width, int32 height)
			: base()
		{
			Game = this;
			VirtualInputs = new List<VirtualInput>();

			Title = windowTitle;
			Width = width;
			Height = height;

			screenRect = SDL.Rect(0, 0, width, height);

			String exePath = scope .();
			Environment.GetExecutableFilePath(exePath);
			String exeDir = scope .();
			Path.GetDirectoryPath(exePath, exeDir);
			Directory.SetCurrentDirectory(exeDir);

			SDL.Init(.Video | .Events | .Audio | .GameController);
			SDL.EventState(.JoyAxisMotion, .Disable);
			SDL.EventState(.JoyBallMotion, .Disable);
			SDL.EventState(.JoyHatMotion, .Disable);
			SDL.EventState(.JoyButtonDown, .Disable);
			SDL.EventState(.JoyButtonUp, .Disable);
			SDL.EventState(.JoyDeviceAdded, .Disable);
			SDL.EventState(.JoyDeviceRemoved, .Disable);

			window = SDL.CreateWindow(Title, .Centered, .Centered, screenRect.w, screenRect.h, .Shown);
			Renderer = SDL.CreateRenderer(window, -1, .Accelerated);
			screen = SDL.GetWindowSurface(window);
			SDLImage.Init(.PNG | .JPG);
			SDLMixer.OpenAudio(44100, SDLMixer.MIX_DEFAULT_FORMAT, 2, 4096);

			SDLTTF.Init();

			gamepad = SDL.GameControllerOpen(0);
		}

		public ~this()
		{
			if (scene != null)
				delete scene;

			if (switchToScene != scene && switchToScene != null)
				delete switchToScene;

			delete VirtualInputs;

			Game = null;
		}

		public void Run()
		{
			Stopwatch sw = scope .();
			sw.Start();
			int curPhysTickCount = 0;

			while (true)
			{
				SDL.Event event;
				if (SDL.PollEvent(out event) != 0 && event.type == .Quit)
					return;

				// Fixed 60 Hz update
				double msPerTick = 1000 / 60.0;
				int newPhysTickCount = (int)(sw.ElapsedMilliseconds / msPerTick);

				int addTicks = newPhysTickCount - curPhysTickCount;
				if (curPhysTickCount == 0)
				{
					// Initial render
					Render();
				}
				else
				{
					keyboardState = SDL.GetKeyboardState(null);
					SDL.GameControllerUpdate();

					addTicks = Math.Min(addTicks, 20); // Limit catchup
					if (addTicks > 0)
					{
						for (int i < addTicks)
						{
							updateCounter++;
							Update();
						}
						Render();
					}
					else
						Thread.Sleep(1);
				}

				curPhysTickCount = newPhysTickCount;
			}
		}

		public virtual void Update()
		{
			//Input
			for (var i in VirtualInputs)
				i.Update();

			//Switch scenes
			if (switchToScene != scene)
			{
				if (scene != null)
					delete scene;
				scene = switchToScene;
				scene.Started();
			}

			if (scene != null)
				scene.Update();

			Time.PreviousElapsed = Time.Elapsed;
			Time.Elapsed += Time.Delta;
		}

		public void Render()
		{
			SDL.SetRenderDrawColor(Renderer, 0, 0, 0, 255);
			SDL.RenderClear(Renderer);
			Draw();
			SDL.RenderPresent(Renderer);
		}

		public virtual void Draw()
		{
			if (Scene != null)
				Scene.Draw();
		}

		public Scene Scene
		{
			get
			{
				return scene;
			}

			set
			{
				if (switchToScene != scene && switchToScene != null)
					delete switchToScene;
				switchToScene = value;
			}
		}

		// Input

		public bool KeyCheck(SDL.Scancode key)
		{
			if (keyboardState == null)
				return false;
			return keyboardState[(int)key];
		}

		public bool GamepadButtonCheck(SDL.SDL_GameControllerButton button)
		{
			if (gamepad == null)
				return false;
			return SDL.GameControllerGetButton(gamepad, button) == 1;
		}

		public float GamepadAxisCheck(SDL.SDL_GameControllerAxis axis)
		{
			if (gamepad == null)
				return 0;

			let val = SDL.GameControllerGetAxis(gamepad, axis);
			if (val == 0)
				return 0;
			else if (val > 0)
				return val / 32767f;
			else
				return val / 32768f;
		}
	}
}
