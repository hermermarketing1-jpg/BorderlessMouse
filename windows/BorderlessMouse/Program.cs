using Avalonia;

namespace BorderlessMouse;

internal static class Program
{
    // Hooki niskiego poziomu i WASAPI wymagają wątku STA z pętlą komunikatów – Avalonia go zapewnia.
    [STAThread]
    public static void Main(string[] args) => BuildAvaloniaApp()
        .StartWithClassicDesktopLifetime(args);

    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont()
            .LogToTrace();
}
