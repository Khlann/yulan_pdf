-- Query Preview for the front document path and current page.
-- Run from Terminal (will prompt for Automation permission the first time):
--   osascript scripts/preview_front_document_info.applescript
--
-- Notes from plan validation (run locally on your Mac):
-- - Preview has NSAppleScriptEnabled = true (scriptable).
-- - If Terminal/Runner is not allowed to control Preview, the script blocks or fails until
--   you allow it in System Settings > Privacy & Security > Automation.
-- - "current page" exists in Preview's scripting dictionary on many macOS versions; if this
--   fails on your OS build, use preview_ax_dump (swift run preview_ax_dump) to hunt AX values.

tell application "Preview"
	if (count of documents) is 0 then
		return "no documents open"
	end if
	set docRef to front document
	set docPath to path of docRef
	try
		set pg to current page of docRef
		return docPath & linefeed & "current_page_index:" & pg
	on error errMsg number errNum
		return docPath & linefeed & "current_page:ERROR " & errNum & " " & errMsg
	end try
end tell
