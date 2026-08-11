#!/bin/zsh

set -euo pipefail

configuration="${1:-release}"
case "$configuration" in
    debug|release) ;;
    *)
        print -u2 "usage: $0 [debug|release]"
        exit 64
        ;;
esac

script_dir="$(cd "$(dirname "$0")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
product_name="AgentOffice"
display_name="${AGENT_OFFICE_DISPLAY_NAME:-Office OS}"
resource_name="AgentOffice_AgentOffice.bundle"
bundle_id="${AGENT_OFFICE_BUNDLE_ID:-com.sassmaker.officeos}"
short_version="${AGENT_OFFICE_VERSION:-0.1.0}"
build_version="${AGENT_OFFICE_BUILD_NUMBER:-1}"
signing_identity="${AGENT_OFFICE_SIGNING_IDENTITY:--}"

cd "$project_dir"
swift build -c "$configuration"
bin_dir="$(swift build -c "$configuration" --show-bin-path)"
executable="$bin_dir/$product_name"
resource_bundle="$bin_dir/$resource_name"
icon_source="$project_dir/Sources/AgentOffice/Resources/app-icon-editorial.png"
small_icon_source="$project_dir/Sources/AgentOffice/Resources/app-icon-editorial-small.png"

if [[ ! -x "$executable" ]]; then
    print -u2 "missing executable: $executable"
    exit 1
fi

if [[ ! -d "$resource_bundle" ]]; then
    print -u2 "missing SwiftPM resource bundle: $resource_bundle"
    exit 1
fi

stage_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-office-package.XXXXXX")"
stage_app="$stage_root/$product_name.app"
contents_dir="$stage_app/Contents"

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$executable" "$contents_dir/MacOS/$product_name"
cp -R "$resource_bundle" "$contents_dir/Resources/$resource_name"

if [[ -f "$icon_source" ]]; then
    iconset_dir="$project_dir/.build/AppIcon.iconset"
    mkdir -p "$iconset_dir"
    for spec in \
        "16 icon_16x16.png" \
        "32 icon_16x16@2x.png" \
        "32 icon_32x32.png" \
        "64 icon_32x32@2x.png" \
        "128 icon_128x128.png" \
        "256 icon_128x128@2x.png" \
        "256 icon_256x256.png" \
        "512 icon_256x256@2x.png" \
        "512 icon_512x512.png" \
        "1024 icon_512x512@2x.png"; do
        size="${spec%% *}"
        filename="${spec#* }"
        source="$icon_source"
        if [[ "$size" -le 64 && -f "$small_icon_source" ]]; then
            source="$small_icon_source"
        fi
        sips -z "$size" "$size" "$source" --out "$iconset_dir/$filename" >/dev/null
    done
    iconutil -c icns "$iconset_dir" -o "$contents_dir/Resources/AppIcon.icns"
fi

info_plist="$contents_dir/Info.plist"
plutil -create xml1 "$info_plist"
plutil -insert CFBundleDevelopmentRegion -string en "$info_plist"
plutil -insert CFBundleDisplayName -string "$display_name" "$info_plist"
plutil -insert CFBundleExecutable -string "$product_name" "$info_plist"
plutil -insert CFBundleIdentifier -string "$bundle_id" "$info_plist"
plutil -insert CFBundleName -string "$display_name" "$info_plist"
if [[ -f "$contents_dir/Resources/AppIcon.icns" ]]; then
    plutil -insert CFBundleIconFile -string AppIcon "$info_plist"
fi
plutil -insert CFBundlePackageType -string APPL "$info_plist"
plutil -insert CFBundleShortVersionString -string "$short_version" "$info_plist"
plutil -insert CFBundleVersion -string "$build_version" "$info_plist"
plutil -insert LSMinimumSystemVersion -string 14.0 "$info_plist"
plutil -insert NSHighResolutionCapable -bool true "$info_plist"
plutil -insert NSPrincipalClass -string NSApplication "$info_plist"

if [[ "$signing_identity" == "-" ]]; then
    codesign --force --deep --options runtime --sign - "$stage_app"
else
    codesign --force --deep --options runtime --timestamp --sign "$signing_identity" "$stage_app"
fi
codesign --verify --deep --strict --verbose=2 "$stage_app"

output_dir="$project_dir/dist"
output_app="$output_dir/$product_name.app"
mkdir -p "$output_dir"

if [[ -e "$output_app" ]]; then
    previous_dir="$output_dir/previous-builds"
    previous_name="$product_name-$(date +%Y%m%d-%H%M%S)-$$.app"
    mkdir -p "$previous_dir"
    mv "$output_app" "$previous_dir/$previous_name"
fi

mv "$stage_app" "$output_app"
rmdir "$stage_root"

print "$output_app"
