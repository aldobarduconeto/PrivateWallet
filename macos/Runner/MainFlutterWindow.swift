import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Instala o controlador Flutter na janela e registra os plugins e controles sem moldura nativa.
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Remove a moldura e a barra de título padrão nativa do macOS (frameless clean)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.isOpaque = false

    // Oculta os botões de controle padrão (traffic lights) para usar os controles limpos do app
    self.standardWindowButton(.closeButton)?.isHidden = true
    self.standardWindowButton(.miniaturizeButton)?.isHidden = true
    self.standardWindowButton(.zoomButton)?.isHidden = true

    // Registra o canal de métodos da janela para sincronizar minimize, maximize, drag e close
    let windowChannel = FlutterMethodChannel(
      name: "private_wallet/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    windowChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: "Window not available", details: nil))
        return
      }
      switch call.method {
      case "minimize":
        self.miniaturize(nil)
        result(nil)
      case "maximize":
        if !self.isZoomed {
          self.zoom(nil)
        }
        result(nil)
      case "restore":
        if self.isZoomed {
          self.zoom(nil)
        }
        result(nil)
      case "isMaximized":
        result(self.isZoomed)
      case "close":
        self.performClose(nil)
        result(nil)
      case "drag":
        if let currentEvent = NSApp.currentEvent {
          self.performDrag(with: currentEvent)
        }
        result(nil)
      case "setTitleBarColor":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
