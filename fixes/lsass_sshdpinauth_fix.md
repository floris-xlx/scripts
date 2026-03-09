# Fix: Windows "Restarting in 1 minute" Caused by LSASS Crash

## Problem


https://learn.microsoft.com/en-us/answers/questions/3894031/c-windowssystem32lsass-exe-failed-with-status-code
Windows repeatedly displays:

    Windows will restart in 1 minute

or

    A critical system process, C:\Windows\System32\lsass.exe, failed with status code c0000409.
    The machine must now be restarted.

During the countdown:

-   New programs cannot be opened
-   The system appears partially locked
-   A forced reboot occurs after the timer

## Investigation

While the issue occurred, Event Viewer logs were inspected.

Path:

    Event Viewer → Windows Logs → Application

Relevant log entries showed:

Faulting application: `lsass.exe`\
Faulting module: `SshdPinAuthLsa.dll`\
Exception code: `0xc0000409`

<img width="1707" height="1063" alt="image" src="https://github.com/user-attachments/assets/eed4c3ac-a83d-439c-893c-adf11cb3b17e" />

<img width="1260" height="609" alt="image" src="https://github.com/user-attachments/assets/f64e69f3-8597-4377-b3f4-83ade8b543a4" />


Example:

    Faulting application name: lsass.exe
    Faulting module name: SshdPinAuthLsa.dll
    Exception code: 0xc0000409
    Faulting application path: C:\Windows\System32\lsass.exe
    Faulting module path: C:\Windows\System32\SshdPinAuthLsa.dll

## Cause

`SshdPinAuthLsa.dll` is an **LSA authentication provider** used with
Windows authentication systems (e.g., Windows Hello or SSH
authentication extensions).

LSASS loads authentication providers during login and security
operations.\
If one of these providers is corrupted or incompatible, it can crash
`lsass.exe`.

Because LSASS is a **critical system process**, Windows immediately
forces a system restart when it fails.

## Fix

Remove the faulty authentication provider.

### Step 1 --- Locate the Module

    C:\Windows\System32\SshdPinAuthLsa.dll

### Step 2 --- Remove the File

Delete the DLL or unregister it if it was installed as an LSA provider.

### Step 3 --- Reboot

Restart the system.

## Result

After removing `SshdPinAuthLsa.dll`:

-   `lsass.exe` no longer crashes
-   The "Restarting in 1 minute" message stops
-   Windows operates normally

## Key Takeaway

If Windows repeatedly forces restarts due to LSASS failure:

1.  Open Event Viewer
2.  Find the **faulting module inside lsass.exe**
3.  Remove or fix the corresponding **LSA authentication provider**
