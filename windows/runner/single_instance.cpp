#include "single_instance.h"

namespace {

// Name of the single-instance mutex. It is deliberately session-local (no
// "Global\\" prefix): a per-user desktop app must not block other user's
// sessions from running their own instance.
constexpr wchar_t kSingleInstanceMutexName[] = L"Linky_SingleInstance_Mutex";

// Name of the window message used to ask the primary instance to show its main
// window. Registering under the same name yields the same message id in both
// instances, so a second instance can reach the primary one.
constexpr wchar_t kBringToFrontMessageName[] = L"Linky_BringToFront_Message";

// Handle to the mutex. It is intentionally never released while the process is
// alive: keeping the named mutex open is exactly what prevents a second
// instance from launching. The OS releases it automatically when the process
// exits.
HANDLE g_single_instance_mutex = nullptr;

UINT g_bring_to_front_message = 0;

}  // namespace

// Definition of the shared window title (declared extern in single_instance.h).
const wchar_t kMainWindowTitle[] = L"Linky 链可";

UINT GetBringToFrontMessage() {
  if (g_bring_to_front_message == 0) {
    g_bring_to_front_message = ::RegisterWindowMessageW(kBringToFrontMessageName);
  }
  return g_bring_to_front_message;
}

bool EnsureSingleInstance() {
  // Create (or open) the named mutex. If it already exists, another instance is
  // still running.
  g_single_instance_mutex = ::CreateMutexW(nullptr, FALSE, kSingleInstanceMutexName);
  if (g_single_instance_mutex == nullptr) {
    // Could not create the mutex for an unexpected reason; fall back to
    // launching so a resource error does not block the user.
    return true;
  }

  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    // Another instance is already running. Ask it to show its main window, then
    // exit without creating a new process.
    ::CloseHandle(g_single_instance_mutex);
    g_single_instance_mutex = nullptr;

    HWND hwnd = ::FindWindowW(nullptr, kMainWindowTitle);
    if (hwnd != nullptr) {
      ::SendMessageTimeoutW(hwnd, GetBringToFrontMessage(), 0, 0,
                            SMTO_ABORTIFHUNG, 1000, nullptr);
    }
    return false;
  }

  // We are the primary instance. Register the bring-to-front message ahead of
  // time so the window is ready to respond to a second instance right away.
  (void)GetBringToFrontMessage();

  return true;
}

void BringToForeground(HWND hwnd) {
  if (hwnd == nullptr) {
    return;
  }

  // Restore the window if it is currently minimized.
  if (::IsIconic(hwnd)) {
    ::ShowWindow(hwnd, SW_RESTORE);
  }

  // Attempt a straightforward foreground switch first.
  ::BringWindowToTop(hwnd);
  ::SetForegroundWindow(hwnd);

  // SetForegroundWindow can be refused when this process does not currently own
  // input. Temporarily attach to the foreground thread's input queue to lift
  // that restriction, then restore the original state.
  HWND foreground = ::GetForegroundWindow();
  DWORD foreground_thread =
      (foreground != nullptr) ? ::GetWindowThreadProcessId(foreground, nullptr)
                              : 0;
  DWORD target_thread = ::GetWindowThreadProcessId(hwnd, nullptr);
  if (foreground_thread != 0 && foreground_thread != target_thread) {
    if (::AttachThreadInput(foreground_thread, target_thread, TRUE)) {
      ::BringWindowToTop(hwnd);
      ::SetForegroundWindow(hwnd);
      ::AttachThreadInput(foreground_thread, target_thread, FALSE);
    }
  }
}
