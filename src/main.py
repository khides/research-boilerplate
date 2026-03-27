"""Research project entry point."""

import argparse
from pathlib import Path

import yaml


def load_config(config_path: str = "config.yaml") -> dict:
    """Load experiment configuration from YAML file."""
    with open(config_path) as f:
        return yaml.safe_load(f)


def main() -> None:
    parser = argparse.ArgumentParser(description="Research project")
    parser.add_argument(
        "--config",
        type=str,
        default="config.yaml",
        help="Path to config file",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default=None,
        help="Override output directory",
    )
    args = parser.parse_args()

    config = load_config(args.config)
    output_dir = Path(args.output_dir or config["experiment"]["output_dir"])
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Experiment: {config['experiment']['name']}")
    print(f"Output: {output_dir}")
    print("TODO: Implement your research pipeline here")


if __name__ == "__main__":
    main()
