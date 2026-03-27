"""Basic tests for the research project."""

from src.main import load_config


def test_load_config():
    config = load_config("config.yaml")
    assert "experiment" in config
    assert "name" in config["experiment"]
