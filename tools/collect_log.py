"""Extract probe lines from a supplied stdout.txt; never package saves or game assets."""
import argparse
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("stdout", type=Path)
parser.add_argument("--output", type=Path, default=Path("reports/native-probe.log"))
args = parser.parse_args()
lines = args.stdout.read_text(encoding="utf-8", errors="replace").splitlines()
selected = [line for line in lines if "[CargoDistribution]" in line or
            ("cargo_distribution" in line.lower() and "error" in line.lower())]
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text("\n".join(selected) + "\n", encoding="utf-8")
print(f"Collected {len(selected)} probe/error lines into {args.output}")
