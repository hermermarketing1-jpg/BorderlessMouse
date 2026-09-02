using System.Text;
using Avalonia.Input.Platform;
using Avalonia.Threading;
using BorderlessMouse.Input;
using BorderlessMouse.Protocol;

namespace BorderlessMouse.Net;

/// <summary>
/// Obserwuje schowek Windows (GetClipboardSequenceNumber co 0,5 s; na innych
/// systemach porównuje tekst) i ustawia go z zewnątrz bez odsyłania własnej zmiany.
/// Działa na wątku UI.
/// </summary>
public sealed class ClipboardSync
{
    private readonly IClipboard _clipboard;
    private readonly DispatcherTimer _timer;
    private uint _lastSequence;
    private string? _lastText;
    private bool _busy;

    public event Action<string>? LocalChanged;
    public bool Enabled { get; set; } = true;

    public ClipboardSync(IClipboard clipboard)
    {
        _clipboard = clipboard;
        if (OperatingSystem.IsWindows()) _lastSequence = NativeMethods.GetClipboardSequenceNumber();
        _timer = new DispatcherTimer(TimeSpan.FromMilliseconds(500), DispatcherPriority.Background, (_, _) => _ = PollAsync());
    }

    public void Start() => _timer.Start();
    public void Stop() => _timer.Stop();

    private async Task PollAsync()
    {
        if (!Enabled || _busy) return;
        if (OperatingSystem.IsWindows())
        {
            var seq = NativeMethods.GetClipboardSequenceNumber();
            if (seq == _lastSequence) return;
            _lastSequence = seq;
        }
        _busy = true;
        try
        {
            var text = await _clipboard.TryGetTextAsync();
            if (!string.IsNullOrEmpty(text) && text != _lastText && Encoding.UTF8.GetByteCount(text) <= ProtocolConstants.MaxClipboardBytes)
            {
                _lastText = text;
                LocalChanged?.Invoke(text);
            }
        }
        catch
        {
            // inna aplikacja trzyma schowek – spróbujemy przy następnym ticku
        }
        finally
        {
            _busy = false;
        }
    }

    /// <summary>Ustawia schowek tekstem z Maca.</summary>
    public async Task ApplyAsync(string text)
    {
        _busy = true;
        try
        {
            await _clipboard.SetTextAsync(text);
            _lastText = text;
            if (OperatingSystem.IsWindows()) _lastSequence = NativeMethods.GetClipboardSequenceNumber();
        }
        catch
        {
            // jw.
        }
        finally
        {
            _busy = false;
        }
    }
}
