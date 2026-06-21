on run argv
    set wantsUniversal to false
    set buildRootArg to ""

    repeat with arg in argv
        set argText to arg as text
        if argText is "--universal" then
            set wantsUniversal to true
        else if argText starts with "--build-root=" then
            set sepIndex to (offset of "=" in argText)
            if sepIndex > 0 then
                set buildRootArg to text (sepIndex + 1) thru (length of argText) of argText
            end if
        end if
    end repeat

    if buildRootArg is "" then
        set buildRoot to missing value
    else
        set buildRoot to buildRootArg
    end if

    set launcherAppPath to POSIX path of (path to me)
    set launcherDir to do shell script "dirname " & quoted form of launcherAppPath
    set repoRoot to do shell script "dirname " & quoted form of launcherDir

    set buildScript to repoRoot & "/macosx/MACKAN/scripts/build-dev-app.sh"
    set buildCmd to "cd " & quoted form of repoRoot & " &&"
    if buildRoot is not missing value then
        set buildCmd to buildCmd & " BUILD_ROOT=" & quoted form of buildRoot & " "
    end if
    set buildCmd to buildCmd & quoted form of buildScript
    if wantsUniversal then
        set buildCmd to buildCmd & " --universal"
    end if

    set appPath to do shell script buildCmd
    do shell script "open " & quoted form of appPath
end run
