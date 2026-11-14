# Galaxy on Fire 2 Full HD – macOS patch

Patch for the Mac App Store version of *Galaxy on Fire 2 Full HD* that restores native fullscreen, keyboard input and mouse steering on current macOS.

This repository contains only the patch tooling. It does not contain any game files.

> [!IMPORTANT]
> **Disclaimer:** This patch was built with the help of AI. Running untrusted scripts may be dangerous. Check the code carefully before you execute anything. Use at your own risk.

## Tested versions

| macOS | Architecture | Status |
|---|---|---|
| 26.3 (Tahoe) | Apple Silicon (arm64) | ✅ |
| 15.7 (Sequoia) | Intel (x86_64) | ✅ |

## What it fixes

| Issue | Fix |
|---|---|
| Fullscreen is a legacy overlay covering the menu bar and Dock | Uses a native macOS fullscreen Space |
| Keys only produce the system beep | Fullscreen window can become key window |
| Mouse steering only works while the left button is held | Fullscreen window receives mouse-moved events |
| Patched app quits with `exit(173)` | Self signature check is bypassed |

## Requirements

- The original game installed (default: `/Applications/Galaxy on Fire 2 Full HD.app`)
- Xcode command line tools (`xcode-select --install`)
- Python 3
- Intel Mac, or Apple Silicon with Rosetta

## Usage

```sh
./apply.sh [path/to/original.app] [output.app]
```

- The original app defaults to `/Applications/Galaxy on Fire 2 Full HD.app` and is never modified.
- The output defaults to `Galaxy on Fire 2 Full HD.app` in the repository root (git-ignored). An existing copy is replaced.

Then start the patched app:

```sh
open -n "Galaxy on Fire 2 Full HD.app"
```

macOS may ask for approval on first launch because the app is signed ad hoc.

**Download and patch the game on each Mac separately.** The App Store receipt is tied to the Mac that downloaded the game. A patched copy moved to another Mac exits with `exit(173)`. Do not copy the patched app between machines.

## In-app purchases

The add-ons (Kaamo, Supernova, Valkyrie) and in-game money should be bought in the **unmodified** app. Purchases made there appear automatically in the patched app. Buying in the patched app is untested and probably does not work.

## Repository layout

| Path | Purpose |
|---|---|
| `apply.sh` | Builds the patched copy of the game |
| `src/gof2fix.m` | Source of the shim dylib that is loaded into the game |
| `tools/inject.py` | Adds an `LC_LOAD_DYLIB` command to a thin x86_64 Mach-O |
| `config/ent.plist` | Entitlements for the ad-hoc signature (sandbox, network, USB) |

## What `apply.sh` does

1. Copies the original app and removes the stray `embedded.mobileprovision`, which breaks the bundle seal.
2. Thins the executable to x86_64 and removes its signature.
3. Compiles `src/gof2fix.m` into `Contents/Frameworks/libgof2fix.dylib`.
4. Runs `tools/inject.py` so the game loads the dylib at startup.
5. Re-signs the frameworks and the app ad hoc with `config/ent.plist`, then clears extended attributes.

## How the patch works

Found by disassembling the x86_64 binary. The shim hooks the following:

- **Keyboard:** `-[NSWindow canBecomeKeyWindow]` and `canBecomeMainWindow` return `YES`. The game's borderless fullscreen window returned `NO`, so `BasicOpenGLView -keyDown:` never received events and AppKit beeped.
- **Fullscreen:** after `MainController -goFullscreenWindow`, the window gets a titled, full-size-content style mask, normal window level and `FullScreenPrimary`, then `toggleFullScreen:` enters a native Space. `goWindow` closes it again with `orderOut:` when returning to windowed mode.
- **Mouse steering:** the fullscreen window gets `setAcceptsMouseMovedEvents:YES`, so `BasicOpenGLView -mouseMoved:` is called after the right-click toggle, not only `mouseDragged:`.
- **Signature check:** the game calls `SecStaticCodeCheckValidity` on itself as copy protection, and exits with code 173 if the check fails. The shim interposes the function (`__DATA,__interpose`) to return success.

## Limitations

- iCloud save sync does not work, so the iCloud save slot is not available in the patched app. The restricted entitlements (`application-identifier`, iCloud container) were dropped because they need a provisioning profile. Local save files are shared with the unmodified app.
- The patched app only runs on the Mac it was built on. The receipt check is not bypassed, so copying the app to another Mac fails with `exit(173)`.
- The patched binary is x86_64 only. The game's 32-bit slice is removed.
- The fullscreen change relies on the game's own `reshape` handling of the new view size. If the picture is scaled wrongly, check the resolution selected in the game options.

## License

The patch tooling in this repository is released under the [MIT License](LICENSE). It covers only this repository's code. *Galaxy on Fire 2* and its assets belong to their respective rights holders, and this project is not affiliated with or endorsed by them.
