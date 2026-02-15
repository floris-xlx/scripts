# Windows DriverStore Corruption Repair (0xC0000490 / Invalid INF)

## Problem

System-wide device install failures after firmware change.

Indicators:

* `0xC0000490` everywhere
* Unknown manufacturer / class GUID
* ACPI + USB + storage + network all failing
* `setupapi.dev.log` shows invalid INF parsing

Example:

```
Invalid INF ... DriverStore\FileRepository\netathrx.inf ... parsing error line 0
Failed to get version info ... Error = 0x00000003
```

Meaning: registry driver index and physical driver packages no longer match. PnP refuses to attach any class installer.

INFCACHE rebuild is not enough. Entire DriverStore must be regenerated from WinSxS.

---

## Goal

Force Windows to boot with an empty driver database so it reconstructs all drivers from the component store.

---

## Step 1 — Stop services (best effort)

Run elevated CMD:

```
sc config trustedinstaller start= auto
net stop wuauserv
net stop cryptSvc
net stop bits
net stop trustedinstaller
```

Ignore failures.

---

## Step 2 — Schedule offline DriverStore wipe

DriverStore cannot be renamed live. Queue rename before kernel loads drivers.

```
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" ^
/v PendingFileRenameOperations /t REG_MULTI_SZ /d "\??\C:\Windows\INF\0\??\C:\Windows\INF.old\0\??\C:\Windows\System32\DriverStore\0\??\C:\Windows\System32\DriverStore.old\0" /f
```

Create replacement directories so boot continues:

```
mkdir C:\Windows\INF
mkdir C:\Windows\System32\DriverStore
mkdir C:\Windows\System32\DriverStore\FileRepository
```

---

## Step 3 — Reboot immediately

```
shutdown /r /t 0
```

---

## What happens on next boot

Very early boot (before PnP):

```
INF -> INF.old
DriverStore -> DriverStore.old
```

Windows detects empty driver database and rebuilds from WinSxS.

Expect:

* 10–25 minute boot
* screen flicker
* hardware reinstall loops
* USB disconnect/reconnect

Do not interrupt.

---

## After login

System loads generic drivers first. Now reinstall platform stack in order:

1. Chipset INF
2. Intel MEI
3. Intel DTT / Thread Director
4. GPU / other drivers

---


