# Another ADE

Greenfield native macOS app workspace for the session-first ADE described in `.compozy/tasks/native-mac-ade`.

## Build, test, and run

```bash
swift build
swift test
./scripts/run.sh
./scripts/run.sh bundle
```

The initial scaffold uses Swift Package Manager to keep the workspace lightweight while defining a SwiftUI app executable, a core library target, and a unit test target.

`./scripts/run.sh` also supports `build` and `test` modes:

```bash
./scripts/run.sh build
./scripts/run.sh bundle
./scripts/run.sh test
```

`run` and `bundle` create a real `.app` bundle inside `.build/.../debug/NativeMacADE.app`, which makes the app show up in the Dock like a normal macOS app.
