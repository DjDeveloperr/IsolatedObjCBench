"use strict";

const { TestObject: V8DirectTestObject } = require("./build/Release/direct.node");
const { TestObject: NapiTestObject } = require("./build/Release/napi.node");

const repeat = Number(process.env.REPEAT || 9);
const iterations = Number(process.env.ITERATIONS || 2_000_000);
const warmupIterations = Number(process.env.WARMUP || 100_000);

let sink = 0;

function makeCachedPassThroughProxy(target) {
  const cache = Object.create(null);
  return new Proxy(target, {
    get(object, property, receiver) {
      const value = Reflect.get(object, property, receiver);
      if (typeof value !== "function") {
        return value;
      }

      const cached = cache[property];
      if (cached !== undefined) {
        return cached;
      }

      return (cache[property] = value.bind(object));
    },
    set(object, property, value, receiver) {
      return Reflect.set(object, property, value, receiver);
    },
  });
}

function median(values) {
  const sorted = values.slice().sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

function mean(values) {
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function format(value, digits = 1) {
  return Number.isFinite(value) ? value.toFixed(digits) : "n/a";
}

function runTimed(iterationCount, fn) {
  const start = process.hrtime.bigint();
  sink ^= fn(iterationCount) | 0;
  const elapsedNs = Number(process.hrtime.bigint() - start);
  return elapsedNs / iterationCount;
}

function jsLoop(iterationCount) {
  let total = 0;
  for (let i = 0; i < iterationCount; i++) {
    total += (i & 255) + 7;
  }
  return total;
}

function callOneOff(object, iterationCount) {
  let total = 0;
  for (let i = 0; i < iterationCount; i++) {
    total += object.oneOff();
  }
  return total;
}

function callAdd(object, iterationCount) {
  let total = 0;
  for (let i = 0; i < iterationCount; i++) {
    total += object.add(i & 255, 3);
  }
  return total;
}

function callCached(method, iterationCount) {
  let total = 0;
  for (let i = 0; i < iterationCount; i++) {
    total += method(i & 255, 3);
  }
  return total;
}

function callCachedOneOff(method, iterationCount) {
  let total = 0;
  for (let i = 0; i < iterationCount; i++) {
    total += method();
  }
  return total;
}

const direct = new V8DirectTestObject();
const napi = new NapiTestObject();
const napiProxy = makeCachedPassThroughProxy(new NapiTestObject());

const cases = [
  {
    name: "js.loop.baseline",
    path: "js",
    method: "loop",
    fn: (count) => jsLoop(count),
  },
  {
    name: "direct.oneOff",
    path: "v8-direct",
    method: "oneOff",
    fn: (count) => callOneOff(direct, count),
  },
  {
    name: "node-api.oneOff",
    path: "node-api",
    method: "oneOff",
    fn: (count) => callOneOff(napi, count),
  },
  {
    name: "node-api-proxy.oneOff",
    path: "node-api-proxy",
    method: "oneOff",
    fn: (count) => callOneOff(napiProxy, count),
  },
  {
    name: "direct.add",
    path: "v8-direct",
    method: "add",
    fn: (count) => callAdd(direct, count),
  },
  {
    name: "node-api.add",
    path: "node-api",
    method: "add",
    fn: (count) => callAdd(napi, count),
  },
  {
    name: "node-api-proxy.add",
    path: "node-api-proxy",
    method: "add",
    fn: (count) => callAdd(napiProxy, count),
  },
  {
    name: "direct.oneOff.cachedMethod",
    path: "v8-direct",
    method: "oneOff.cached",
    fn: (count) => callCachedOneOff(direct.oneOff.bind(direct), count),
  },
  {
    name: "node-api.oneOff.cachedMethod",
    path: "node-api",
    method: "oneOff.cached",
    fn: (count) => callCachedOneOff(napi.oneOff.bind(napi), count),
  },
  {
    name: "node-api-proxy.oneOff.cachedMethod",
    path: "node-api-proxy",
    method: "oneOff.cached",
    fn: (count) => callCachedOneOff(napiProxy.oneOff, count),
  },
  {
    name: "direct.add.cachedMethod",
    path: "v8-direct",
    method: "add.cached",
    fn: (count) => callCached(direct.add.bind(direct), count),
  },
  {
    name: "node-api.add.cachedMethod",
    path: "node-api",
    method: "add.cached",
    fn: (count) => callCached(napi.add.bind(napi), count),
  },
  {
    name: "node-api-proxy.add.cachedMethod",
    path: "node-api-proxy",
    method: "add.cached",
    fn: (count) => callCached(napiProxy.add, count),
  },
];

function main() {
  const samples = new Map(cases.map((item) => [item.name, []]));

  for (let i = 0; i < repeat; i++) {
    const order = i % 2 === 0 ? cases : cases.slice().reverse();
    for (const item of order) {
      item.fn(warmupIterations);
      const nsPerOp = runTimed(iterations, item.fn);
      samples.get(item.name).push(nsPerOp);
      process.stdout.write(
        `run ${i + 1}/${repeat} ${item.name}: ${format(nsPerOp, 2)} ns/op\n`
      );
    }
  }

  const rows = cases.map((item) => {
    const values = samples.get(item.name);
    return {
      name: item.name,
      path: item.path,
      method: item.method,
      medianNsPerOp: median(values),
      meanNsPerOp: mean(values),
      minNsPerOp: Math.min(...values),
      maxNsPerOp: Math.max(...values),
    };
  });

  const byName = new Map(rows.map((row) => [row.name, row]));
  const comparisonRows = rows.map((row) => {
    let directName = null;
    if (row.name.includes(".oneOff")) {
      directName = row.name.includes(".cachedMethod")
        ? "direct.oneOff.cachedMethod"
        : "direct.oneOff";
    } else if (row.name.includes(".add")) {
      directName = row.name.includes(".cachedMethod")
        ? "direct.add.cachedMethod"
        : "direct.add";
    }

    const directRow = directName != null ? byName.get(directName) : null;
    const vsDirect =
      directRow != null && row.name !== directName
        ? row.medianNsPerOp / directRow.medianNsPerOp
        : null;

    return {
      ...row,
      vsDirect,
    };
  });

  console.log("");
  console.log(
    `Node ${process.version}, repeat=${repeat}, iterations=${iterations}, warmup=${warmupIterations}, sink=${sink}`
  );
  console.log("");
  console.log("| case | path | median ns/op | mean ns/op | min | max | vs direct |");
  console.log("|---|---|---:|---:|---:|---:|---:|");
  for (const row of comparisonRows) {
    console.log(
      `| ${row.name} | ${row.path} | ${format(row.medianNsPerOp)} | ${format(
        row.meanNsPerOp
      )} | ${format(row.minNsPerOp)} | ${format(row.maxNsPerOp)} | ${
        row.vsDirect == null ? "" : `${format(row.vsDirect, 2)}x`
      } |`
    );
  }
}

main();

