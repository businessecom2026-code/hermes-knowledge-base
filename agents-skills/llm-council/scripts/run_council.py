#!/usr/bin/env python3
"""Run the installed LLM Council without starting its web interface."""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path


DEFAULT_COUNCIL_HOME = Path("C:/Users/judon/.agents/tools/llm-council")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prompt-file", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


async def main() -> int:
    args = parse_args()
    council_home = Path(os.getenv("LLM_COUNCIL_HOME", str(DEFAULT_COUNCIL_HOME)))

    # Load the tool-local, gitignored credential without exposing its value.
    from dotenv import load_dotenv

    load_dotenv(council_home / ".env")
    if not os.getenv("OPENROUTER_API_KEY"):
        print("OPENROUTER_API_KEY is not configured.", file=sys.stderr)
        return 2

    if not (council_home / "backend" / "council.py").is_file():
        print(f"LLM Council installation not found: {council_home}", file=sys.stderr)
        return 3

    prompt = args.prompt_file.read_text(encoding="utf-8").strip()
    if not prompt:
        print("Prompt file is empty.", file=sys.stderr)
        return 4

    sys.path.insert(0, str(council_home))
    os.chdir(council_home)
    from backend.council import run_full_council

    stage1, stage2, stage3, metadata = await run_full_council(prompt)
    result = {
        "prompt_file": str(args.prompt_file.resolve()),
        "stage1": stage1,
        "stage2": stage2,
        "stage3": stage3,
        "metadata": metadata,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(args.output.resolve())
    return 0 if stage1 and stage3.get("model") != "error" else 5


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
