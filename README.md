# IGTweak — Instagram Modification Dylib

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2015%2B-blue" />
  <img src="https://img.shields.io/badge/arch-arm64-green" />
  <img src="https://img.shields.io/badge/Instagram-434.0.0-purple" />
  <img src="https://img.shields.io/badge/language-Objective--C-orange" />
</p>

Runtime tweak for decrypted Instagram IPA. Injects an Objective-C dylib that hooks into Instagram's classes via `objc/runtime.h` method swizzling.

## Features

| Feature | Status | Hooked Class |
|---------|--------|-------------|
| 🚫 Remove feed ads | ✅ | `IGAdInsertionHandler`, `IGAdFetcherManager` |
| 🚫 Remove story ads | ✅ | `IGStoryAdInsertionDataSource` |
| 👻 Ghost Mode (view stories anonymously) | ✅ | `IGStorySeenStateUploader` |
| 🔇 Disable typing indicator in Direct | ✅ | `IGDirectTypingStatusService` |
| 📸 Disable screenshot notifications | ✅ | `IGScreenshotResharePromptController`, `NSNotificationCenter` |

## How It Works

```
Instagram launches
  └─→ dyld loads IGTweak.dylib
       └─→ __attribute__((constructor)) fires
            └─→ Method Swizzling via objc/runtime.h
                 ├─→ IGAdInsertionHandler hooks (block feed ads)
                 ├─→ IGStoryAdInsertionDataSource hooks (block story ads)
                 ├─→ IGStorySeenStateUploader hooks (ghost mode)
                 ├─→ IGDirectTypingStatusService hooks (no typing indicator)
                 └─→ NSNotificationCenter hooks (no screenshot alerts)
```

## Prerequisites

- macOS with Xcode (for iOS SDK & clang)
- Decrypted Instagram IPA (place contents in project root)
- `insert_dylib` — auto-built by `inject.sh` or build from [tyilo/insert_dylib](https://github.com/tyilo/insert_dylib)

## Quick Start

### 1. Place your decrypted Instagram IPA

Extract your decrypted IPA so the project structure looks like:

```
.
├── Payload/
│   └── Instagram.app/
│       └── Instagram          # decrypted Mach-O binary
├── Tweak/
│   ├── IGTweak.m              # tweak source code
│   └── Makefile               # arm64 dylib build
├── inject.sh                  # automation script
└── .gitignore
```

### 2. Build & Inject

```bash
chmod +x inject.sh
./inject.sh
```

This will:
1. Compile `IGTweak.dylib` (arm64, iOS 15+)
2. Copy it into `Instagram.app/Frameworks/`
3. Inject `LC_LOAD_DYLIB` into the Instagram binary
4. Remove PlugIns & code signatures
5. Package `Instagram-Modded.ipa`

### 3. Install

Install `Instagram-Modded.ipa` on your device using:
- [Sideloadly](https://sideloadly.io/)
- [AltStore](https://altstore.io/)
- [TrollStore](https://github.com/opa334/TrollStore)

## Project Structure

```
Tweak/
├── IGTweak.m       # All hooks (5 features, ~250 lines)
└── Makefile        # Compiles arm64 dylib via xcrun --sdk iphoneos
inject.sh           # Full automation: build → inject → package
.gitignore          # Excludes Payload/, Headers/, *.ipa
```

## Adding New Hooks

Edit `Tweak/IGTweak.m` and add your hook:

```objc
// 1. Store original IMP
static IMP orig_myMethod = NULL;

// 2. Write replacement
static void hook_myMethod(id self, SEL _cmd, id arg1) {
    NSLog(@"[IGTweak] Hooked!");
    // Call original if needed:
    // ((void(*)(id, SEL, id))orig_myMethod)(self, _cmd, arg1);
}

// 3. Install in constructor
swizzleMethod(NSClassFromString(@"IGSomeClass"),
              @selector(someMethod:),
              (IMP)hook_myMethod,
              &orig_myMethod);
```

Then rebuild: `./inject.sh`

## Dumping Headers

The headers were dumped using `otool -ov` since `class-dump` and `dsdump` cannot parse modern chained-fixups Mach-O binaries. If you need to re-dump:

```bash
mkdir -p Headers
# Use the otool-based script or icdump (Python)
python3 -m pip install icdump
```

## Disclaimer

This project is for **educational and research purposes only**. Do not use it to violate Instagram's Terms of Service. The authors are not responsible for any consequences of using this software.

## License

MIT
