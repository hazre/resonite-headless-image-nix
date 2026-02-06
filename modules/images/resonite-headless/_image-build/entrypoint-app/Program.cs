using System.Diagnostics;

return await Program.Main(args);

/// <summary>
/// Resonite Headless Entrypoint - Downloads Resonite at runtime if needed, then launches the server.
/// </summary>
static partial class Program
{
    private static readonly string[] RequiredEnvVars = ["STEAM_USERNAME", "STEAM_PASSWORD"];
    private static readonly string[] NonLinuxPlatformPrefixes = ["win", "osx", "ios", "android", "freebsd", "rhel", "fedora", "opensuse", "debian"];
    private static readonly string[] UnnecessaryFileExtensions = ["*.exe", "*.pdb", "*.a", "*.dll.config"];
    private static readonly string[] RequiredSystemLibraries = ["libpng16.so.16", "libbz2.so.1.0", "libz.so.1"];
    private static readonly string[] NixLibraryPackages = ["libpng", "bzip2", "zlib"];

    public static async Task<int> Main(string[] args)
    {
        var gameDir = Environment.GetEnvironmentVariable("RESONITE_GAME_DIR") ?? "/Game";
        var configPath = Environment.GetEnvironmentVariable("RESONITE_CONFIG") ?? "/Config/Config.json";
        var logsPath = Environment.GetEnvironmentVariable("RESONITE_LOGS") ?? "/Logs";
        var headlessDir = Path.Combine(gameDir, "Headless");

        Console.WriteLine("=== Resonite Headless Container ===");

        if (!ValidateCredentials())
            return 1;

        // ResoniteDownloader handles version resolution automatically if not specified
        var requestedVersion = Environment.GetEnvironmentVariable("RESONITE_VERSION");
        
        if (await DownloadIfNeeded(gameDir, headlessDir, requestedVersion) is false)
            return 1;

        var libraryPath = PrepareNativeLibraries(headlessDir);

        return await LaunchServer(headlessDir, configPath, logsPath, args, libraryPath);
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

    private static async Task<bool> DownloadIfNeeded(string gameDir, string headlessDir, string? requestedVersion)
    {
        var buildVersionFile = Path.Combine(gameDir, "Build.version");
        var resoniteDll = Path.Combine(headlessDir, "Resonite.dll");

        if (File.Exists(resoniteDll))
        {
            var installedVersion = File.Exists(buildVersionFile)
                ? File.ReadAllText(buildVersionFile).Trim()
                : null;

            if (installedVersion != null)
            {
                Console.WriteLine($"Found installed version: {installedVersion}");
                
                if (string.IsNullOrEmpty(requestedVersion))
                {
                    Console.WriteLine("No specific version requested, using existing installation");
                    return true;
                }
                
                if (installedVersion == requestedVersion)
                {
                    Console.WriteLine($"Requested version {requestedVersion} already installed");
                    return true;
                }
                
                Console.WriteLine($"Version mismatch: installed={installedVersion}, requested={requestedVersion}");
            }
        }

        Console.WriteLine("Running ResoniteDownloader...");
        var exitCode = await RunResoniteDownloader(gameDir, requestedVersion);
        
        if (exitCode != 0)
        {
            Console.Error.WriteLine("ERROR: ResoniteDownloader failed");
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
            : "unknown";
        Console.WriteLine($"Resonite {finalVersion} ready");

        return true;
    }

    private static async Task<int> RunResoniteDownloader(string gameDir, string? requestedVersion)
    {
        var steamUser = Environment.GetEnvironmentVariable("STEAM_USERNAME")!;
        var steamPass = Environment.GetEnvironmentVariable("STEAM_PASSWORD")!;
        var betaPass = Environment.GetEnvironmentVariable("STEAM_BETA_PASSWORD") ?? "";

        var args = new List<string>
        {
            "download",
            "--game-dir", gameDir,
            "--steam-user", steamUser,
            "--steam-pass", steamPass,
            "--branch", "headless"
        };

        // Add beta password if provided (required for headless branch)
        if (!string.IsNullOrEmpty(betaPass))
        {
            args.Add("--beta-pass");
            args.Add(betaPass);
        }

        if (!string.IsNullOrEmpty(requestedVersion))
        {
            args.Add("--version");
            args.Add(requestedVersion);
        }

        var startInfo = new ProcessStartInfo("ResoniteDownloader")
        {
            ArgumentList = { },
            UseShellExecute = false
        };

        foreach (var arg in args)
            startInfo.ArgumentList.Add(arg);

        // Log command (with passwords redacted)
        var safeArgs = args
            .Select((arg, i) => 
                (i > 0 && (args[i-1] == "--steam-user" || args[i-1] == "--steam-pass" || args[i-1] == "--beta-pass")) 
                    ? "***" 
                    : arg)
            .ToList();
        Console.WriteLine($"Running: ResoniteDownloader {string.Join(" ", safeArgs)}");

        var process = Process.Start(startInfo);
        if (process is null)
        {
            Console.Error.WriteLine("ERROR: Failed to start ResoniteDownloader");
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

        var preservedEntries = new HashSet<string>(StringComparer.Ordinal)
        {
            Path.GetFullPath(headlessDir),
            Path.GetFullPath(Path.Combine(gameDir, "Build.version"))
        };

        foreach (var path in Directory.GetFileSystemEntries(gameDir))
        {
            var fullPath = Path.GetFullPath(path);
            if (preservedEntries.Contains(fullPath))
                continue;

            if (Directory.Exists(fullPath))
                Directory.Delete(fullPath, recursive: true);
            else if (File.Exists(fullPath))
                File.Delete(fullPath);
        }
    }

    private static string? PrepareNativeLibraries(string headlessDir)
    {
        var runtimeDirs = GetLinuxNativeRuntimeDirs(headlessDir);
        if (runtimeDirs.Count == 0)
            return null;

        Console.WriteLine("Preparing native libraries...");

        foreach (var dir in runtimeDirs)
        {
            EnsureSymlink(
                Path.Combine(dir, "freetype6.so"),
                Path.Combine(dir, "libfreetype6.so"),
                Path.GetFileName(Path.Combine(dir, "libfreetype6.so"))
            );
        }

        var libraryDirs = BuildLibrarySearchDirs(runtimeDirs);
        foreach (var runtimeDir in runtimeDirs)
        {
            foreach (var libraryName in RequiredSystemLibraries)
                EnsureLibrarySymlink(runtimeDir, libraryName, libraryDirs);
        }

        if (libraryDirs.Count == 0)
            return null;

        return string.Join(':', libraryDirs);
    }

    private static List<string> GetLinuxNativeRuntimeDirs(string headlessDir)
    {
        var runtimesRoot = Path.Combine(headlessDir, "runtimes");
        if (!Directory.Exists(runtimesRoot))
            return [];

        return Directory
            .EnumerateDirectories(runtimesRoot)
            .Where(dir => Path.GetFileName(dir).StartsWith("linux", StringComparison.Ordinal))
            .Select(dir => Path.Combine(dir, "native"))
            .Where(Directory.Exists)
            .Distinct(StringComparer.Ordinal)
            .ToList();
    }

    private static List<string> BuildLibrarySearchDirs(IEnumerable<string> runtimeDirs)
    {
        var result = new List<string>();

        void AddDirectory(string? dir)
        {
            if (string.IsNullOrWhiteSpace(dir) || !Directory.Exists(dir))
                return;

            if (result.Contains(dir, StringComparer.Ordinal))
                return;

            result.Add(dir);
        }

        var existingLibraryPath = Environment.GetEnvironmentVariable("LD_LIBRARY_PATH") ?? "";
        foreach (var dir in existingLibraryPath.Split(':', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            AddDirectory(dir);

        foreach (var dir in runtimeDirs)
            AddDirectory(dir);

        foreach (var packageName in NixLibraryPackages)
        {
            foreach (var dir in FindNixStoreLibDirs(packageName))
                AddDirectory(dir);
        }

        return result;
    }

    private static IEnumerable<string> FindNixStoreLibDirs(string packageName)
    {
        const string nixStore = "/nix/store";
        if (!Directory.Exists(nixStore))
            yield break;

        IEnumerable<string> candidates;
        try
        {
            candidates = Directory.EnumerateDirectories(nixStore, $"*-{packageName}-*");
        }
        catch
        {
            yield break;
        }

        foreach (var candidate in candidates)
        {
            var libDir = Path.Combine(candidate, "lib");
            if (Directory.Exists(libDir))
                yield return libDir;
        }
    }

    private static void EnsureLibrarySymlink(string runtimeDir, string libraryName, IEnumerable<string> libraryDirs)
    {
        var targetPath = Path.Combine(runtimeDir, libraryName);
        if (File.Exists(targetPath))
            return;

        foreach (var libraryDir in libraryDirs)
        {
            var sourcePath = Path.Combine(libraryDir, libraryName);
            if (!File.Exists(sourcePath))
                continue;

            EnsureSymlink(targetPath, sourcePath, sourcePath);
            return;
        }
    }

    private static void EnsureSymlink(string linkPath, string targetPath, string displayTarget)
    {
        if (!File.Exists(targetPath) || File.Exists(linkPath))
            return;

        File.CreateSymbolicLink(linkPath, targetPath);
        Console.WriteLine($"  Created {linkPath} -> {displayTarget}");
    }

    private static async Task<int> LaunchServer(string headlessDir, string configPath, string logsPath, string[] args, string? libraryPath)
    {
        Console.WriteLine("Starting Resonite Headless Server...");
        Directory.SetCurrentDirectory(headlessDir);

        Environment.SetEnvironmentVariable("DOTNET_EnableDiagnostics", "0");

        var startInfo = new ProcessStartInfo("dotnet")
        {
            Arguments = $"Resonite.dll -HeadlessConfig {configPath} -Logs {logsPath} {string.Join(" ", args)}",
            UseShellExecute = false
        };

        if (!string.IsNullOrWhiteSpace(libraryPath))
            startInfo.Environment["LD_LIBRARY_PATH"] = libraryPath;

        var process = Process.Start(startInfo);
        if (process is null)
        {
            Console.Error.WriteLine("ERROR: Failed to start Resonite server");
            return 1;
        }
        
        await process.WaitForExitAsync();
        return process.ExitCode;
    }
}
