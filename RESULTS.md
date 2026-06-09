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
- `napi.node` uses Node-API callbacks with `napi_wrap`/`napi_unwrap`
- `napi_hostobject.node` mirrors the `napi-android` host-object shape: V8 internal-field data plus named/indexed interceptors, while methods still use Node-API callbacks
- proxy path is a cached pass-through JS `Proxy` around a Node-API object

| case | path | median ns/op | vs direct |
|---|---|---:|---:|
| js.loop.baseline | js | 0.3 | |
| direct.oneOff | v8-direct | 12.5 | |
| node-api.oneOff | node-api | 40.8 | 3.27x |
| node-api-hostobject.oneOff | node-api-hostobject | 16.6 | 1.33x |
| node-api-proxy.oneOff | node-api-proxy | 57.6 | 4.62x |
| direct.add | v8-direct | 14.9 | |
| node-api.add | node-api | 46.0 | 3.09x |
| node-api-hostobject.add | node-api-hostobject | 21.3 | 1.43x |
| node-api-proxy.add | node-api-proxy | 63.7 | 4.28x |
| direct.oneOff.cachedMethod | v8-direct | 9.6 | |
| node-api.oneOff.cachedMethod | node-api | 38.2 | 3.99x |
| node-api-hostobject.oneOff.cachedMethod | node-api-hostobject | 14.4 | 1.51x |
| node-api-proxy.oneOff.cachedMethod | node-api-proxy | 38.1 | 3.98x |
| direct.add.cachedMethod | v8-direct | 12.1 | |
| node-api.add.cachedMethod | node-api | 42.3 | 3.49x |
| node-api-hostobject.add.cachedMethod | node-api-hostobject | 18.8 | 1.55x |
| node-api-proxy.add.cachedMethod | node-api-proxy | 42.7 | 3.52x |

Interpretation:

- The host-object path closes most of the gap between plain Node-API and direct V8 for this tiny native call. Cached `oneOff` drops from `38.2 ns/op` with `napi_unwrap` to `14.4 ns/op` with internal-field host-object data.
- The JS `Proxy` cost is still real for uncached `obj.method(...)` calls: `node-api-proxy.oneOff` is `57.6 ns/op`, while the cached proxy method is `38.1 ns/op`.
- The host-object interceptor is much cheaper than JS `Proxy` lookup. `node-api-hostobject.oneOff` is only `2.2 ns/op` above its cached-method row, while the JS proxy is about `19.5 ns/op` above its cached-method row.
- Direct V8 is still faster because it avoids the Node-API callback/argument/return conversion boundary entirely.

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
| js.loop.baseline | js | 8.4 | |
| direct.oneOff | v8-direct | 20.3 | |
| node-api.oneOff | node-api | 53.4 | 2.63x |
| node-api-hostobject.oneOff | node-api-hostobject | 26.4 | 1.30x |
| node-api-proxy.oneOff | node-api-proxy | 87.0 | 4.29x |
| direct.add | v8-direct | 24.7 | |
| node-api.add | node-api | 58.5 | 2.37x |
| node-api-hostobject.add | node-api-hostobject | 32.0 | 1.30x |
| node-api-proxy.add | node-api-proxy | 96.0 | 3.89x |
| direct.oneOff.cachedMethod | v8-direct | 17.3 | |
| node-api.oneOff.cachedMethod | node-api | 47.4 | 2.75x |
| node-api-hostobject.oneOff.cachedMethod | node-api-hostobject | 22.5 | 1.31x |
| node-api-proxy.oneOff.cachedMethod | node-api-proxy | 47.3 | 2.74x |
| direct.add.cachedMethod | v8-direct | 22.2 | |
| node-api.add.cachedMethod | node-api | 55.7 | 2.51x |
| node-api-hostobject.add.cachedMethod | node-api-hostobject | 29.7 | 1.34x |
| node-api-proxy.add.cachedMethod | node-api-proxy | 56.4 | 2.54x |

Interpretation:

- With JIT disabled, host-object lookup stays close to direct V8: about `1.30x-1.34x` direct in all rows.
- Plain Node-API remains roughly `2.4x-2.8x` direct, so the host-object/internal-field path still removes a large share of the overhead under an iOS-like no-JIT profile.
- JS proxy lookup gets much worse without JIT. Uncached proxy calls land at `87.0-96.0 ns/op`; cached proxy calls collapse back to plain Node-API because the proxy `get` trap is no longer in the timed loop.
- The strongest signal is the cached-method comparison: `node-api-hostobject.*.cachedMethod` avoids proxy lookup and mostly isolates callback/data/argument/return overhead. Those rows are roughly half the cost of plain Node-API.

## Notes

Stock Node does not provide `napi_create_host_object`, `napi_get_host_object_data`, or `napi_is_host_object`. The benchmark target therefore implements the same V8-side mechanism locally instead of calling a public Node symbol. One important compatibility detail fell out of that experiment: stock `napi_define_class` methods are receiver-branded and reject the synthetic host object with `Illegal invocation`, so the host-object target uses a plain Node-API constructor function plus plain Node-API prototype functions.
