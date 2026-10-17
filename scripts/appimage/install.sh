#!/bin/sh
# Puts Scrapkeep in the app menu for the current user, or takes it out again.
#   Scrapkeep-<sha>-x86_64.AppImage --install     (AppRun runs this file from inside the image)
#   Scrapkeep-<sha>-x86_64.AppImage --uninstall
#   sh install.sh install <AppImage> <AppDir>      (what npm run sketch:appimage runs)
#   sh install.sh uninstall
# install copies the AppImage to $XDG_DATA_HOME/scrapkeep/Scrapkeep.AppImage (default
# ~/.local/share), the icon under icons/hicolor and the AppDir's scrapkeep.desktop, with Exec
# pointed at the copy, to applications/scrapkeep.desktop. uninstall removes those three files and
# nothing else: saves and settings under ~/.local/share/godot/app_userdata/core-loop stay.
set -eu

command=${1:-}
data=${XDG_DATA_HOME:-$HOME/.local/share}
app="$data/scrapkeep/Scrapkeep.AppImage"
icon="$data/icons/hicolor/scalable/apps/scrapkeep.svg"
desktop="$data/applications/scrapkeep.desktop"

refresh() {
	# Optional; launchers that watch the folder pick the entry up without them.
	update-desktop-database "$data/applications" >/dev/null 2>&1 || true
	gtk-update-icon-cache -q -t "$data/icons/hicolor" >/dev/null 2>&1 || true
}

# The desktop spec splits Exec on spaces, so a path with a space or quote is quoted.
exec_path() {
	case $1 in
	*[[:space:]\"\'\\\$\`]*) printf '"%s"' "$(printf '%s' "$1" | sed 's/[\\"$`]/\\&/g')" ;;
	*) printf '%s' "$1" ;;
	esac
}

case $command in
install)
	source=${2:-${APPIMAGE:-}}
	appdir=${3:-${APPDIR:-$(dirname "$0")/../..}}
	if [ -z "$source" ] || [ ! -f "$source" ]; then
		echo "scrapkeep install: no AppImage to install (got '${source}'); run it as Scrapkeep-<sha>-x86_64.AppImage --install" >&2
		exit 1
	fi
	if [ ! -f "$appdir/scrapkeep.desktop" ] || [ ! -f "$appdir/scrapkeep.svg" ]; then
		echo "scrapkeep install: no scrapkeep.desktop and scrapkeep.svg in $appdir" >&2
		exit 1
	fi
	mkdir -p "$(dirname "$app")" "$(dirname "$icon")" "$(dirname "$desktop")"
	if [ "$(readlink -f "$source")" != "$(readlink -f "$app" 2>/dev/null || true)" ]; then
		cp "$source" "$app.part"
		chmod 755 "$app.part"
		mv -f "$app.part" "$app"
	fi
	cp "$appdir/scrapkeep.svg" "$icon"
	exec_line="Exec=$(exec_path "$app")"
	# TryExec names the file without quotes; launchers hide the entry once the file is gone.
	awk -v exec_line="$exec_line" -v try_exec="TryExec=$app" '
		/^Exec=/ { print exec_line; print try_exec; next }
		/^TryExec=/ { next }
		{ print }
	' "$appdir/scrapkeep.desktop" >"$desktop.part"
	mv -f "$desktop.part" "$desktop"
	refresh
	echo "installed: $app"
	echo "app menu: $desktop"
	;;
uninstall)
	rm -f "$desktop" "$icon" "$app"
	rmdir "$(dirname "$app")" 2>/dev/null || true
	refresh
	echo "removed Scrapkeep from the app menu; saves and settings are kept"
	;;
*)
	echo "usage: install.sh install <AppImage> [AppDir] | install.sh uninstall" >&2
	exit 2
	;;
esac
