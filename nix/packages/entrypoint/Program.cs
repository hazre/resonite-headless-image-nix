using System.Diagnostics;
using System.Text.Json;

return await Program.Main(args);

/// <summary>
/// Resonite Headless Entrypoint - Downloads Resonite at runtime if needed, then launches the server.
/// </summary>
static partial class Program
{
    private const int AppId = 2519830;
    private const int DepotId = 2519832;
    private const string VersionMonitorUrl = "https://raw.githubusercontent.com/resonite-love/resonite-version-monitor/refs/heads/master/data/versions.json";

    private static readonly string[] RequiredEnvVars = ["STEAM_USERNAME", "STEAM_PASSWORD", "STEAM_BETA_PASSWORD"];
    private static readonly string[] NonLinuxPlatformPrefixes = ["win", "osx", "ios", "android", "freebsd", "rhel", "fedora", "opensuse", "debian"];
    private static readonly string[] UnnecessaryFileExtensions = ["*.exe", "*.pdb", "*.a", "*.dll.config"];

    public static async Task<int> Main(string[] args)
    {
        var gameDir = Environment.GetEnvironmentVariable("RESONITE_GAME_DIR") ?? "/Game";
        var configPath = Environment.GetEnvironmentVariable("RESONITE_CONFIG") ?? "/Config/Config.json";
        var logsPath = Environment.GetEnvironmentVariable("RESONITE_LOGS") ?? "/Logs";
        var headlessDir = Path.Combine(gameDir, "Headless");

        Console.WriteLine("=== Resonite Headless Container ===");

        if (!ValidateCredentials())
            return 1;

        var version = await ResolveVersion();
        if (version is null)
            return 1;

        Console.WriteLine($"Target version: {version}");

        if (await DownloadIfNeeded(gameDir, headlessDir, version) is false)
            return 1;

        return await LaunchServer(headlessDir, configPath, logsPath, args);
    }

    private static bool ValidateCredentials()
    {
        var missing = RequiredEnvVars
            .Where(v => string.IsNullOrEmpty(Environment.GetEnvironmentVariable(v)))
            .ToList();

        if (missing.Count == 0)
            return true;

        Console.Error.WriteLine("ERROR: Missing required environment variables:");
        foreach (var v in missing)
            Console.Error.WriteLine($"  - {v}");
        Console.Error.WriteLine();
        Console.Error.WriteLine("Set these variables when running the container:");
        Console.Error.WriteLine("  podman run -e STEAM_USERNAME=xxx -e STEAM_PASSWORD=xxx -e STEAM_BETA_PASSWORD=xxx ...");
        return false;
    }

