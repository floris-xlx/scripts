# Rust Analyzer: can't load standard library (Windows MSVC install)

## Symptom

Rust Analyzer repeatedly logs:

```
ERROR can't load standard library, try installing `rust-src`
sysroot_path=C:\Program Files\Rust stable MSVC 1.93
thread panicked: called `Result::unwrap()` on an `Err` value: SendError(..)
```

IDE features depending on type information fail (completion, go-to-definition, diagnostics).

## Root Cause

Rust was installed using the standalone Windows installer instead of `rustup`.

Rust Analyzer expects a toolchain layout managed by `rustup` and attempts to locate the standard library source inside the sysroot. The standalone installation does not contain the `rust-src` component and exposes a different directory structure, so the language server cannot resolve `core`, `std`, and `alloc` crates.

Result: analyzer initialization fails and panics during reload.

### sysroot Override

If `cargo` exists but the IDE points to the standalone install, explicitly set the sysroot used by rust-analyzer:

```
settings.json

{
  "rust-analyzer.cargo.sysroot": "C:\\Users\\floris\\.rustup\\toolchains\\stable-x86_64-pc-windows-msvc"
}
```

After restart, rust-analyzer resolves the standard library and stops panicking.

Rust Analyzer does not use `cargo.exe` to discover the toolchain; it queries the sysroot and expects the Rust source tree (`lib/rustlib/src/rust/library`). Only rustup-managed toolchains guarantee that layout. Pointing the analyzer to the rustup sysroot or installing `rust-src` restores semantic analysis.
