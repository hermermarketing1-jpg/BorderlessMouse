using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;

namespace BorderlessMouse.Views;

/// <summary>
/// Niewidoczne (alfa 1/255), zawsze-na-wierzchu okno bez kursora. Gdy
/// sterujemy Makiem, kursor jest "zaparkowany" pod tym oknem, dzięki czemu
/// nie widać go na ekranie Windows. Hooki i tak blokują wszystkie zdarzenia.
/// </summary>
public sealed class CoverWindow : Window
{
    private const int Size = 400;

    public CoverWindow()
    {
        Title = "BorderlessMouse";
        SystemDecorations = SystemDecorations.None;
        ShowInTaskbar = false;
        Topmost = true;
        CanResize = false;
        ShowActivated = false;
        Focusable = false;
        TransparencyLevelHint = new[] { WindowTransparencyLevel.Transparent };
        Background = new SolidColorBrush(Color.FromArgb(1, 0, 0, 0));
        Cursor = new Cursor(StandardCursorType.None);
        Width = Size;
        Height = Size;
        WindowStartupLocation = WindowStartupLocation.Manual;
    }

    /// <summary>Pokazuje okno wyśrodkowane na pozycji (piksele fizyczne).</summary>
    public void ShowAt(int pixelX, int pixelY)
    {
        Position = new PixelPoint(pixelX - Size / 2, pixelY - Size / 2);
        if (!IsVisible) Show();
    }
}
