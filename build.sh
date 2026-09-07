#!/usr/bin/env bash
# Morphe patch builder: YT + YTM (stable listed / experimental newest base)
set -e
MPP_TAG="$1"; TARGET="${2:-auto}"
PKG_YT="com.google.android.youtube"; PKG_YTM="com.google.android.apps.youtube.music"
KS=keystore/Morphe.keystore
KS_ARGS=(--keystore "$KS" --keystore-entry-alias Morphe --keystore-entry-password 'Morphe!' --keystore-password 'Morphe!')

list_versions() {
  java -jar morphe-desktop.jar list-versions --patches patches.mpp -f "$1" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

# probe correct URL (YT: -all.apk; YTM: -arm64-v8a.apk), return first that gives HTTP 200
resolve_url() {
  local pkg="$1" base="$2"
  for suffix in "-all.apk" "-arm64-v8a.apk"; do
    local url="https://archive.org/download/jhc-apks/apks/$pkg/$pkg-$base$suffix"
    local code=$(curl -sIL --max-time 25 -o /dev/null -w '%{http_code}' "$url")
    if [ "$code" = "200" ]; then echo "$url"; return 0; fi
  done
  return 1
}

build_one() {
  local pkg="$1" base="$2" name="$3" suffix="$4"
  local url; url=$(resolve_url "$pkg" "$base") || { echo "NO URL for $pkg $base, skip"; return 1; }
  echo "downloading $url"
  curl -sL --retry 3 --max-time 600 -o base.apk "$url"
  local size=$(stat -c%s base.apk)
  [ "$size" -lt 10000000 ] && { echo "base too small ($size), abort"; return 1; }
  VER=$(./aapt2 dump badging base.apk 2>/dev/null | grep -oE "versionName='[^']+'" | head -1 | cut -d"'" -f2)
  echo "base versionName=$VER (wanted $base)"
  [ -z "$VER" ] && { echo "aapt2 failed on base.apk"; return 1; }
  local out="out/${name}-v${VER}-patches-${MPP_TAG}${suffix}.apk"
  java -Xms512m -Xmx3g -jar morphe-desktop.jar patch -p patches.mpp base.apk -o "$out" -d "Custom branding" "${KS_ARGS[@]}"
  ./aapt2 dump badging "$out" | grep -E '^package:|application-label:'
}

# newest base from jhc-apks listing (experimental) - any of the two namings
newest_base() {
  curl -s --max-time 30 "https://archive.org/download/jhc-apks/apks/$1/" | grep -oE "$1-[0-9]+\.[0-9]+\.[0-9]+(-arm64-v8a|-all)?\.apk" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -uV | tail -1
}

YT_LISTED=$(list_versions "$PKG_YT")
YTM_LISTED=$(list_versions "$PKG_YTM")
echo "listed: YT=$YT_LISTED YTM=$YTM_LISTED"

YT_NEWEST=$(newest_base "$PKG_YT")
YTM_NEWEST=$(newest_base "$PKG_YTM")
echo "newest: YT=$YT_NEWEST YTM=$YTM_NEWEST"

mkdir -p out
if [ "$TARGET" = "auto" ] || [ "$TARGET" = "yt" ]; then
  build_one "$PKG_YT" "$YT_LISTED" "YouTube" "" || echo "WARN: YT stable build failed"
  if [ -n "$YT_NEWEST" ] && [ "$YT_NEWEST" != "$YT_LISTED" ]; then
    build_one "$PKG_YT" "$YT_NEWEST" "YouTube" "-exp" || echo "WARN: YT exp build failed (ok)"
  fi
fi
if [ "$TARGET" = "auto" ] || [ "$TARGET" = "ytm" ]; then
  build_one "$PKG_YTM" "$YTM_LISTED" "YouTube_Music" "" || echo "WARN: YTM stable build failed"
  if [ -n "$YTM_NEWEST" ] && [ "$YTM_NEWEST" != "$YTM_LISTED" ]; then
    build_one "$PKG_YTM" "$YTM_NEWEST" "YouTube_Music" "-exp" || echo "WARN: YTM exp build failed (ok)"
  fi
fi
ls -lh out/
[ -n "$(ls -A out 2>/dev/null)" ] || { echo "FATAL: no APK built"; exit 1; }
