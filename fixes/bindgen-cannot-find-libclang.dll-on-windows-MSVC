# Fix: `bindgen` / `rquickjs-sys` cannot find `libclang.dll` (Windows MSVC)

## Problem

Rust build fails with:

```
Unable to find libclang: couldn't find any valid shared libraries matching: ['clang.dll', 'libclang.dll']
```

Cause: `bindgen` requires a Windows MSVC-compatible `libclang.dll` and the system does not have one installed or visible to Cargo.

---

## 1. Install LLVM (provides libclang.dll)

Open **PowerShell as Administrator**:

```powershell
winget install --id LLVM.LLVM -e
```

If `winget` is unavailable, download the Windows installer from [https://llvm.org](https://llvm.org) and install to the default path:

```
C:\Program Files\LLVM
```

---

## 2. Verify installation

```powershell
Test-Path 'C:\Program Files\LLVM\bin\libclang.dll'
Get-ChildItem 'C:\Program Files\LLVM\bin' -Filter 'libclang*.dll'
```

Expected: `True` and a listed `libclang.dll`.

---

## 3. Temporary fix (current terminal only)

```powershell
$env:LIBCLANG_PATH = 'C:\Program Files\LLVM\bin'
cargo clean
cargo build -v
```

---

## 4. Permanent fix (recommended)

```powershell
[Environment]::SetEnvironmentVariable('LIBCLANG_PATH','C:\Program Files\LLVM\bin','User')
```

Restart the terminal afterwards.

---

## 5. Alternative: Add LLVM to PATH instead

```powershell
$old = [Environment]::GetEnvironmentVariable('Path','User')
[Environment]::SetEnvironmentVariable('Path', $old + ';C:\Program Files\LLVM\bin','User')
```

Restart the terminal afterwards.

---

## 6. If build still fails

```powershell
$env:RUST_BACKTRACE=1
$env:LIBCLANG_PATH='C:\Program Files\LLVM\bin'
cargo build -v 2>&1 | Select-Object -Last 40
```

Inspect output for `bindgen` or `libclang` errors.

---

## Notes

* This applies to the MSVC Rust toolchain on Windows.
* Do not use MSYS2 `libclang` with MSVC toolchains.
* `libclang.dll` must be 64‑bit and match the installed LLVM version.
