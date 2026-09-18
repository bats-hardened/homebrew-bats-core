#!/usr/bin/env bash
set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

declare -a curl_args=(
  --fail
  --silent
  --show-error
  --location
  --retry 4
  --retry-connrefused
)

if [ -n "${GITHUB_TOKEN:-}" ]; then
  curl_args+=(--header "Authorization: Bearer $GITHUB_TOKEN")
fi

update_formula() {
  local repo="$1"
  local formula="$2"
  local release
  local tag
  local version
  local archive
  local sha256

  release="$(curl "${curl_args[@]}" \
    "https://api.github.com/repos/$repo/releases/latest")"
  tag="$(printf '%s' "$release" |
    sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
    head -n 1)"

  case "$tag" in
    v*) version="${tag#v}" ;;
    *)
      echo "Failed to resolve a v-prefixed release tag for $repo" >&2
      exit 1
      ;;
  esac

  archive="$temp_dir/${repo##*/}.tar.gz"
  curl "${curl_args[@]}" --output "$archive" \
    "https://github.com/$repo/archive/refs/tags/$tag.tar.gz"

  sha256="$(sha256sum "$archive")"
  sha256="${sha256%% *}"

  sed -i \
    -e "s#^  url \"https://github.com/$repo/archive/refs/tags/.*\.tar\.gz\"#  url \"https://github.com/$repo/archive/refs/tags/$tag.tar.gz\"#" \
    -e "s/^  sha256 \"[0-9a-f]*\"/  sha256 \"$sha256\"/" \
    "$script_dir/Formula/$formula.rb"

  echo "$repo: $version" >&2
}

update_formula "bats-core/bats-support" bats-support
update_formula "bats-core/bats-assert" bats-assert
update_formula "bats-core/bats-detik" bats-detik
update_formula "bats-core/bats-file" bats-file
