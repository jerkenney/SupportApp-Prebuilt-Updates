#!/bin/zsh --no-rcs

# Support App Extension - Addigy Prebuilt App Updates
#
# Updates a "prebuilt_updates" extension in the Root3 Support App with the
# number of Addigy Prebuilt Apps that have an update pending. Designed to run
# both as the extension's OnAppearAction (instant refresh on open) and from a
# LaunchDaemon (proactive refresh + menu bar badge).
#
# Data source (read-only): the local Addigy agent's prebuilt-app state DB.
# This is the same source MacManage reads for its menu bar update count, so no
# Addigy API call or API key is required. The agent refreshes it on each policy
# run (~every 30 minutes).
#
#   /Library/Addigy/ansible/prebuilt-apps/state.db  ->  table: prebuilt_apps
#     status = 'installed'  -> app is current
#     status = 'pending'    -> update available / not yet applied
#
# When updates are pending the item becomes clickable and opens MacManage so
# the user can apply them.

extension_id="prebuilt_updates"
preference_file="/Library/Preferences/nl.root3.support.plist"
db="/Library/Addigy/ansible/prebuilt-apps/state.db"

# Open the DB read-only with a short busy timeout so we never block, or get
# blocked by, the agent that writes to this file on every policy run.
query() {
  sqlite3 -readonly "${db}" ".timeout 2000" "$1" 2>/dev/null
}

if [[ ! -f "${db}" ]]; then
  # No prebuilt-apps state on this Mac (feature not deployed) - show nothing
  # alarming, clear the badge, and make sure the item isn't clickable.
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

# Make the item open MacManage to apply updates only when there is something to
# do; otherwise clear the action so it stays display-only.
if (( count > 0 )); then
  defaults write "${preference_file}" "${extension_id}_action" -string "com.addigy.MacManage"
  defaults write "${preference_file}" "${extension_id}_action_type" -string "App"
  # Raise the menu bar notification badge (orange dot). NOTE: red is reserved by
  # the Support App for pending macOS updates and cannot be set per-extension.
  defaults write "${preference_file}" "${extension_id}_alert" -bool true
else
  defaults delete "${preference_file}" "${extension_id}_action" 2>/dev/null
  defaults delete "${preference_file}" "${extension_id}_action_type" 2>/dev/null
  defaults write "${preference_file}" "${extension_id}_alert" -bool false
fi

exit 0
