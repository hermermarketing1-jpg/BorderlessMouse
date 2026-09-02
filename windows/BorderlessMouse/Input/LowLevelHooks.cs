using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using static BorderlessMouse.Input.NativeMethods;

namespace BorderlessMouse.Input;

/// <summary>
/// Hooki WH_MOUSE_LL / WH_KEYBOARD_LL. Muszą być instalowane z wątku
/// z pętlą komunikatów (wątek UI Avalonii) – tam też wołane są callbacki.
/// Handler zwraca true, żeby zablokować zdarzenie lokalnie.
/// </summary>
[SupportedOSPlatform("windows")]
public sealed class LowLevelHooks : IDisposable
{
    public delegate bool MouseHandler(int message, in MSLLHOOKSTRUCT data);
    public delegate bool KeyboardHandler(int message, in KBDLLHOOKSTRUCT data);

    public MouseHandler? OnMouse;
    public KeyboardHandler? OnKeyboard;

    private readonly HookProc _mouseProc;
    private readonly HookProc _keyboardProc;
    private IntPtr _mouseHook;
    private IntPtr _keyboardHook;

    public bool IsInstalled => _mouseHook != IntPtr.Zero;

    public LowLevelHooks()
    {
        // delegaty trzymane w polach, żeby GC ich nie sprzątnął
        _mouseProc = MouseCallback;
        _keyboardProc = KeyboardCallback;
    }

    public void Install()
    {
        if (IsInstalled) return;
        var module = GetModuleHandle(null);
        _mouseHook = SetWindowsHookEx(WH_MOUSE_LL, _mouseProc, module, 0);
        if (_mouseHook == IntPtr.Zero)
        {
            throw new InvalidOperationException($"SetWindowsHookEx(WH_MOUSE_LL) failed: {Marshal.GetLastWin32Error()}");
        }
        _keyboardHook = SetWindowsHookEx(WH_KEYBOARD_LL, _keyboardProc, module, 0);
        if (_keyboardHook == IntPtr.Zero)
        {
            var err = Marshal.GetLastWin32Error();
            UnhookWindowsHookEx(_mouseHook);
            _mouseHook = IntPtr.Zero;
            throw new InvalidOperationException($"SetWindowsHookEx(WH_KEYBOARD_LL) failed: {err}");
        }
    }

    public void Uninstall()
    {
        if (_mouseHook != IntPtr.Zero) { UnhookWindowsHookEx(_mouseHook); _mouseHook = IntPtr.Zero; }
        if (_keyboardHook != IntPtr.Zero) { UnhookWindowsHookEx(_keyboardHook); _keyboardHook = IntPtr.Zero; }
    }

    private IntPtr MouseCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            var data = Marshal.PtrToStructure<MSLLHOOKSTRUCT>(lParam);
            try
            {
                if (OnMouse?.Invoke((int)wParam, in data) == true) return 1;
            }
            catch
            {
                // wyjątek w hooku = utrata hooka; nigdy nie propagujemy
            }
        }
        return CallNextHookEx(_mouseHook, nCode, wParam, lParam);
    }

    private IntPtr KeyboardCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            var data = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam);
            try
            {
                if (OnKeyboard?.Invoke((int)wParam, in data) == true) return 1;
            }
            catch
            {
                // jw.
            }
        }
        return CallNextHookEx(_keyboardHook, nCode, wParam, lParam);
    }

    public void Dispose() => Uninstall();
}
