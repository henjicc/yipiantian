// Native desktop lifecycle and filtered pointer forwarding. The parent Godot process owns all farm data.
// Design references and supported boundaries are documented in README.md.
#include <windows.h>
#include <shellapi.h>
#include <dwmapi.h>
#include <wtsapi32.h>
#include <tlhelp32.h>
#include <oleacc.h>
#include <algorithm>
#include <string>
#include <vector>

namespace {
constexpr UINT TRAY_MESSAGE = WM_APP + 1;
HWND game = nullptr, helper = nullptr, desktop = nullptr, icons = nullptr;
HANDLE parent_process = nullptr;
DWORD game_pid = 0;
LONG_PTR old_style = 0, old_ex_style = 0;
RECT old_rect{}, monitor_rect{};
std::wstring monitor_name;
bool attached = false, running = true, locked = false, was_visible = false;
bool styles_saved = false;
NOTIFYICONDATAW tray{};
UINT taskbar_created = 0;
std::string input;
constexpr UINT POINTER_BUTTON = WM_APP + 2;
HHOOK mouse_hook_handle = nullptr;
bool interacting = false, pointer_available = false;
POINT pointer_point{};
HWND pointer_window = nullptr;
ULONGLONG pointer_sampled = 0;
unsigned captured_buttons = 0;
struct PointerButton { POINT point; int button; bool pressed; double factor; };
LRESULT CALLBACK mouse_hook(int code, WPARAM message, LPARAM data);
void stop_mouse() {
    if (mouse_hook_handle) UnhookWindowsHookEx(mouse_hook_handle);
    mouse_hook_handle = nullptr;
    interacting = false; pointer_available = false; captured_buttons = 0;
}

void emit(const std::string &line) {
    DWORD written = 0;
    std::string bytes = line + "\n";
    WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), bytes.data(), static_cast<DWORD>(bytes.size()), &written, nullptr);
}
void error(const char *stage) { emit("ERROR " + std::string(stage) + " " + std::to_string(GetLastError())); }
bool owns_window() {
    DWORD pid = 0;
    GetWindowThreadProcessId(game, &pid);
    return pid == game_pid && IsWindow(game) && WaitForSingleObject(parent_process, 0) == WAIT_TIMEOUT;
}
std::wstring window_class(HWND hwnd) {
    wchar_t buffer[128]{};
    GetClassNameW(hwnd, buffer, 128);
    return buffer;
}
bool set_parent(HWND parent) {
    SetLastError(0);
    return SetParent(game, parent) != nullptr || GetLastError() == 0;
}
bool set_style(int index, LONG_PTR value) {
    SetLastError(0);
    return SetWindowLongPtrW(game, index, value) != 0 || GetLastError() == 0;
}
BOOL CALLBACK find_layer(HWND hwnd, LPARAM data) {
    HWND defview = FindWindowExW(hwnd, nullptr, L"SHELLDLL_DefView", nullptr);
    if (defview) {
        icons = defview;
        *reinterpret_cast<HWND *>(data) = FindWindowExW(nullptr, hwnd, L"WorkerW", nullptr);
    }
    return TRUE;
}
BOOL CALLBACK locate_monitor(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
    MONITORINFOEXW info{}; info.cbSize = sizeof(info);
    if (GetMonitorInfoW(monitor, &info) && monitor_name == info.szDevice) {
        monitor_rect = info.rcMonitor;
        *reinterpret_cast<bool *>(data) = true;
        return FALSE;
    }
    return TRUE;
}
bool restore(bool announce = true) {
    stop_mouse();
    if (styles_saved) emit("RESTORING");
    if (!owns_window()) return false;
    if (styles_saved) {
        if (!set_parent(nullptr) || !set_style(GWL_STYLE, old_style) || !set_style(GWL_EXSTYLE, old_ex_style)) {
            error("restore_style"); return false;
        }
        if (!SetWindowPos(game, HWND_NOTOPMOST, old_rect.left, old_rect.top,
            old_rect.right-old_rect.left, old_rect.bottom-old_rect.top,
            SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_SHOWWINDOW)) {
            error("restore_position"); return false;
        }
    }
    attached = false;
    styles_saved = false;
    if (announce) emit("RESTORED");
    return true;
}
bool attach() {
    emit("ATTACHING");
    if (!owns_window()) { SetLastError(ERROR_INVALID_WINDOW_HANDLE); error("window_lost"); return false; }
    bool monitor_found = false;
    EnumDisplayMonitors(nullptr, nullptr, locate_monitor, reinterpret_cast<LPARAM>(&monitor_found));
    if (!monitor_found) { SetLastError(ERROR_INVALID_MONITOR_HANDLE); error("monitor_removed"); return false; }
    HWND progman = FindWindowW(L"Progman", nullptr);
    if (!progman) { SetLastError(ERROR_NOT_FOUND); error("desktop_missing"); return false; }
    DWORD_PTR result = 0;
    if (!SendMessageTimeoutW(progman, 0x052C, 0xD, 1, SMTO_ABORTIFHUNG, 1000, &result)) {
        error("desktop_timeout"); return false;
    }
    HWND worker = nullptr;
    icons = nullptr;
    EnumWindows(find_layer, reinterpret_cast<LPARAM>(&worker));
    const bool raised = (GetWindowLongPtrW(progman, GWL_EXSTYLE) & WS_EX_NOREDIRECTIONBITMAP) != 0;
    if (raised) {
        icons = FindWindowExW(progman, nullptr, L"SHELLDLL_DefView", nullptr);
        worker = FindWindowExW(progman, nullptr, L"WorkerW", nullptr);
    }
    if (!worker || !icons) { SetLastError(ERROR_NOT_FOUND); error("desktop_layer_missing"); return false; }
    if (!styles_saved) {
        old_style = GetWindowLongPtrW(game, GWL_STYLE);
        old_ex_style = GetWindowLongPtrW(game, GWL_EXSTYLE);
        GetWindowRect(game, &old_rect);
        styles_saved = true;
    }
    desktop = raised ? progman : worker;
    LONG_PTR style = (old_style & ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX)) | WS_CHILD;
    LONG_PTR ex_style = (old_ex_style & ~(WS_EX_APPWINDOW | WS_EX_TOPMOST)) | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE;
    if (raised) ex_style |= WS_EX_LAYERED;
    // Godot's layered style must be applied before reparenting its render window.
    if (!set_style(GWL_STYLE, style) || !set_style(GWL_EXSTYLE, ex_style)
        || (raised && !SetLayeredWindowAttributes(game, 0, 255, LWA_ALPHA)) || !set_parent(desktop)) {
        error("attach_style"); restore(false); return false;
    }
    POINT position{monitor_rect.left, monitor_rect.top};
    if (!ScreenToClient(desktop, &position) || !SetWindowPos(game, raised ? icons : HWND_BOTTOM,
        position.x, position.y, monitor_rect.right-monitor_rect.left, monitor_rect.bottom-monitor_rect.top,
        SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_SHOWWINDOW)) {
        error("attach_position"); restore(false); return false;
    }
    attached = true;
    if (!mouse_hook_handle) mouse_hook_handle = SetWindowsHookExW(WH_MOUSE_LL, mouse_hook, GetModuleHandleW(nullptr), 0);
    if (!mouse_hook_handle) { error("desktop_input"); restore(false); return false; }
    was_visible = false;
    emit("ATTACHED");
    emit("COVERED");
    return true;
}

