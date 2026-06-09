# IsolatedObjCBench

Minimal Objective-C object bridge benchmark for four paths in the same Node/V8 process:

- direct V8 addon wrapper
- Node-API addon wrapper
- Node-API host-object wrapper, modeled after the custom host-object extension in `napi-android`
- Node-API addon wrapper behind a cached pass-through JS `Proxy`

Each JS object owns a real `IOBTestObject` Objective-C instance. The native object exposes:

- `oneOff() -> number`
- `add(a, b) -> number`

The benchmark is intentionally tiny. It exists to answer one question without the noise of metadata lookup, selector resolution, or a full runtime: for a JS object tied to a real Objective-C object, how much overhead comes from direct V8 callbacks, Node-API callbacks, host-object internal-field lookup, and a pass-through JS proxy?

The `node-api-hostobject` path mirrors the mechanism in `~/Developer/napi-android`: the constructor returns a V8 host object with four internal fields and V8 named/indexed property interceptors, while the hot `oneOff`/`add` methods still enter Node-API callback functions and still use Node-API argument/return conversion. Stock Node does not expose `napi_create_host_object`, so this target implements the same V8-side shape inside the benchmark addon.

## Layout

- `src/TestObjectNative.mm`: the Objective-C object implementation, built once into `testobject.dylib`
- `src/direct_addon.mm`: direct V8 wrapper around the native object
- `src/napi_addon.mm`: Node-API wrapper around the same native object
- `src/napi_hostobject_addon.mm`: Node-API callback wrapper using a V8 host object for property forwarding and native data
- `bench.js`: benchmark harness and proxy variant
- `RESULTS.md`: latest captured result table and interpretation

## Requirements

- macOS
- Xcode command line tools
- Node.js `>=22`

## Run

```sh
npm install
npm run build
npm run bench
```

Useful knobs:

```sh
REPEAT=11 ITERATIONS=5000000 WARMUP=250000 npm run bench
```

To approximate an iOS-style no-JIT runtime in local Node/V8, run with V8 JIT disabled:

```sh
REPEAT=9 ITERATIONS=5000000 WARMUP=250000 npm run bench:jitless
```

The `*.cachedMethod` cases bind/read the method once before the timed loop. The uncached cases call `obj.method(...)` inside the loop and therefore include property lookup, plus the proxy `get` trap for the proxy path.

For a quick sanity check:

```sh
npm test
```

## Current Takeaway

The isolated benchmark shows the host-object design removes most of the avoidable overhead in this tiny path. Plain Node-API is still about `2.4x-4.0x` over direct V8 depending on JIT mode and method shape, while the host-object path is about `1.3x-1.6x`. The pass-through JS `Proxy` remains expensive when method lookup happens in the timed loop. See `RESULTS.md` for numbers.
