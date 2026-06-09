# Results

## JIT Enabled

Run:

```sh
REPEAT=9 ITERATIONS=5000000 WARMUP=250000 npm run bench
```

Environment:

- Node `v26.1.0`
- macOS arm64
- native `IOBTestObject` lives once in `build/Release/testobject.dylib`
- `direct.node` uses direct V8 callbacks
- `napi.node` uses Node-API callbacks
- proxy path is a cached pass-through JS `Proxy` around a Node-API object

| case | path | median ns/op | vs direct |
|---|---|---:|---:|
| js.loop.baseline | js | 0.3 | |
| direct.oneOff | v8-direct | 11.5 | |
| node-api.oneOff | node-api | 38.1 | 3.31x |
| node-api-proxy.oneOff | node-api-proxy | 53.4 | 4.65x |
| direct.add | v8-direct | 14.0 | |
| node-api.add | node-api | 44.2 | 3.17x |
| node-api-proxy.add | node-api-proxy | 60.1 | 4.31x |
| direct.oneOff.cachedMethod | v8-direct | 9.1 | |
| node-api.oneOff.cachedMethod | node-api | 35.9 | 3.95x |
| node-api-proxy.oneOff.cachedMethod | node-api-proxy | 35.7 | 3.93x |
| direct.add.cachedMethod | v8-direct | 11.4 | |
| node-api.add.cachedMethod | node-api | 42.4 | 3.73x |
| node-api-proxy.add.cachedMethod | node-api-proxy | 42.1 | 3.70x |

Interpretation:

- Node-API alone is already roughly `3.2x-4.0x` slower than the direct V8 wrapper for tiny calls.
- The pass-through proxy adds visible overhead only when the benchmark performs `obj.method(...)` inside the loop, because that includes the proxy `get` trap every iteration.
- When the method is read/bound once before timing, proxy overhead mostly disappears. Those cached-method rows isolate callback, unwrap, argument conversion, Objective-C call, and return conversion.
- This supports the idea that the large gap is not primarily a JS `Proxy` issue. Proxies matter for property-heavy call sites, but the core Node-API callback boundary is already much heavier than direct V8.

## JIT Disabled

Run:

```sh
REPEAT=9 ITERATIONS=5000000 WARMUP=250000 node --jitless bench.js
```

Environment:

- Node `v26.1.0`
- V8 JIT disabled with `--jitless`
- macOS arm64
- same native object/addon layout as above

| case | path | median ns/op | vs direct |
|---|---|---:|---:|
| js.loop.baseline | js | 7.9 | |
| direct.oneOff | v8-direct | 18.5 | |
| node-api.oneOff | node-api | 46.0 | 2.48x |
| node-api-proxy.oneOff | node-api-proxy | 82.9 | 4.48x |
| direct.add | v8-direct | 23.1 | |
| node-api.add | node-api | 53.0 | 2.29x |
| node-api-proxy.add | node-api-proxy | 89.2 | 3.86x |
| direct.oneOff.cachedMethod | v8-direct | 16.2 | |
| node-api.oneOff.cachedMethod | node-api | 43.4 | 2.67x |
| node-api-proxy.oneOff.cachedMethod | node-api-proxy | 43.6 | 2.69x |
| direct.add.cachedMethod | v8-direct | 20.7 | |
| node-api.add.cachedMethod | node-api | 50.9 | 2.46x |
| node-api-proxy.add.cachedMethod | node-api-proxy | 51.1 | 2.47x |

Interpretation:

- Disabling JIT raises the JS loop baseline from about `0.3 ns/op` to about `7.9 ns/op`, so the benchmark is now much closer to an interpreter-only runtime profile.
- Direct V8 still wins, but its advantage over plain Node-API shrinks from roughly `3.2x-4.0x` to roughly `2.3x-2.7x`.
- The pass-through proxy remains expensive for uncached `obj.method(...)` calls because the proxy `get` trap is now interpreted too.
- Cached-method proxy rows still match plain Node-API, which reinforces that the proxy cost is specifically property lookup/trap cost, not native callback cost.
