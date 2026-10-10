#!/usr/bin/env bash
# Sourced via BASH_ENV from the Steam desktop shortcut. Bash reads it before
# every script in that launch, so this returns unless the script is the
# CEF helper. Steam has no -cef-force-wayland switch; the helper forces
# --device-scale-factor=1, and Hyprland then scales that X11 window and
# cursor up on DP-1 (1.5). Drop those flags and use Wayland instead.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    echo "steam-webhelper-args.sh is sourced via BASH_ENV for steamwebhelper" >&2
    exit 1
fi

case "$0" in
    *steamwebhelper.sh|*steamwebhelper_sniper_wrap.sh) ;;
    *) return 0 ;;
esac

if [ "${STEAM_NO_WAYLAND:-}" = 1 ]; then
    return 0
fi

_steam_wl_args=()
_steam_wl_skip=
_steam_wl_features=
_steam_wl_ozone=

for _steam_wl_arg in "$@"; do
    if [ -n "${_steam_wl_skip}" ]; then
        _steam_wl_skip=
        continue
    fi
    case "${_steam_wl_arg}" in
        --disablehighdpi|--disable-highdpi)
            continue
            ;;
        --force-device-scale-factor|--device-scale-factor)
            _steam_wl_skip=1
            continue
            ;;
        --force-device-scale-factor=*|--device-scale-factor=*)
            continue
            ;;
        --enable-features=*)
            _steam_wl_features=1
            case "${_steam_wl_arg}" in
                *WaylandFractionalScaleV1*) ;;
                *) _steam_wl_arg="${_steam_wl_arg},WaylandFractionalScaleV1" ;;
            esac
            ;;
        --ozone-platform=wayland)
            _steam_wl_ozone=1
            ;;
        --ozone-platform=*)
            _steam_wl_arg="--ozone-platform=wayland"
            _steam_wl_ozone=1
            ;;
    esac
    _steam_wl_args+=("${_steam_wl_arg}")
done

if [ -z "${_steam_wl_features}" ]; then
    _steam_wl_args+=("--enable-features=WaylandFractionalScaleV1")
fi
if [ -z "${_steam_wl_ozone}" ]; then
    _steam_wl_args+=("--ozone-platform=wayland")
fi

set -- "${_steam_wl_args[@]}"
unset _steam_wl_args _steam_wl_skip _steam_wl_features _steam_wl_ozone _steam_wl_arg
