-- export_pages_to_epub.applescript
-- Usage:
-- osascript export_pages_to_epub.applescript "/full/path/to/input.pages" "/full/path/to/output.epub"
	on run argv
    if (count of argv) < 2 then
        return "Usage: osascript export_pages_to_epub.applescript INPUT.pages OUTPUT.epub"
    end if

    set inputPath to item 1 of argv
    set outputPath to item 2 of argv

    tell application "Pages"
        open POSIX file inputPath
        delay 0.5
        try
            export front document to POSIX file outputPath as EPUB
        on error errMsg number errNum
            close front document saving no
            error errMsg number errNum
        end try
        close front document saving no
    end tell

    return "OK"
end run

