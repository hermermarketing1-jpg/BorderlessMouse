using Avalonia.Controls;
using Avalonia.Media;
using FluentAvalonia.UI.Windowing;

namespace BorderlessMouse.Views;

public partial class MainWindow : AppWindow
{
    public MainWindow()
    {
        InitializeComponent();
        TitleBar.ExtendsContentIntoTitleBar = true;
        TitleBar.TitleBarHitTestType = TitleBarHitTestType.Complex;

        // Mica na Windows 11; gdzie niedostępna – jednolite tło jak w Ustawieniach
        TransparencyLevelHint = new[] { WindowTransparencyLevel.Mica, WindowTransparencyLevel.None };
        Opened += (_, _) => ApplyBackdrop();
        PropertyChanged += (_, e) =>
        {
            if (e.Property == ActualTransparencyLevelProperty) ApplyBackdrop();
        };

        Closing += (_, e) =>
        {
            // zamknięcie okna = schowanie do zasobnika; wyjście przez menu ikony
            if (App.Current is App app && !app.IsExiting)
            {
                e.Cancel = true;
                Hide();
            }
        };
    }

    private void ApplyBackdrop()
    {
        if (ActualTransparencyLevel == WindowTransparencyLevel.Mica)
        {
            Background = Brushes.Transparent;
        }
        else if (this.TryFindResource("SolidBackgroundFillColorBaseBrush", ActualThemeVariant, out var brush) && brush is IBrush b)
        {
            Background = b;
        }
    }
}
