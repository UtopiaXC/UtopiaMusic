#!/usr/bin/env python3
"""Release helper script for rendering GitHub Release notes and artifact tables."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
from urllib.parse import quote


@dataclass(frozen=True)
class ArtifactSpec:
    suffixes: tuple[str, ...]
    platform: str
    arch: str
    description: str
    priority: int


ARTIFACT_SPECS: tuple[ArtifactSpec, ...] = (
    ArtifactSpec(
        suffixes=("-Android-arm64-v8a.apk", "-Android-v8a.apk"),
        platform="Android",
        arch="arm64-v8a",
        description="64位安装包，适用于主流安卓设备",
        priority=10,
    ),
    ArtifactSpec(
        suffixes=("-Android-armeabi-v7a.apk", "-Android-v7a.apk"),
        platform="Android",
        arch="armeabi-v7a",
        description="32位安装包，适用于旧款安卓设备",
        priority=11,
    ),
    ArtifactSpec(
        suffixes=("-Android-x86_64.apk",),
        platform="Android",
        arch="x86_64",
        description="适用于x86架构设备或模拟器",
        priority=12,
    ),
    ArtifactSpec(
        suffixes=("-iOS-universal.ipa",),
        platform="iOS",
        arch="Universal",
        description="未签名包，需使用AltStore等工具侧载安装",
        priority=20,
    ),
    ArtifactSpec(
        suffixes=("-macOS-universal.dmg",),
        platform="macOS",
        arch="Universal",
        description="磁盘镜像，首次打开需允许来自未知开发者的应用",
        priority=30,
    ),
    ArtifactSpec(
        suffixes=("-Windows-x64-setup.exe",),
        platform="Windows",
        arch="x64",
        description="推荐，标准安装程序",
        priority=40,
    ),
    ArtifactSpec(
        suffixes=("-Windows-x64-portable.zip",),
        platform="Windows",
        arch="x64",
        description="便携压缩包，解压即用",
        priority=41,
    ),
    ArtifactSpec(
        suffixes=("-Linux-x64.AppImage",),
        platform="Linux",
        arch="x64",
        description="推荐，通用可执行镜像",
        priority=50,
    ),
    ArtifactSpec(
        suffixes=("-Linux-x64.deb",),
        platform="Linux",
        arch="x64",
        description="适用于Debian及Ubuntu系发行版",
        priority=51,
    ),
    ArtifactSpec(
        suffixes=("-Linux-x64.rpm",),
        platform="Linux",
        arch="x64",
        description="适用于RHEL、CentOS及Fedora系发行版",
        priority=52,
    ),
)


def format_size(size_bytes: int) -> str:
    return f"{size_bytes / (1024 * 1024):.2f} MB"


def match_spec(filename: str) -> ArtifactSpec:
    for spec in ARTIFACT_SPECS:
        if any(filename.endswith(suffix) for suffix in spec.suffixes):
            return spec
    return ArtifactSpec(
        suffixes=(),
        platform="Other",
        arch="-",
        description="发布产物",
        priority=999,
    )


def collect_artifacts(artifacts_dir: Path) -> list[tuple[ArtifactSpec, Path]]:
    files = sorted(
        (path for path in artifacts_dir.rglob("*") if path.is_file()),
        key=lambda path: path.name,
    )
    entries = [(match_spec(path.name), path) for path in files]
    entries.sort(key=lambda item: (item[0].priority, item[1].name))
    return entries


def build_download_url(server_url: str, repo: str, tag: str, filename: str) -> str:
    base = server_url.rstrip("/")
    return f"{base}/{repo}/releases/download/{quote(tag)}/{quote(filename)}"


def render_matrix_table(
    entries: Iterable[tuple[ArtifactSpec, Path]],
    server_url: str,
    repo: str,
    tag: str,
) -> str:
    rows = [
        "| Platform | Arch | Artifact | Size | Description |",
        "| --- | --- | --- | --- | --- |",
    ]
    for spec, path in entries:
        url = build_download_url(server_url, repo, tag, path.name)
        size = format_size(path.stat().st_size)
        artifact_link = f"[{path.name}]({url})"
        rows.append(
            f"| {spec.platform} | {spec.arch} | {artifact_link} | {size} | {spec.description} |"
        )
    return "\n".join(rows)


def render_release_body(
    *,
    note_path: Path,
    artifacts_dir: Path,
    repo: str,
    tag: str,
    version_name: str,
    server_url: str = "https://github.com",
) -> str:
    note_content = note_path.read_text(encoding="utf-8").strip()
    entries = collect_artifacts(artifacts_dir)
    if not entries:
        raise FileNotFoundError(f"No release artifacts found in {artifacts_dir}")

    sections = [
        f"# Utopia Music v{version_name}",
        "",
        note_content,
        "",
        "## Build Matrix",
        "",
        render_matrix_table(entries, server_url, repo, tag),
        "",
    ]
    return "\n".join(sections)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Helpers for UtopiaMusic CI release notes and build matrices."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    render_cmd = subparsers.add_parser(
        "render-release-body",
        help="Combine release notes and artifact download matrix into markdown.",
    )
    render_cmd.add_argument("--note", type=Path, required=True)
    render_cmd.add_argument("--artifacts-dir", type=Path, required=True)
    render_cmd.add_argument("--repo", required=True)
    render_cmd.add_argument("--tag", required=True)
    render_cmd.add_argument("--version-name", required=True)
    render_cmd.add_argument("--server-url", default="https://github.com")
    render_cmd.add_argument("--output", type=Path, required=True)

    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.command == "render-release-body":
        body = render_release_body(
            note_path=args.note,
            artifacts_dir=args.artifacts_dir,
            repo=args.repo,
            tag=args.tag,
            version_name=args.version_name,
            server_url=args.server_url,
        )
        args.output.write_text(body, encoding="utf-8")
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
