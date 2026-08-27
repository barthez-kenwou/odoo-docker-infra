// =============================================================================
// k6 load test. Run with:
//   BASE_URL=https://staging-odoo.example.com k6 run tests/load/k6_load_test.js
//
// Profile: ramps to a realistic small-business concurrency (30 VUs), holds,
// then ramps down. Thresholds encode the SLOs documented in docs/SLO_SLA.md
// — a failed threshold fails the CI job the same way a failed unit test would.
// =============================================================================
import http from "k6/http";
import { check, sleep } from "k6";

const BASE_URL = __ENV.BASE_URL || "http://localhost";

export const options = {
  stages: [
    { duration: "1m", target: 10 },   // warm-up
    { duration: "3m", target: 30 },   // steady state
    { duration: "1m", target: 60 },   // peak burst
    { duration: "2m", target: 30 },   // back to steady state
    { duration: "1m", target: 0 },    // ramp down
  ],
  thresholds: {
    // See docs/SLO_SLA.md: p95 login latency budget.
    http_req_duration: ["p(95)<1500"],
    http_req_failed: ["rate<0.01"],
  },
};

export default function () {
  const res = http.get(`${BASE_URL}/web/login`, {
    // Self-signed cert in dev/staging drills; real cert in production.
    insecureSkipTLSVerify: true,
  });

  check(res, {
    "status is 200": (r) => r.status === 200,
    "has security headers": (r) => r.headers["Strict-Transport-Security"] !== undefined,
    "responded under 3s": (r) => r.timings.duration < 3000,
  });

  sleep(Math.random() * 2 + 1); // 1-3s think time between requests, like a real user
}

export function handleSummary(data) {
  return {
    "tests/load/last-run-summary.json": JSON.stringify(data, null, 2),
    stdout: `p95=${data.metrics.http_req_duration.values["p(95)"].toFixed(0)}ms  ` +
            `error_rate=${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%\n`,
  };
}