struct Coverage { HRGN visible; };
BOOL CALLBACK subtract_window(HWND hwnd, LPARAM data) {
    if (!IsWindowVisible(hwnd) || IsIconic(hwnd) || hwnd == game || hwnd == helper) return TRUE;
    const auto cls = window_class(hwnd);
    if (cls == L"Progman" || cls == L"WorkerW" || cls == L"Shell_TrayWnd" || cls == L"Shell_SecondaryTrayWnd") return TRUE;
    DWORD cloaked = 0;
    DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, &cloaked, sizeof(cloaked));
    if (cloaked) return TRUE;
    LONG_PTR ex = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
    if (ex & WS_EX_TRANSPARENT) return TRUE;
    if (ex & WS_EX_LAYERED) {
        BYTE alpha = 255; DWORD flags = 0; COLORREF color;
        if (!GetLayeredWindowAttributes(hwnd, &color, &alpha, &flags) || ((flags & LWA_ALPHA) && alpha < 255) || (flags & LWA_COLORKEY)) return TRUE;
    }
    RECT bounds{};
    if (FAILED(DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, &bounds, sizeof(bounds)))) GetWindowRect(hwnd, &bounds);
    HRGN region = CreateRectRgnIndirect(&bounds);
    auto coverage = reinterpret_cast<Coverage *>(data);
    CombineRgn(coverage->visible, coverage->visible, region, RGN_DIFF);
    DeleteObject(region);
    return TRUE;
}
void visibility() {
    bool visible = !locked;
    if (visible) {
        Coverage coverage{CreateRectRgnIndirect(&monitor_rect)};
        EnumWindows(subtract_window, reinterpret_cast<LPARAM>(&coverage));
        DWORD bytes = GetRegionData(coverage.visible, 0, nullptr);
        std::vector<BYTE> buffer(bytes);
        long long area = 0;
        if (bytes && GetRegionData(coverage.visible, bytes, reinterpret_cast<RGNDATA *>(buffer.data()))) {
            auto region = reinterpret_cast<RGNDATA *>(buffer.data());
            auto rects = reinterpret_cast<RECT *>(region->Buffer);
            for (DWORD i=0; i<region->rdh.nCount; ++i) area += static_cast<long long>(rects[i].right-rects[i].left)*(rects[i].bottom-rects[i].top);
            const long long total = static_cast<long long>(monitor_rect.right-monitor_rect.left)*(monitor_rect.bottom-monitor_rect.top);
            visible = area > total/20;
        }
        DeleteObject(coverage.visible);
    }
    if (visible != was_visible) { was_visible = visible; emit(visible ? "VISIBLE" : "COVERED"); }
}
void add_tray() {
    tray.cbSize = sizeof(tray); tray.hWnd = helper; tray.uID = 1;
    tray.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    tray.uCallbackMessage = TRAY_MESSAGE;
    wchar_t filename[MAX_PATH]{}; DWORD size = MAX_PATH;
    if (QueryFullProcessImageNameW(parent_process, 0, filename, &size)) ExtractIconExW(filename, 0, nullptr, &tray.hIcon, 1);
    if (!tray.hIcon) tray.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    lstrcpynW(tray.szTip, L"我有一片田 · 双击返回农场", 128);
    if (!Shell_NotifyIconW(NIM_ADD, &tray)) { error("tray_missing"); running = false; }
}
void request_restore(bool quit) {
    if (quit) emit("QUIT");
    if (restore()) {
        AllowSetForegroundWindow(game_pid);
        SetForegroundWindow(game);
    }
}
bool desktop_background(POINT point) {
    if (!attached || locked || !PtInRect(&monitor_rect, point)) return false;
    HWND hit = WindowFromPoint(point);
    const auto cls = window_class(hit);
    if (hit == game || (hit == desktop && cls == L"WorkerW")) return true;
    if (hit != icons && !IsChild(icons, hit) && cls != L"Progman" && cls != L"WorkerW") return false;
    // Inspect only the desktop under this click. A desktop icon (including its
    // label) must retain its normal action and never wake the farm behind it.
    IAccessible *accessible = nullptr;
    VARIANT child{}, role{};
    bool background = false;
    if (SUCCEEDED(AccessibleObjectFromPoint(point, &accessible, &child)) && accessible) {
        if (SUCCEEDED(accessible->get_accRole(child, &role)) && role.vt == VT_I4) {
            background = role.lVal == ROLE_SYSTEM_LIST || role.lVal == ROLE_SYSTEM_CLIENT || role.lVal == ROLE_SYSTEM_WINDOW;
        }
        accessible->Release();
    }
    VariantClear(&child); VariantClear(&role);
    return background;
}
std::string pointer_coordinates(POINT point) {
    RECT client{};
    if (!ScreenToClient(game, &point) || !GetClientRect(game, &client)
        || client.right <= 0 || client.bottom <= 0 || !PtInRect(&client, point)) return "";
    return std::to_string(double(point.x)/client.right) + " " + std::to_string(double(point.y)/client.bottom);
}
void sample_pointer() {
    POINT point{};
    const bool available = GetCursorPos(&point) && desktop_background(point);
    const bool moved = point.x != pointer_point.x || point.y != pointer_point.y;
    const bool changed = available != pointer_available;
    pointer_point = point;
    pointer_available = available;
    pointer_window = available ? WindowFromPoint(point) : nullptr;
    pointer_sampled = GetTickCount64();
    if (available && (moved || changed)) {
        const auto coordinates = pointer_coordinates(point);
        if (!coordinates.empty()) emit("POINTER " + coordinates);
    } else if (changed) emit("LEAVE");
}
LRESULT CALLBACK mouse_hook(int code, WPARAM message, LPARAM data) {
    // Never call Accessibility, write pipes, or send synchronous messages here.
    // The host samples the desktop outside the hook; stale/moved points fail closed.
    if (code != HC_ACTION || !attached || locked) return CallNextHookEx(nullptr, code, message, data);
    auto mouse = reinterpret_cast<MSLLHOOKSTRUCT *>(data);
    int button = 0; bool pressed = false; double factor = 1.0;
    switch (message) {
        case WM_LBUTTONDOWN: button=1; pressed=true; break;
        case WM_LBUTTONUP: button=1; break;
        case WM_RBUTTONDOWN: button=2; pressed=true; break;
        case WM_RBUTTONUP: button=2; break;
        case WM_MBUTTONDOWN: button=3; pressed=true; break;
        case WM_MBUTTONUP: button=3; break;
        case WM_MOUSEWHEEL: {
            const short delta = static_cast<short>(HIWORD(mouse->mouseData));
            button = delta > 0 ? 4 : 5; pressed = true;
            factor = abs(double(delta))/WHEEL_DELTA;
            break;
        }
        default: return CallNextHookEx(nullptr, code, message, data);
    }
    const bool valid = pointer_available && GetTickCount64()-pointer_sampled < 150
        && mouse->pt.x == pointer_point.x && mouse->pt.y == pointer_point.y
        && WindowFromPoint(mouse->pt) == pointer_window;
    const unsigned bit = 1u << button;
    const bool captured = (captured_buttons & bit) != 0;
    const bool suppress = captured || (valid && interacting);
    if (button <= 3) {
        if (pressed && suppress) captured_buttons |= bit;
        if (!pressed) captured_buttons &= ~bit;
    }
    // Passive clicks are only candidates: the game decides whether a tool was hit.
    if (valid || captured || !interacting) {
        auto event = new PointerButton{mouse->pt, button, pressed, factor};
        if (!PostMessageW(helper, POINTER_BUTTON, 0, reinterpret_cast<LPARAM>(event))) delete event;
    }
    if (suppress) return 1;
    return CallNextHookEx(nullptr, code, message, data);
}
void forward_button(const PointerButton &event) {
    if (!attached || locked) return;
    if (!desktop_background(event.point)) { emit("LEAVE"); return; }
    const auto coordinates = pointer_coordinates(event.point);
    if (coordinates.empty()) { emit("LEAVE"); return; }
    emit("BUTTON " + std::to_string(event.button) + " " + (event.pressed ? "1 " : "0 ")
        + coordinates + " " + std::to_string(event.factor));
}
LRESULT CALLBACK window_proc(HWND hwnd, UINT message, WPARAM wp, LPARAM lp) {
    if (message == POINTER_BUTTON) {
        auto event = reinterpret_cast<PointerButton *>(lp);
        forward_button(*event);
        delete event;
    } else if (message == taskbar_created && taskbar_created) {
        Shell_NotifyIconW(NIM_ADD, &tray);
        // The timer also checks ownership and parent liveness after shell rebuilds.
    } else if (message == TRAY_MESSAGE) {
        if (lp == WM_LBUTTONDBLCLK) request_restore(false);
        if (lp == WM_RBUTTONUP || lp == WM_CONTEXTMENU) {
            HMENU menu = CreatePopupMenu();
            AppendMenuW(menu, MF_STRING, 1, L"返回农场");
            AppendMenuW(menu, MF_STRING, 2, L"退出游戏");
            POINT p{}; GetCursorPos(&p); SetForegroundWindow(hwnd);
            int choice = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON, p.x, p.y, 0, hwnd, nullptr);
            DestroyMenu(menu);
            if (choice) request_restore(choice == 2);
            PostMessageW(hwnd, WM_NULL, 0, 0);
        }
    } else if (message == WM_WTSSESSION_CHANGE) {
        if (wp == WTS_SESSION_LOCK) locked = true;
        if (wp == WTS_SESSION_UNLOCK) locked = false;
    } else if (message == WM_DISPLAYCHANGE && attached) {
        if (!attach()) request_restore(false);
    } else if (message == WM_QUERYENDSESSION) { return TRUE;
    } else if (message == WM_CLOSE) { request_restore(true); return 0; }
    return DefWindowProcW(hwnd, message, wp, lp);
}
DWORD actual_parent() {
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    PROCESSENTRY32W entry{}; entry.dwSize = sizeof(entry);
    DWORD result = 0;
    if (Process32FirstW(snapshot, &entry)) do {
        if (entry.th32ProcessID == GetCurrentProcessId()) { result = entry.th32ParentProcessID; break; }
    } while (Process32NextW(snapshot, &entry));
    CloseHandle(snapshot); return result;
}
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    int argc = 0; LPWSTR *argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (!argv || argc != 3) { emit("ERROR arguments 87"); if (argv) LocalFree(argv); return 1; }
    wchar_t *end = nullptr;
    game = reinterpret_cast<HWND>(_wcstoui64(argv[1], &end, 10));
    bool valid = end && !*end;
    game_pid = wcstoul(argv[2], &end, 10); valid = valid && end && !*end && game_pid != 0;
    LocalFree(argv);
    if (!valid || actual_parent() != game_pid) { emit("ERROR owner 5"); return 1; }
    parent_process = OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, game_pid);
    if (!parent_process || !owns_window()) { error("owner"); if (parent_process) CloseHandle(parent_process); return 1; }
    MONITORINFOEXW monitor{}; monitor.cbSize = sizeof(monitor);
    if (!GetMonitorInfoW(MonitorFromWindow(game, MONITOR_DEFAULTTONEAREST), &monitor)) { error("monitor"); CloseHandle(parent_process); return 1; }
    monitor_name = monitor.szDevice;
    const HRESULT com = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(com)) { emit("ERROR accessibility 1"); CloseHandle(parent_process); return 1; }
    WNDCLASSW cls{}; cls.lpfnWndProc = window_proc; cls.hInstance = instance; cls.lpszClassName = L"FarmDesktopHost";
    RegisterClassW(&cls);
    helper = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, cls.lpszClassName, L"我有一片田 · 桌面宿主", WS_POPUP, 0,0,0,0,nullptr,nullptr,instance,nullptr);
    taskbar_created = RegisterWindowMessageW(L"TaskbarCreated");
    WTSRegisterSessionNotification(helper, NOTIFY_FOR_THIS_SESSION);
    add_tray();
    if (!running || !attach()) running = false;
    ULONGLONG next_visibility = 0, next_pointer = 0;
    while (running && WaitForSingleObject(parent_process, 0) == WAIT_TIMEOUT) {
        MSG message;
        while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) { TranslateMessage(&message); DispatchMessageW(&message); }
        DWORD available = 0;
        if (!PeekNamedPipe(GetStdHandle(STD_INPUT_HANDLE), nullptr, 0, nullptr, &available, nullptr)) break;
        if (available) {
            char buffer[256]; DWORD count = 0;
            if (!ReadFile(GetStdHandle(STD_INPUT_HANDLE), buffer, std::min<DWORD>(available, sizeof(buffer)), &count, nullptr)) break;
            input.append(buffer, count);
            if (input.size() > 1024) { emit("ERROR protocol 87"); break; }
            size_t newline;
            while ((newline = input.find('\n')) != std::string::npos) {
                std::string command = input.substr(0, newline); input.erase(0, newline+1);
                if (command == "RESTORE") request_restore(false);
                else if (command == "STOP") running = false;
                else if (command == "INTERACT") interacting = true;
                else if (command == "OBSERVE") interacting = false;
                else { emit("ERROR command 87"); running = false; }
            }
        }
        if (attached && GetTickCount64() >= next_visibility) {
            next_visibility = GetTickCount64()+500;
            if (!owns_window()) { emit("ERROR window_lost 1400"); break; }
            if (!IsWindow(desktop) || GetParent(game) != desktop) {
                // Bounded recovery. A failed recovery reveals the normal game instead.
                if (!attach()) request_restore(false);
            }
            if (attached) visibility();
        }
        if (attached && GetTickCount64() >= next_pointer) {
            next_pointer = GetTickCount64()+33;
            sample_pointer();
        }
        MsgWaitForMultipleObjects(1, &parent_process, FALSE, 16, QS_ALLINPUT);
    }
    if (styles_saved) restore(false);
    stop_mouse();
    Shell_NotifyIconW(NIM_DELETE, &tray);
    WTSUnRegisterSessionNotification(helper);
    DestroyWindow(helper);
    CloseHandle(parent_process);
    CoUninitialize();
    return 0;
}
