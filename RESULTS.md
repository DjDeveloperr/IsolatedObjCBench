# Results

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
