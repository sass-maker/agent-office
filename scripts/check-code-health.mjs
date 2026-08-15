#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const productionPaths = ["Sources"];

function log(message) {
  process.stdout.write(`${message}\n`);
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: projectRoot,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  if (result.error) throw result.error;
  if (result.status !== 0 && !options.allowFailure) {
    process.stdout.write(result.stdout ?? "");
    process.stderr.write(result.stderr ?? "");
    throw new Error(`${command} exited with status ${result.status}`);
  }
  return result;
}

function failRegressions(label, observed, baseline) {
  const regressions = Object.entries(baseline).filter(
    ([key, maximum]) => observed[key] > maximum,
  );
  if (regressions.length > 0) {
    throw new Error(
      regressions
        .map(
          ([key, maximum]) =>
            `${label} ${key} regressed: ${observed[key]} > ${maximum}`,
        )
        .join("\n"),
    );
  }
  if (Object.entries(baseline).some(([key, maximum]) => observed[key] < maximum)) {
    log(`${label} improved; lower the checked-in baseline intentionally.`);
  }
}

function checkMinimums(label, observed, minimums) {
  const regressions = Object.entries(minimums).filter(
    ([key, minimum]) => observed[key] + Number.EPSILON < minimum,
  );
  if (regressions.length > 0) {
    throw new Error(
      regressions
        .map(
          ([key, minimum]) =>
            `${label} ${key} regressed: ${observed[key]} < ${minimum}`,
        )
        .join("\n"),
    );
  }
  if (Object.entries(minimums).some(([key, minimum]) => observed[key] > minimum)) {
    log(`${label} improved; raise the checked-in baseline intentionally.`);
  }
}

function checkFormat() {
  const result = run(
    "xcrun",
    ["swift-format", "lint", "--strict", "--recursive", "Sources", "Tests"],
    { allowFailure: true },
  );
  const diagnostics = `${result.stdout}\n${result.stderr}`
    .split("\n")
    .filter((line) => line.includes("error:")).length;
  log(`Swift format debt: ${diagnostics} diagnostics.`);
  // Ratcheted legacy debt: https://github.com/sass-maker/agent-office/issues/21
  failRegressions("Swift format", { diagnostics }, { diagnostics: 0 });
}

function checkCoverage() {
  const testResult = run("swift", ["test", "--enable-code-coverage"]);
  const testOutput = `${testResult.stdout}\n${testResult.stderr}`;
  const testCounts = [...testOutput.matchAll(/Executed (\d+) tests/gu)].map((match) =>
    Number(match[1]),
  );
  const tests = Math.max(0, ...testCounts);
  if (tests === 0) throw new Error("Swift test run executed zero XCTest tests.");

  const pathResult = run("swift", ["test", "--show-codecov-path"]);
  const reportPath = pathResult.stdout.trim();
  const report = JSON.parse(readFileSync(reportPath, "utf8"));
  const files = report.data[0].files.filter((file) =>
    file.filename.includes("/Sources/AgentOfficeCore/"),
  );
  const sum = (metric, field) =>
    files.reduce((total, file) => total + file.summary[metric][field], 0);
  const percentage = (metric) => (sum(metric, "covered") / sum(metric, "count")) * 100;
  const observed = {
    lines: percentage("lines"),
    functions: percentage("functions"),
    regions: percentage("regions"),
  };
  log(
    `Tests and core coverage: ${tests} tests; ${observed.lines.toFixed(4)}% lines, ` +
      `${observed.functions.toFixed(4)}% functions, ${observed.regions.toFixed(4)}% regions.`,
  );
  // Ratcheted legacy debt: https://github.com/sass-maker/agent-office/issues/21
  checkMinimums("AgentOfficeCore coverage", observed, {
    lines: 84,
    functions: 72,
    regions: 69,
  });
}

function checkBuild() {
  run("swift", ["build"]);
  log("Swift build: clean.");
}

function checkUnused() {
  const scratch = mkdtempSync(join(tmpdir(), "agent-office-periphery-"));
  const requestedIndexStore = join(scratch, "index-store");
  run("swift", [
    "build",
    "--scratch-path",
    scratch,
    "-Xswiftc",
    "-index-store-path",
    "-Xswiftc",
    requestedIndexStore,
  ]);
  const indexStore = [requestedIndexStore, join(scratch, "out")].find(existsSync);
  if (!indexStore) {
    throw new Error("Swift build did not produce the requested Periphery index store.");
  }
  const result = run("periphery", [
    "scan",
    "--skip-build",
    "--index-store-path",
    indexStore,
    "--format",
    "json",
    "--relative-results",
    "--disable-update-check",
    "--quiet",
    "--retain-public",
  ]);
  const observed = { findings: JSON.parse(result.stdout).length };
  log(`Swift unused-code debt: ${observed.findings} Periphery findings.`);
  // Ratcheted legacy debt: https://github.com/sass-maker/agent-office/issues/21
  failRegressions("Swift unused code", observed, { findings: 4 });
}