    private static async Task<string?> ResolveVersion()
    {
        var envVersion = Environment.GetEnvironmentVariable("RESONITE_VERSION");
        if (!string.IsNullOrEmpty(envVersion))
            return envVersion;

        Console.WriteLine("Fetching latest Resonite version...");

        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
            var json = await http.GetStringAsync(VersionMonitorUrl);
            var data = JsonDocument.Parse(json);

            if (!data.RootElement.TryGetProperty("headless", out var headlessArray))
            {
                Console.Error.WriteLine("ERROR: Version monitor response missing 'headless' field");
                return null;
            }

            var version = headlessArray
                .EnumerateArray()
                .Select(v => v.TryGetProperty("gameVersion", out var gv) ? gv.GetString() : null)
                .Where(v => !string.IsNullOrEmpty(v) && Version.TryParse(v, out _))
                .OrderByDescending(v => Version.Parse(v!))
                .FirstOrDefault();

            if (string.IsNullOrEmpty(version))
            {
                Console.Error.WriteLine("ERROR: Failed to fetch latest version from resonite-version-monitor");
                return null;
            }

            return version;
        }
        catch (HttpRequestException ex)
        {
            Console.Error.WriteLine($"ERROR: Failed to fetch version info: {ex.Message}");
            return null;
        }
        catch (TaskCanceledException)
        {
            Console.Error.WriteLine("ERROR: Timed out fetching version info");
            return null;
        }
        catch (JsonException ex)
        {
            Console.Error.WriteLine($"ERROR: Invalid JSON from version monitor: {ex.Message}");
            return null;
        }
    }

    private static async Task<bool> DownloadIfNeeded(string gameDir, string headlessDir, string targetVersion)
    {
        var buildVersionFile = Path.Combine(gameDir, "Build.version");
        var resoniteDll = Path.Combine(headlessDir, "Resonite.dll");

        var installedVersion = File.Exists(buildVersionFile)
            ? File.ReadAllText(buildVersionFile).Trim()
            : null;

        var needsDownload = DetermineIfDownloadNeeded(resoniteDll, installedVersion, targetVersion);

        if (!needsDownload)
            return true;

        Console.WriteLine($"Downloading Resonite {targetVersion}...");
        CleanDirectory(gameDir);

        var exitCode = await RunDepotDownloader(gameDir);
        if (exitCode != 0)
        {
            Console.Error.WriteLine("ERROR: DepotDownloader failed");
            return false;
        }

        if (!File.Exists(resoniteDll))
        {
            Console.Error.WriteLine("ERROR: Download failed - Resonite.dll not found");
            return false;
        }

        CleanupUnnecessaryFiles(gameDir, headlessDir);

        var finalVersion = File.Exists(buildVersionFile)
            ? File.ReadAllText(buildVersionFile).Trim()
            : targetVersion;
        Console.WriteLine($"Resonite {finalVersion} installed successfully");

        return true;
    }

    private static bool DetermineIfDownloadNeeded(string resoniteDll, string? installedVersion, string targetVersion)
    {
        if (!File.Exists(resoniteDll))
        {
            Console.WriteLine("Resonite not found, download required");
            return true;
        }

        if (installedVersion is null)
        {
            Console.WriteLine("No version info found, download required");
            return true;
        }

        if (!Version.TryParse(installedVersion, out var installed) ||
            !Version.TryParse(targetVersion, out var target))
        {
            Console.WriteLine("Unable to parse version, download required");
            return true;
        }

        if (installed >= target)
        {
            Console.WriteLine($"Resonite {installedVersion} already installed [target: {targetVersion}]");
            return false;
        }

        Console.WriteLine($"Upgrade needed: {installedVersion} -> {targetVersion}");
        return true;
    }

    private static void CleanDirectory(string directory)
    {
        if (!Directory.Exists(directory))
            return;

        foreach (var entry in Directory.GetFileSystemEntries(directory))
        {
            if (Directory.Exists(entry))
                Directory.Delete(entry, recursive: true);
            else
                File.Delete(entry);
        }
    }

    private static async Task<int> RunDepotDownloader(string gameDir)
    {
        var steamUser = Environment.GetEnvironmentVariable("STEAM_USERNAME")!;
        var steamPass = Environment.GetEnvironmentVariable("STEAM_PASSWORD")!;
        var betaPass = Environment.GetEnvironmentVariable("STEAM_BETA_PASSWORD")!;

        var startInfo = new ProcessStartInfo("DepotDownloader")
        {
            Arguments = $"-app {AppId} -depot {DepotId} -username {steamUser} -password {steamPass} -beta headless -betapassword {betaPass} -dir {gameDir}",
            UseShellExecute = false
        };

        var process = Process.Start(startInfo);
        if (process is null)
        {
            Console.Error.WriteLine("ERROR: Failed to start DepotDownloader");
            return -1;
        }
        await process.WaitForExitAsync();
        return process.ExitCode;
    }

    private static void CleanupUnnecessaryFiles(string gameDir, string headlessDir)
    {
        Console.WriteLine("Cleaning up unnecessary files...");

        var runtimesDir = Path.Combine(headlessDir, "runtimes");
        if (Directory.Exists(runtimesDir))
        {
            foreach (var dir in Directory.GetDirectories(runtimesDir))
            {
                var name = Path.GetFileName(dir);
                if (NonLinuxPlatformPrefixes.Any(prefix => name.StartsWith(prefix)))
                    Directory.Delete(dir, recursive: true);
            }
        }

        foreach (var extension in UnnecessaryFileExtensions)
        {
            foreach (var file in Directory.GetFiles(gameDir, extension, SearchOption.AllDirectories))
                File.Delete(file);
        }
    }

    private static async Task<int> LaunchServer(string headlessDir, string configPath, string logsPath, string[] args)
    {
        Console.WriteLine("Starting Resonite Headless Server...");
        Directory.SetCurrentDirectory(headlessDir);

        Environment.SetEnvironmentVariable("DOTNET_EnableDiagnostics", "0");
        ConfigureNativeLibraryPaths(headlessDir);

        var startInfo = new ProcessStartInfo("dotnet")
        {
            Arguments = $"Resonite.dll -HeadlessConfig {configPath} -Logs {logsPath} {string.Join(" ", args)}",
            UseShellExecute = false
        };

        var process = Process.Start(startInfo);
        if (process is null)
        {
            Console.Error.WriteLine("ERROR: Failed to start Resonite server");
            return 1;
        }
        await process.WaitForExitAsync();
        return process.ExitCode;
    }

    private static void ConfigureNativeLibraryPaths(string headlessDir)
    {
        var nativePaths = new[]
        {
            Path.Combine(headlessDir, "runtimes/linux/native"),
            Path.Combine(headlessDir, "runtimes/linux-x64/native"),
            Path.Combine(headlessDir, "runtimes/linux-arm64/native")
        }.Where(Directory.Exists);

        var existingPath = Environment.GetEnvironmentVariable("LD_LIBRARY_PATH") ?? "";

        var allPaths = nativePaths
            .Concat([existingPath])
            .Where(s => !string.IsNullOrEmpty(s));

        Environment.SetEnvironmentVariable("LD_LIBRARY_PATH", string.Join(":", allPaths));
    }
}
