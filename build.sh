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

build_one() {
  local pkg="$1" base="$2" name="$3" suffix="$4"
  local url="https://archive.org/download/jhc-apks/apks/$pkg/$pkg-$base-arm64-v8a.apk"
  # YT uses -all.apk naming on jhc-apks
  curl -sIL --max-time 20 "$url" -o /dev/null || url="https://archive.org/download/jhc-apks/apks/$pkg/$pkg-$base-all.apk"
  curl -sL --retry 3 -o base.apk "$url"
  # verify base version
  VER=$(./aapt2 dump badging base.apk 2>/dev/null | grep -oE "versionName='[^']+'" | head -1 | cut -d"'" -f2)
  echo "base versionName=$VER (wanted $base)"
  local out="out/${name}-v${VER}-patches-${MPP_TAG}${suffix}.apk"
  java -Xms512m -Xmx3g -jar morphe-desktop.jar patch -p patches.mpp base.apk -o "$out" -d "Custom branding" "${KS_ARGS[@]}"
  ./aapt2 dump badging "$out" | grep -E '^package:|application-label:' 
}

# detect versions
YT_LISTED=$(list_versions "$PKG_YT")
YTM_LISTED=$(list_versions "$PKG_YTM")
echo "listed: YT=$YT_LISTED YTM=$YTM_LISTED"

# newest base from jhc-apks listing (experimental) - parse archive.org dir index
newest_base() {
  curl -s --max-time 30 "https://archive.org/download/jhc-apks/apks/$1/" | grep -oE "$1-[0-9]+\.[0-9]+\.[0-9]+-arm64-v8a\.apk" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -uV | tail -1
}

YT_NEWEST=$(newest_base "$PKG_YT")
YTM_NEWEST=$(newest_base "$PKG_YTM")
echo "newest: YT=$YT_NEWEST YTM=$YTM_NEWEST"

mkdir -p out
if [ "$TARGET" = "auto" ] || [ "$TARGET" = "yt" ]; then
  build_one "$PKG_YT" "$YT_LISTED" "YouTube" "" 
  if [ "$YT_NEWEST" != "$YT_LISTED" ]; then
    build_one "$PKG_YT" "$YT_NEWEST" "YouTube" "-exp" || echo "YT exp build failed (ok)"
  fi
fi
if [ "$TARGET" = "auto" ] || [ "$TARGET" = "ytm" ]; then
  build_one "$PKG_YTM" "$YTM_LISTED" "YouTube_Music" ""
  if [ "$YTM_NEWEST" != "$YTM_LISTED" ]; then
    build_one "$PKG_YTM" "$YTM_NEWEST" "YouTube_Music" "-exp" || echo "YTM exp build failed (ok)"
  fi
fi
ls -lh out/