function checkComplexity() {
  const result = run("uvx", [
    "--from",
    "lizard==1.23.0",
    "lizard",
    ...productionPaths,
    "--csv",
  ]);
  const rows = result.stdout
    .trim()
    .split("\n")
    .map((line) => line.match(/^(\d+),(\d+),(\d+),(\d+),(\d+),/u))
    .filter(Boolean)
    .map((match) => match.slice(1).map(Number));
  const observed = {
    functions: rows.length,
    nloc: rows.reduce((sum, row) => sum + row[0], 0),
    violations: rows.filter((row) => row[1] > 15 || row[4] > 100 || row[3] > 7)
      .length,
    maxCcn: Math.max(...rows.map((row) => row[1])),
    maxLength: Math.max(...rows.map((row) => row[4])),
    maxParams: Math.max(...rows.map((row) => row[3])),
  };
  log(
    `Complexity: ${observed.functions} functions, ${observed.nloc} NLOC, ` +
      `${observed.violations} violations; max CCN ${observed.maxCcn}, ` +
      `max length ${observed.maxLength}, max params ${observed.maxParams}.`,
  );
  // Ratcheted legacy debt: https://github.com/sass-maker/agent-office/issues/21
  failRegressions("Complexity", observed, {
    violations: 40,
    maxCcn: 25,
    maxLength: 293,
    maxParams: 28,
  });
}

function checkDuplication() {
  const outputDirectory = mkdtempSync(join(tmpdir(), "agent-office-jscpd-"));
  run("npx", [
    "--yes",
    "jscpd@5.0.14",
    "Sources",
    "--format",
    "swift",
    "--min-lines",
    "8",
    "--min-tokens",
    "60",
    "--mode",
    "strict",
    "--ignore",
    "**/Resources/**",
    "--reporters",
    "json",
    "--output",
    outputDirectory,
    "--silent",
    "--no-tips",
  ]);
  const observed = JSON.parse(
    readFileSync(join(outputDirectory, "jscpd-report.json"), "utf8"),
  ).statistics.total;
  log(
    `Duplication: ${observed.duplicatedLines}/${observed.lines} lines ` +
      `(${observed.percentage.toFixed(4)}%), ${observed.clones} groups across ` +
      `${observed.sources} files.`,
  );
  // Ratcheted legacy debt: https://github.com/sass-maker/agent-office/issues/21
  failRegressions("Duplication", observed, {
    clones: 3,
    duplicatedLines: 31,
    // Rounded slightly above the observed 0.72101% because jscpd's percentage
    // varies in its last digits between runs.
    percentage: 0.1469,
  });
}

function checkDependencies() {
  const result = run("swift", ["package", "show-dependencies", "--format", "json"]);
  const report = JSON.parse(result.stdout);
  const observed = { dependencies: report.dependencies.length };
  log(`Dependencies: ${observed.dependencies} external Swift packages.`);
  failRegressions("Dependencies", observed, { dependencies: 0 });
}

function countMatches(pattern) {
  const result = run(
    "git",
    ["grep", "-n", "-E", pattern, "--", "Sources", "Tests"],
    { allowFailure: true },
  );
  return result.stdout.trim() ? result.stdout.trim().split("\n") : [];
}

function checkSuppressions() {
  const matches = countMatches(
    "swiftlint:disable|swift-format-ignore|coverage:ignore|nocov",
  );
  log(`Suppressions: ${matches.length} inline directives.`);
  if (matches.length > 0) {
    throw new Error(`Unjustified suppressions:\n${matches.join("\n")}`);
  }
}

function checkHygiene() {
  // An empty tracked file is almost always an accident, and an empty gate
  // script would pass every check by doing nothing at all.
  const emptyFiles = run("git", ["ls-files", "--", "."])
    .stdout.split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .filter((file) => {
      try {
        return statSync(file).size === 0;
      } catch {
        return false;
      }
    });
  if (emptyFiles.length > 0) {
    throw new Error(`Tracked files are empty:\n${emptyFiles.join("\n")}`);
  }
  const conflictMarkers = run(
    "git",
    ["grep", "-n", "-E", "^(<<<<<<<|=======|>>>>>>>)", "--", "."],
    { allowFailure: true },
  ).stdout.trim();
  if (conflictMarkers) throw new Error(`Conflict markers:\n${conflictMarkers}`);
  const todos = countMatches("TODO|FIXME");
  if (todos.length > 0) {
    throw new Error(`Durable TODO/FIXME markers:\n${todos.join("\n")}`);
  }
  run("git", ["diff", "--check", "HEAD", "--", "."]);
  log("Repository hygiene: clean.");
}

function checkSite() {
  run("node", ["--check", "site/script.js"]);
  run("node", ["scripts/check-site.mjs"]);
  log("Static site: clean.");
}

const checks = {
  build: checkBuild,
  complexity: checkComplexity,
  coverage: checkCoverage,
  dependencies: checkDependencies,
  duplication: checkDuplication,
  format: checkFormat,
  hygiene: checkHygiene,
  site: checkSite,
  suppressions: checkSuppressions,
  unused: checkUnused,
};

function checkAll() {
  checkFormat();
  checkCoverage();
  checkBuild();
  checkUnused();
  checkComplexity();
  checkDuplication();
  checkDependencies();
  checkSuppressions();
  checkHygiene();
  checkSite();
}

const selected = process.argv[2];
if (selected === "all") {
  try {
    checkAll();
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exit(1);
  }
} else if (Object.hasOwn(checks, selected)) {
  try {
    checks[selected]();
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exit(1);
  }
} else {
  process.stderr.write(`Usage: check-code-health.mjs <all|${Object.keys(checks).join("|")}>\n`);
  process.exit(2);
}
