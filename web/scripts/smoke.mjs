import { readFile } from "node:fs/promises";
import { parseIbkrReport } from "../src/parser.js";

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const text = await readFile(new URL("../samples/ibkr-sample-demo.csv", import.meta.url), "utf8");
const data = parseIbkrReport(text);

assert(data.baseCurrency === "USD", `Expected USD base currency, got ${data.baseCurrency}`);
assert(data.positions.length === 10, `Expected 10 positions, got ${data.positions.length}`);
assert(data.tradeDetails.length === 109, `Expected 109 trade details, got ${data.tradeDetails.length}`);
assert(Object.keys(data.sectionStats).length === 23, "Expected 23 parsed report sections");
assert(data.warnings.length === 0, `Expected no parser warnings, got ${data.warnings.length}`);
assert(data.accountInfo.account === "U12345678", `Expected sample account, got ${data.accountInfo.account}`);
assert(Number.isFinite(data.nav.total), "Expected finite total NAV");

console.log("Smoke test passed:", {
  baseCurrency: data.baseCurrency,
  positions: data.positions.length,
  trades: data.tradeDetails.length,
  sections: Object.keys(data.sectionStats).length,
  totalNav: data.nav.total
});
