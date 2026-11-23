import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    ArcaFolderPlugin.register(
      with: flutterViewController.registrar(forPlugin: "ArcaFolderPlugin"))

    super.awakeFromNib()
  }
}

/// Carpeta del Arca en macOS: selector (NSOpenPanel) y security-scoped
/// bookmarks para conservar el permiso del sandbox entre arranques.
class ArcaFolderPlugin: NSObject, FlutterPlugin {
  /// Carpetas cuyo acceso está abierto durante la vida de la app.
  private var accessed: [URL] = []

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "dev.pkarktools/folder", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(ArcaFolderPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "pick": pick(result)
    case "resolve": resolve(args["bookmark"] as? String ?? "", result)
    case "download": download(args, result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  /// iCloud Drive del usuario real (fuera del contenedor del sandbox).
  private func iCloudDrive() -> URL? {
    guard let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir else { return nil }
    let url = URL(fileURLWithPath: String(cString: home))
      .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  private func pick(_ result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Usar esta carpeta"
    panel.message = "Elige la carpeta del Arca. En iCloud Drive se compartirá con tus otros dispositivos."
    if let icloud = iCloudDrive() { panel.directoryURL = icloud }
    panel.begin { response in
      guard response == .OK, let url = panel.url else {
        result(nil)
        return
      }
      do {
        let data = try url.bookmarkData(
          options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        if url.startAccessingSecurityScopedResource() { self.accessed.append(url) }
        result(["path": url.path, "bookmark": data.base64EncodedString()])
      } catch {
        result(FlutterError(code: "bookmark", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func resolve(_ b64: String, _ result: @escaping FlutterResult) {
    guard let data = Data(base64Encoded: b64) else {
      result(FlutterError(code: "access", message: "Bookmark no válido", details: nil))
      return
    }
    do {
      var stale = false
      let url = try URL(
        resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil,
        bookmarkDataIsStale: &stale)
      if url.startAccessingSecurityScopedResource() { accessed.append(url) }
      var out: [String: Any] = ["path": url.path, "stale": stale]
      if stale,
        let fresh = try? url.bookmarkData(
          options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
      {
        out["bookmark"] = fresh.base64EncodedString()
      }
      result(out)
    } catch {
      result(FlutterError(code: "access", message: error.localizedDescription, details: nil))
    }
  }

  /// Pide a iCloud que descargue los archivos aún no presentes (`.nombre.icloud`).
  private func download(_ args: [String: Any], _ result: @escaping FlutterResult) {
    let root = URL(fileURLWithPath: args["root"] as? String ?? "", isDirectory: true)
    for rel in args["paths"] as? [String] ?? [] {
      let placeholder = root.appendingPathComponent(rel)
      var name = placeholder.lastPathComponent
      if name.hasPrefix(".") { name.removeFirst() }
      if name.hasSuffix(".icloud") { name.removeLast(7) }
      let target = placeholder.deletingLastPathComponent().appendingPathComponent(name)
      try? FileManager.default.startDownloadingUbiquitousItem(at: target)
    }
    result(nil)
  }
}
