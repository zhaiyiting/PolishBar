import Darwin
import Foundation
import PolishBarCore
import PolishBarMac

func printUsage() {
    print("""
    polishbar \(Version.current) — hotkey text polisher

    USAGE:
      polishbar              Start the daemon (default)
      polishbar run          Start the daemon
      polishbar exec TEXT    Send TEXT through the LLM once and print the result
                             (reads stdin when no TEXT is given)
      polishbar doctor       Show permission + config status
      polishbar stop         Stop a running daemon
      polishbar --version    Print version
      polishbar help         Show this help
    """)
}

func runExec(_ text: String) async {
    let config = ConfigStore.load()
    guard let apiKey = KeyStore.resolve(environment: ProcessInfo.processInfo.environment) else {
        FileHandle.standardError.write(Data("no API key found — set POLISHBAR_API_KEY or store one (app Settings / ~/.config/polishbar/api-key)\n".utf8))
        exit(1)
    }

    let service = makePolishBarLLM(config: config, apiKey: apiKey, log: { print("[polishbar] \($0)") })
    do {
        let output = try await service.transform(text)
        print("[polishbar] result:\n\(output)")
    } catch {
        FileHandle.standardError.write(Data("[polishbar] \(error)\n".utf8))
        exit(1)
    }
}

func readStdin() -> String {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func runDoctor() {
    let path = ConfigStore.defaultPath
    let exists = FileManager.default.fileExists(atPath: path)
    let config = ConfigStore.load(path: path)

    print("polishbar \(Version.current)")
    print("config file : \(path)\(exists ? "" : "  (missing; using defaults)")")
    print("hotkey      : \(config.hotkey)")
    print("provider    : \(config.provider)")
    print("model       : \(config.model)")
    print("capture mode: \(config.captureMode)")
    print("accessibility: \(Permissions.isTrusted ? "granted" : "NOT granted")")
    print("  binary    : \(Permissions.executablePath())")

    let key = KeyStore.resolve(environment: ProcessInfo.processInfo.environment)
    print("api key     : \(key == nil ? "missing (set POLISHBAR_API_KEY or use the app / ~/.config/polishbar/api-key)" : "present")")
}

func runStop() {
    let path = Daemon.pidFilePath
    guard let raw = try? String(contentsOfFile: path, encoding: .utf8),
          let pid = pid_t(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        FileHandle.standardError.write(Data("no running daemon (no pid file at \(path))\n".utf8))
        exit(1)
    }
    if kill(pid, SIGTERM) == 0 {
        print("stopped polishbar (pid \(pid))")
    } else {
        FileHandle.standardError.write(Data("could not signal pid \(pid)\n".utf8))
        try? FileManager.default.removeItem(atPath: path)
        exit(1)
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first ?? "run" {
case "run", "start":
    Daemon(config: ConfigStore.load()).run()
case "exec":
    let inline = arguments.dropFirst().joined(separator: " ")
    await runExec(inline.isEmpty ? readStdin() : inline)
case "doctor":
    runDoctor()
case "stop":
    runStop()
case "version", "--version", "-v":
    print("polishbar \(Version.current)")
case "help", "--help", "-h":
    printUsage()
default:
    FileHandle.standardError.write(Data("unknown command: \(arguments.first!)\n".utf8))
    printUsage()
    exit(2)
}
