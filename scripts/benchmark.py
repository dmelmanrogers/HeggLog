#!/usr/bin/env python3
"""Run the HeggLog release benchmark suite."""

from __future__ import annotations

import argparse
import json
import shutil
import statistics
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class BenchmarkCase:
    name: str
    args: list[str]
    expected_stdout: str | None = None
    stdout_contains: str | None = None
    expected_stderr: str | None = None
    stderr_contains: str | None = None


def fail(message: str) -> None:
    print(f"benchmark failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def run_command(args: list[str], *, stdin: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=ROOT,
        input=stdin,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def require_success(label: str, completed: subprocess.CompletedProcess[str]) -> None:
    if completed.returncode != 0:
        print(completed.stdout, end="")
        print(completed.stderr, end="", file=sys.stderr)
        fail(f"{label} exited with {completed.returncode}")


def build_executable() -> Path:
    build = run_command(["cabal", "build", "exe:hegglog"])
    require_success("cabal build exe:hegglog", build)

    list_bin = run_command(["cabal", "list-bin", "exe:hegglog"])
    require_success("cabal list-bin exe:hegglog", list_bin)
    executable = Path(list_bin.stdout.strip())
    if not executable.is_file():
        fail(f"cabal list-bin returned missing executable: {executable}")
    return executable


def benchmark_cases(executable: Path, work_dir: Path) -> list[BenchmarkCase]:
    lazy_exe = work_dir / "lazy-argument"
    modules_dir = ROOT / "examples" / "haskell2010" / "modules"
    return [
        BenchmarkCase(
            name="check-fibonacci",
            args=[str(executable), "check", "examples/haskell2010/fibonacci.hs"],
            expected_stdout="",
            expected_stderr="",
        ),
        BenchmarkCase(
            name="emit-core-typeclass",
            args=[str(executable), "emit-core", "examples/haskell2010/typeclass-dictionary.hs", "--both"],
            stdout_contains="Optimized Typed Core",
            expected_stderr="",
        ),
        BenchmarkCase(
            name="run-fibonacci",
            args=[str(executable), "run", "examples/haskell2010/fibonacci.hs"],
            expected_stdout="21\n",
            expected_stderr="",
        ),
        BenchmarkCase(
            name="compile-lazy-native",
            args=[
                str(executable),
                "compile",
                "examples/haskell2010/lazy-argument.hs",
                "-o",
                str(lazy_exe),
            ],
            expected_stdout="",
            stderr_contains="wrote native executable to",
        ),
        BenchmarkCase(
            name="execute-compiled-lazy",
            args=[str(lazy_exe)],
            expected_stdout="1\n",
            expected_stderr="",
        ),
        BenchmarkCase(
            name="report-standard-library",
            args=[str(executable), "report", "examples/haskell2010/standard-library.hs"],
            stdout_contains="Status: ok",
            expected_stderr="",
        ),
        BenchmarkCase(
            name="check-module-graph",
            args=[
                str(executable),
                "check",
                str(modules_dir / "Main.hs"),
                "--import-path",
                str(modules_dir),
            ],
            expected_stdout="",
            expected_stderr="",
        ),
    ]


def validate_output(case: BenchmarkCase, completed: subprocess.CompletedProcess[str]) -> None:
    require_success(case.name, completed)
    if case.expected_stdout is not None and completed.stdout != case.expected_stdout:
        fail(
            f"{case.name} stdout mismatch: expected {case.expected_stdout!r}, got {completed.stdout!r}"
        )
    if case.stdout_contains is not None and case.stdout_contains not in completed.stdout:
        fail(f"{case.name} stdout does not contain {case.stdout_contains!r}")
    if case.expected_stderr is not None and completed.stderr != case.expected_stderr:
        fail(
            f"{case.name} stderr mismatch: expected {case.expected_stderr!r}, got {completed.stderr!r}"
        )
    if case.stderr_contains is not None and case.stderr_contains not in completed.stderr:
        fail(f"{case.name} stderr does not contain {case.stderr_contains!r}")


def run_case(case: BenchmarkCase) -> dict[str, object]:
    started = time.perf_counter()
    completed = run_command(case.args)
    elapsed = time.perf_counter() - started
    validate_output(case, completed)
    return {
        "duration_seconds": elapsed,
        "stdout_bytes": len(completed.stdout.encode("utf-8")),
        "stderr_bytes": len(completed.stderr.encode("utf-8")),
    }


def summarize_runs(runs: list[dict[str, object]]) -> dict[str, float]:
    durations = [float(run["duration_seconds"]) for run in runs]
    return {
        "min_seconds": min(durations),
        "median_seconds": statistics.median(durations),
        "max_seconds": max(durations),
    }


def write_outputs(output_dir: Path, result: dict[str, object]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / "benchmark.json"
    md_path = output_dir / "benchmark.md"

    json_path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    lines = [
        "# HeggLog Benchmark Summary",
        "",
        f"- Generated at: {result['generated_at']}",
        f"- Iterations: {result['iterations']}",
        f"- Executable: `{result['executable']}`",
        "",
        "| Benchmark | Median seconds | Min seconds | Max seconds |",
        "| --- | ---: | ---: | ---: |",
    ]
    for benchmark in result["benchmarks"]:  # type: ignore[index]
        lines.append(
            "| {name} | {median:.6f} | {minimum:.6f} | {maximum:.6f} |".format(
                name=benchmark["name"],
                median=benchmark["median_seconds"],
                minimum=benchmark["min_seconds"],
                maximum=benchmark["max_seconds"],
            )
        )
    lines.append("")
    md_path.write_text("\n".join(lines), encoding="utf-8")

    print(md_path.read_text(encoding="utf-8"), end="")
    print(f"benchmark artifacts written to {output_dir}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--iterations",
        type=int,
        default=1,
        help="number of measured iterations for each benchmark case",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(".context/benchmarks"),
        help="directory for benchmark JSON and Markdown artifacts",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.iterations < 1:
        fail("--iterations must be at least 1")

    output_dir = args.output_dir
    work_dir = output_dir / "work"
    if output_dir.exists():
        shutil.rmtree(output_dir)
    work_dir.mkdir(parents=True, exist_ok=True)

    executable = build_executable()
    benchmarks = []
    for case in benchmark_cases(executable, work_dir):
        runs = [run_case(case) for _ in range(args.iterations)]
        benchmarks.append(
            {
                "name": case.name,
                "command": case.args,
                "runs": runs,
                **summarize_runs(runs),
            }
        )

    result: dict[str, object] = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "iterations": args.iterations,
        "executable": str(executable),
        "benchmarks": benchmarks,
    }
    write_outputs(output_dir, result)


if __name__ == "__main__":
    main()
