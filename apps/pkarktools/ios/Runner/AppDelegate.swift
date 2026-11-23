import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ArcaFolderPlugin") {
      ArcaFolderPlugin.register(with: registrar)
    }
  }
}

/// Carpeta del Arca en iOS: selector de carpetas de Archivos (iCloud Drive,
/// En mi iPhone, proveedores como Google Drive o Dropbox) y bookmarks para
/// conservar el permiso entre arranques.
class ArcaFolderPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private var pending: FlutterResult?
  private var accessed: [URL] = []

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "dev.pkarktools/folder", binaryMessenger: registrar.messenger())
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

  private func topController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
    var vc = window?.rootViewController
    while let presented = vc?.presentedViewController { vc = presented }
    return vc
  }

  private func pick(_ result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "Ya hay un selector abierto", details: nil))
      return
    }
    guard let presenter = topController() else {
      result(FlutterError(code: "ui", message: "No hay ventana para mostrar el selector", details: nil))
      return
    }
    pending = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pending else { return }
    pending = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    let ok = url.startAccessingSecurityScopedResource()
    if ok { accessed.append(url) }
    do {
      let data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
      result(["path": url.path, "bookmark": data.base64EncodedString()])
    } catch {
      result(FlutterError(code: "bookmark", message: error.localizedDescription, details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(nil)
    pending = nil
  }

  private func resolve(_ b64: String, _ result: @escaping FlutterResult) {
    guard let data = Data(base64Encoded: b64) else {
      result(FlutterError(code: "access", message: "Bookmark no válido", details: nil))
      return
    }
    do {
      var stale = false
      let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
      guard url.startAccessingSecurityScopedResource() else {
        result(FlutterError(code: "access", message: "iOS no devolvió el permiso sobre la carpeta", details: nil))
        return
      }
      accessed.append(url)
      var out: [String: Any] = ["path": url.path, "stale": stale]
      if stale, let fresh = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
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
