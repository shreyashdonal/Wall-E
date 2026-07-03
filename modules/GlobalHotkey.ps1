<#
.SYNOPSIS
    GlobalHotkey.ps1 - Registers system-wide hotkeys (RegisterHotKey) so the
    arrow keys work while this app runs in the background, even without
    focus, and routes WM_HOTKEY messages back into WPF callbacks.

.DESCRIPTION
    IMPORTANT TRADE-OFF: because these are bare arrow keys (no Ctrl/Alt
    modifier), registering them makes Left/Right/Up/Down stop reaching
    every OTHER application system-wide while hotkeys are enabled - typing
    in a text box, browsing, gaming, etc. will not receive arrow key input.
    Use the "Hotkeys Enabled" checkbox in the app to toggle this off when
    you need normal arrow key behavior elsewhere.
#>

if (-not ([System.Management.Automation.PSTypeName]'Win32.HotkeyNative').Type) {
    Add-Type -Namespace Win32 -Name HotkeyNative -MemberDefinition @"
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool RegisterHotKey(System.IntPtr hWnd, int id, uint fsModifiers, uint vk);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool UnregisterHotKey(System.IntPtr hWnd, int id);
"@
}

# Virtual-key codes
$script:VK_LEFT  = 0x25
$script:VK_UP    = 0x26
$script:VK_RIGHT = 0x27
$script:VK_DOWN  = 0x28

# MOD_NOREPEAT: suppress OS auto-repeat while a key is held, so holding an
# arrow down fires once instead of flooding Next/Previous calls.
$script:MOD_NOREPEAT = 0x4000

# Hotkey IDs (arbitrary, must be unique per registering window)
$script:HOTKEY_ID_LEFT  = 9001
$script:HOTKEY_ID_RIGHT = 9002
$script:HOTKEY_ID_UP    = 9003
$script:HOTKEY_ID_DOWN  = 9004

$script:HotkeyWindowHandle = [IntPtr]::Zero
$script:HotkeySource       = $null
$script:HotkeyHook         = $null
$script:HotkeyCallbacks    = @{}
$script:HotkeysRegistered  = $false

function Register-GlobalArrowHotkeys {
    <#
    .SYNOPSIS
        Registers global Left/Right/Up/Down hotkeys against the given WPF
        window and wires each to a scriptblock callback.

    .PARAMETER Window
        The WPF Window object (must already be Show()n / have a handle).

    .PARAMETER OnLeft / OnRight / OnUp / OnDown
        Scriptblocks invoked (on the UI thread) when each key fires.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Window,
        [Parameter(Mandatory)] [scriptblock]$OnLeft,
        [Parameter(Mandatory)] [scriptblock]$OnRight,
        [Parameter(Mandatory)] [scriptblock]$OnUp,
        [Parameter(Mandatory)] [scriptblock]$OnDown
    )

    # Guard against stacking hooks/hotkeys if this is called again while
    # already registered (e.g. the "Hotkeys enabled" checkbox is toggled
    # more than once) - always start from a clean slate.
    if ($script:HotkeysRegistered) {
        Unregister-GlobalArrowHotkeys
    }

    $helper = New-Object System.Windows.Interop.WindowInteropHelper($Window)
    $script:HotkeyWindowHandle = $helper.Handle

    if ($script:HotkeyWindowHandle -eq [IntPtr]::Zero) {
        Write-Error "Register-GlobalArrowHotkeys: window handle not available yet - call after the window is shown."
        return $false
    }

    $script:HotkeyCallbacks = @{
        $script:HOTKEY_ID_LEFT  = $OnLeft
        $script:HOTKEY_ID_RIGHT = $OnRight
        $script:HOTKEY_ID_UP    = $OnUp
        $script:HOTKEY_ID_DOWN  = $OnDown
    }

    $ok = $true
    $ok = $ok -and [Win32.HotkeyNative]::RegisterHotKey($script:HotkeyWindowHandle, $script:HOTKEY_ID_LEFT,  $script:MOD_NOREPEAT, $script:VK_LEFT)
    $ok = $ok -and [Win32.HotkeyNative]::RegisterHotKey($script:HotkeyWindowHandle, $script:HOTKEY_ID_RIGHT, $script:MOD_NOREPEAT, $script:VK_RIGHT)
    $ok = $ok -and [Win32.HotkeyNative]::RegisterHotKey($script:HotkeyWindowHandle, $script:HOTKEY_ID_UP,    $script:MOD_NOREPEAT, $script:VK_UP)
    $ok = $ok -and [Win32.HotkeyNative]::RegisterHotKey($script:HotkeyWindowHandle, $script:HOTKEY_ID_DOWN,  $script:MOD_NOREPEAT, $script:VK_DOWN)

    if (-not $ok) {
        Write-Warning "Register-GlobalArrowHotkeys: one or more hotkeys failed to register (likely already claimed by another app). Unregistering any that succeeded."
        Unregister-GlobalArrowHotkeys
        return $false
    }

    # Hook WM_HOTKEY (0x0312) on this window's message pump.
    $source = [System.Windows.Interop.HwndSource]::FromHwnd($script:HotkeyWindowHandle)
    $hook = [System.Windows.Interop.HwndSourceHook] {
        param($hwnd, $msg, $wParam, $lParam, [ref]$handled)
        if ($msg -eq 0x0312) {
            $id = $wParam.ToInt32()
            if ($script:HotkeyCallbacks.ContainsKey($id)) {
                & $script:HotkeyCallbacks[$id]
                $handled.Value = $true
            }
        }
        return [IntPtr]::Zero
    }
    $source.AddHook($hook)
    $script:HotkeySource      = $source
    $script:HotkeyHook        = $hook
    $script:HotkeysRegistered = $true

    return $true
}

function Unregister-GlobalArrowHotkeys {
    <#
    .SYNOPSIS
        Releases the four global hotkeys. Safe to call even if not registered.
    #>
    [CmdletBinding()]
    param()

    if ($script:HotkeyWindowHandle -ne [IntPtr]::Zero) {
        [Win32.HotkeyNative]::UnregisterHotKey($script:HotkeyWindowHandle, $script:HOTKEY_ID_LEFT)  | Out-Null
        [Win32.HotkeyNative]::UnregisterHotKey($script:HotkeyWindowHandle, $script:HOTKEY_ID_RIGHT) | Out-Null
        [Win32.HotkeyNative]::UnregisterHotKey($script:HotkeyWindowHandle, $script:HOTKEY_ID_UP)    | Out-Null
        [Win32.HotkeyNative]::UnregisterHotKey($script:HotkeyWindowHandle, $script:HOTKEY_ID_DOWN)  | Out-Null
    }

    # Critical: also detach the WM_HOTKEY hook itself. Without this, a
    # stale hook stays attached to the HwndSource; the next Register call
    # adds ANOTHER hook on top of it, and since both hooks close over the
    # same $script:HotkeyCallbacks, a single key press ends up invoking
    # the Next/Prev callback multiple times (e.g. Right jumping snap1 ->
    # snap2 -> snap3, or overshooting into the next folder).
    if ($script:HotkeySource -and $script:HotkeyHook) {
        $script:HotkeySource.RemoveHook($script:HotkeyHook) | Out-Null
    }
    $script:HotkeySource = $null
    $script:HotkeyHook   = $null

    $script:HotkeysRegistered = $false
}
