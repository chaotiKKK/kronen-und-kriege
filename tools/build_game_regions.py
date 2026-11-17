from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.game_regions import RegionBuildConfig, build_regions, load_frozen_inputs, validate_manifest, write_outputs


def main():
    inputs = load_frozen_inputs(ROOT)
    config = RegionBuildConfig()
    result = build_regions(inputs, config)
    errors = validate_manifest(result.manifest, result.frame, config)
    if errors:
        print("\n".join(errors))
        return 1
    digest = write_outputs(result, ROOT / "data", ROOT / "build/verify/game-regions-build.json")
    print(f"{len(result.manifest['regions'])} Spielregionen; Katalog {digest}")
    print(f"Echte Atlasgrenzlänge: {result.audit['qualified_boundary_length']:.6f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
