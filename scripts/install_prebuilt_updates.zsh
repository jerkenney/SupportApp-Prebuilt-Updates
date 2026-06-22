#!/bin/zsh --no-rcs

# Install script - Addigy Prebuilt App Updates extension for the Root3 Support App
#
# Deploys two things and starts them:
#   1. /Library/Management/Scripts/prebuilt_updates.zsh
#        - the worker: reads Addigy's local prebuilt-app state and updates the
#          Support App "App Updates" extension + menu bar badge.
#   2. /Library/LaunchDaemons/${daemon_label}.plist
#        - runs the worker as root on load, whenever Addigy refreshes its
#          prebuilt-app state (WatchPaths), and every 30 min as a safety net,
#          so the badge is PROACTIVE (no need to open the app first).
#
# Run as root. In Addigy, paste this into a Script (or a Smart Software install
# script) scoped to the devices that run the Support App.
#
# CUSTOMIZE: set daemon_label to your org's reverse-DNS.

install_dir="/Library/Management/Scripts"
script_path="${install_dir}/prebuilt_updates.zsh"
daemon_label="com.example.prebuilt-updates"
daemon_plist="/Library/LaunchDaemons/${daemon_label}.plist"
log_path="/var/log/prebuilt_updates.log"

mkdir -p "${install_dir}"

# --- 1. worker script -------------------------------------------------------
cat > "${script_path}" <<'SUPPORT_EXTENSION_EOF'
#!/bin/zsh --no-rcs

# Support App Extension - Addigy Prebuilt App Updates
# Reads Addigy's local prebuilt-app state (no API key needed) and updates the
# Support App "App Updates" extension + menu bar badge. Runs as OnAppearAction
# (on open) and from the LaunchDaemon (proactive).

extension_id="prebuilt_updates"
preference_file="/Library/Preferences/nl.root3.support.plist"
db="/Library/Addigy/ansible/prebuilt-apps/state.db"

query() {
  sqlite3 -readonly "${db}" ".timeout 2000" "$1" 2>/dev/null
}

if [[ ! -f "${db}" ]]; then
  defaults write "${preference_file}" "${extension_id}" -string "Not available"
  defaults write "${preference_file}" "${extension_id}_alert" -bool false
  defaults delete "${preference_file}" "${extension_id}_action" 2>/dev/null
  defaults delete "${preference_file}" "${extension_id}_action_type" 2>/dev/null
  exit 0
fi

count=$(query "SELECT COUNT(*) FROM prebuilt_apps WHERE status='pending';")
[[ -z "${count}" ]] && count=0

if (( count == 0 )); then
  status_text="✅ Up to date"
elif (( count == 1 )); then
  status_text="🟠 1 update available"
else
  status_text="🟠 ${count} updates available"
fi

defaults write "${preference_file}" "${extension_id}" -string "${status_text}"

if (( count > 0 )); then
  defaults write "${preference_file}" "${extension_id}_action" -string "com.addigy.MacManage"
  defaults write "${preference_file}" "${extension_id}_action_type" -string "App"
  defaults write "${preference_file}" "${extension_id}_alert" -bool true
else
  defaults delete "${preference_file}" "${extension_id}_action" 2>/dev/null
  defaults delete "${preference_file}" "${extension_id}_action_type" 2>/dev/null
  defaults write "${preference_file}" "${extension_id}_alert" -bool false
fi

exit 0
SUPPORT_EXTENSION_EOF

# Root3 Support App requires scripts it runs to be owned root:wheel, mode 755.
chown root:wheel "${script_path}"
chmod 755 "${script_path}"

# --- 2. LaunchDaemon --------------------------------------------------------
cat > "${daemon_plist}" <<DAEMON_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>${daemon_label}</string>
	<key>ProgramArguments</key>
	<array>
		<string>${script_path}</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StartInterval</key>
	<integer>1800</integer>
	<key>WatchPaths</key>
	<array>
		<string>/Library/Addigy/ansible/prebuilt-apps/state.updated</string>
		<string>/Library/Addigy/ansible/prebuilt-apps/state.db</string>
	</array>
	<key>StandardErrorPath</key>
	<string>${log_path}</string>
	<key>StandardOutPath</key>
	<string>${log_path}</string>
</dict>
</plist>
DAEMON_EOF

chown root:wheel "${daemon_plist}"
chmod 644 "${daemon_plist}"

# (Re)load the daemon. bootout first so re-running the installer picks up changes.
launchctl bootout system "${daemon_plist}" 2>/dev/null
launchctl bootstrap system "${daemon_plist}"
launchctl enable "system/${daemon_label}"

# Populate the count immediately (RunAtLoad also does this; be explicit).
"${script_path}"

echo "Installed worker + LaunchDaemon (${daemon_label}); initial count populated."
