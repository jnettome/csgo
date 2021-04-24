#!/usr/bin/env bash

set -ueo pipefail

: "${CSGO_DIR:?'ERROR: CSGO_DIR IS NOT SET!'}"

export RETAKES="${RETAKES:-0}"

export HITBOX_PUG="${HITBOX_PUG:-0}"
export HITBOX_PRACTICE="${HITBOX_PRACTICE:-0}"
export HITBOX_SCRIM="${HITBOX_SCRIM:-0}"

if [ "$HITBOX_PUG" = "1" ]; then
  INSTALL_PLUGINS="https://github.com/splewis/csgo-pug-setup/releases/download/2.0.5/pugsetup_2.0.5.zip"
fi

if [ "$HITBOX_PRACTICE" = "1" ]; then
  INSTALL_PLUGINS="https://github.com/splewis/csgo-practice-mode/releases/download/1.3.3/practicemode_1.3.3.zip"
fi

if [ "$HITBOX_SCRIM" = "1" ]; then
  INSTALL_PLUGINS="https://github.com/splewis/get5/releases/download/0.7.1/get5_0.7.1.zip"
fi

get_checksum_from_string () {
  local md5
  md5=$(echo -n "$1" | md5sum | awk '{print $1}')
  echo "$md5"
}

is_plugin_installed() {
  local url_hash
  url_hash=$(get_checksum_from_string "$1")
  if [[ -f "$CSGO_DIR/csgo/${url_hash}.marker" ]]; then
    return 0
  else
    return 1
  fi
}

create_install_marker() {
  echo "$1" > "$CSGO_DIR/csgo/$(get_checksum_from_string "$1").marker"
}

install_plugin() {
  filename=${1##*/}
  filename_ext=$(echo "${1##*.}" | awk '{print tolower($0)}')
  if ! is_plugin_installed "$1"; then
    echo "Downloading $1..."
    case "$filename_ext" in
      "gz")
        curl -sSL "$1" | tar -zx -C "$CSGO_DIR/csgo"
        echo "Extracting $filename..."
        create_install_marker "$1"
        ;;
      "zip")
        curl -sSL -o "$filename" "$1"
        echo "Extracting $filename..."
        unzip -oq "$filename" -d "$CSGO_DIR/csgo"
        rm "$filename"
        create_install_marker "$1"
        ;;
      "smx")
        (cd "$CSGO_DIR/csgo/addons/sourcemod/plugins/" && curl -sSLO "$1")
        create_install_marker "$1"
        ;;
      *)
        echo "Plugin $filename has an unknown file extension, skipping"
        ;;
    esac
  else
    echo "Plugin $filename is already installed, skipping"
  fi
}

echo "Installing plugins..."

mkdir -p "$CSGO_DIR/csgo"

# instala nois
echo "Installing hitbox.zone base plugins (sourcemod, metamod and required ext)"
curl https://hitboxzone-public.s3-sa-east-1.amazonaws.com/hitbox-base-plugins.tar.gz --output hitbox-base-plugins.tar.gz
tar -zxvf hitbox-base-plugins.tar.gz -C "$CSGO_DIR/"

echo "Installing our management plugin"
curl https://hitboxzone-public.s3-sa-east-1.amazonaws.com/hitbox_stats.smx --output "$CSGO_DIR/csgo/addons/sourcemod/plugins/hitbox_stats.smx"

echo "Installing 3rd party plugins..."

IFS=' ' read -ra PLUGIN_URLS <<< "$(echo "$INSTALL_PLUGINS" | tr "\n" " ")"
for URL in "${PLUGIN_URLS[@]}"; do
  install_plugin "$URL"
done

echo "Finished installing plugins."

# Add steam ids to sourcemod admin file
mkdir -p "$CSGO_DIR/csgo/addons/sourcemod/configs"
IFS=',' read -ra STEAMIDS <<< "$SOURCEMOD_ADMINS"
for id in "${STEAMIDS[@]}"; do
    echo "\"$id\" \"99:z\"" >> "$CSGO_DIR/csgo/addons/sourcemod/configs/admins_simple.ini"
done

if [ "$HITBOX_PUG" = "1" ]; then
  echo "de_vertigo" >> "$CSGO_DIR/csgo/addons/sourcemod/configs/pugsetup/maps.txt"
  echo "de_cbble" >> "$CSGO_DIR/csgo/addons/sourcemod/configs/pugsetup/maps.txt"
  echo "de_cache" >> "$CSGO_DIR/csgo/addons/sourcemod/configs/pugsetup/maps.txt"
fi

echo "Done"
