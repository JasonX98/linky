#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

// Title of the main window. Defined once here so the window-creation code
// (main.cpp) and the window-lookup code (single_instance.cpp) share the same
// value and cannot drift apart.
extern const wchar_t kMainWindowTitle[];

// Returns the registered window message that a second instance uses to ask the
// primary instance to show its main window. It is registered under a stable
// name so both processes observe the same message id.
UINT GetBringToFrontMessage();

// Enforces single-instance behavior using a named mutex. Returns true when this
// process is the first (primary) instance and should continue launching.
// Returns false when another instance is already running; in that case the
// existing main window is brought to the foreground and the caller must exit
// immediately without creating a new process.
bool EnsureSingleInstance();

// Brings |hwnd| to the foreground, restoring it first when it is minimized.
// Called by the primary instance when it receives the bring-to-front message.
void BringToForeground(HWND hwnd);

#endif  // RUNNER_SINGLE_INSTANCE_H_
