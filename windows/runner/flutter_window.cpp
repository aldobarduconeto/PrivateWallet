#include "flutter_window.h"

#include <dwmapi.h>
#include <windowsx.h>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif
#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif
#ifndef DWMWA_TEXT_COLOR
#define DWMWA_TEXT_COLOR 36
#endif

// Guarda o projeto Dart que a janela deverá hospedar.
FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

// Destrói os recursos nativos associados à janela Flutter.
FlutterWindow::~FlutterWindow() {}

// Cria a view Flutter, registra plugins e conecta o canal de aparência.
bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Registra canal de sincronização do layout da janela do Windows com o Flutter
  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "private_wallet/window",
      &flutter::StandardMethodCodec::GetInstance());

  HWND hwnd = GetHandle();

  // Remove moldura nativa estendendo o cliente para cobrir toda a janela
  // mantendo sombras e cantos arredondados nativos do DWM
  MARGINS margins = { 0, 0, 1, 0 };
  DwmExtendFrameIntoClientArea(hwnd, &margins);
  SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);

  window_channel_->SetMethodCallHandler([hwnd](const flutter::MethodCall<flutter::EncodableValue>& call,
                                               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const std::string& method = call.method_name();
    if (method == "minimize") {
      ShowWindow(hwnd, SW_MINIMIZE);
      result->Success();
      return;
    }
    if (method == "maximize") {
      ShowWindow(hwnd, SW_MAXIMIZE);
      result->Success();
      return;
    }
    if (method == "restore") {
      ShowWindow(hwnd, SW_RESTORE);
      result->Success();
      return;
    }
    if (method == "isMaximized") {
      bool is_max = (IsZoomed(hwnd) != FALSE);
      result->Success(flutter::EncodableValue(is_max));
      return;
    }
    if (method == "close") {
      DestroyWindow(hwnd);
      result->Success();
      return;
    }
    if (method == "drag") {
      ReleaseCapture();
      SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
      result->Success();
      return;
    }
    if (method == "setTitleBarColor") {
      const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
      if (arguments) {
        auto r_it = arguments->find(flutter::EncodableValue("r"));
        auto g_it = arguments->find(flutter::EncodableValue("g"));
        auto b_it = arguments->find(flutter::EncodableValue("b"));
        auto dark_it = arguments->find(flutter::EncodableValue("isDark"));
        if (r_it != arguments->end() && g_it != arguments->end() && b_it != arguments->end()) {
          int r = std::get<int>(r_it->second);
          int g = std::get<int>(g_it->second);
          int b = std::get<int>(b_it->second);
          bool is_dark = dark_it != arguments->end() ? std::get<bool>(dark_it->second) : true;

          COLORREF caption_color = RGB(r, g, b);
          DwmSetWindowAttribute(hwnd, DWMWA_CAPTION_COLOR, &caption_color, sizeof(caption_color));

          COLORREF text_color = is_dark ? RGB(236, 240, 250) : RGB(23, 33, 58);
          DwmSetWindowAttribute(hwnd, DWMWA_TEXT_COLOR, &text_color, sizeof(text_color));

          COLORREF border_color = caption_color;
          DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, &border_color, sizeof(border_color));

          BOOL dark_mode = is_dark ? TRUE : FALSE;
          DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark_mode, sizeof(dark_mode));
        }
      }
      result->Success();
      return;
    }
    result->NotImplemented();
  });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

// Libera o canal e o controlador antes de destruir a janela base.
void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

// Delega mensagens ao Flutter, remove a moldura nativa e permite redimensionamento.
LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_CLOSE) {
    DestroyWindow(hwnd);
    return 0;
  }

  switch (message) {
    case WM_NCCALCSIZE: {
      if (wparam == TRUE) {
        if (IsZoomed(hwnd)) {
          auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
          HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
          if (monitor) {
            MONITORINFO monitor_info = {};
            monitor_info.cbSize = sizeof(MONITORINFO);
            if (GetMonitorInfo(monitor, &monitor_info)) {
              params->rgrc[0] = monitor_info.rcWork;
            }
          }
        }
        return 0;
      }
      break;
    }

    case WM_NCHITTEST: {
      if (!IsZoomed(hwnd)) {
        POINT pt = { GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam) };
        RECT rc;
        GetWindowRect(hwnd, &rc);
        const int border_thickness = 8;

        bool left = pt.x >= rc.left && pt.x < rc.left + border_thickness;
        bool right = pt.x < rc.right && pt.x >= rc.right - border_thickness;
        bool top = pt.y >= rc.top && pt.y < rc.top + border_thickness;
        bool bottom = pt.y < rc.bottom && pt.y >= rc.bottom - border_thickness;

        if (top && left) return HTTOPLEFT;
        if (top && right) return HTTOPRIGHT;
        if (bottom && left) return HTBOTTOMLEFT;
        if (bottom && right) return HTBOTTOMRIGHT;
        if (left) return HTLEFT;
        if (right) return HTRIGHT;
        if (top) return HTTOP;
        if (bottom) return HTBOTTOM;
      }
      break;
    }
  }

  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
