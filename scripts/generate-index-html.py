#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "pyyaml",
#     "jinja2",
# ]
# ///

import sys
from pathlib import Path
from typing import TypedDict

import yaml
from jinja2 import Environment, FileSystemLoader


class ChartVersion(TypedDict, total=False):
    version: str
    appVersion: str
    description: str
    keywords: list[str]


class ChartData(TypedDict):
    name: str
    version: str
    app_version: str
    description: str
    keywords: list[str]


class HelmIndex(TypedDict):
    entries: dict[str, list[ChartVersion]]


def load_index_yaml(yaml_path: Path) -> HelmIndex:
    return yaml.safe_load(yaml_path.read_text())


def extract_chart_data(chart_name: str, versions: list[ChartVersion]) -> ChartData:
    latest_version = versions[0]

    return {
        "name": chart_name,
        "version": latest_version.get("version", "unknown"),
        "app_version": latest_version.get("appVersion", "N/A"),
        "description": latest_version.get("description", "No description available"),
        "keywords": latest_version.get("keywords", []),
    }


def parse_charts(index_data: HelmIndex) -> list[ChartData]:
    charts = []

    for chart_name, versions in index_data.get("entries", {}).items():
        if not versions:
            continue

        chart_data = extract_chart_data(chart_name, versions)
        charts.append(chart_data)

    charts.sort(key=lambda chart: chart["name"])

    return charts


def load_template(template_dir: Path) -> Environment:
    env = Environment(loader=FileSystemLoader(template_dir))
    return env


def generate_html(charts: list[ChartData], template_dir: Path) -> str:
    env = load_template(template_dir)
    template = env.get_template("index.html.j2")
    return template.render(charts=charts)


def write_html(html_content: str, output_path: Path) -> None:
    _ = output_path.write_text(html_content)


def main() -> None:
    if len(sys.argv) < 2:
        print(
            "Usage: generate-index-html.py <index.yaml> [output.html]", file=sys.stderr
        )
        sys.exit(1)

    index_yaml_path = Path(sys.argv[1])
    output_html_path = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("index.html")

    if not index_yaml_path.exists():
        print(f"Error: {index_yaml_path} not found", file=sys.stderr)
        sys.exit(1)

    script_dir = Path(__file__).parent
    template_dir = script_dir

    index_data = load_index_yaml(index_yaml_path)
    charts = parse_charts(index_data)
    html_content = generate_html(charts, template_dir)
    write_html(html_content, output_html_path)

    print(f"✓ Generated {output_html_path} from {index_yaml_path}")


if __name__ == "__main__":
    main()
