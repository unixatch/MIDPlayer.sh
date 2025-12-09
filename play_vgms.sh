#!/bin/bash
shopt -s extglob
play_vgmFormats() (
    # Error if nothing has been given
    [[ -z $@ ]] && {
        echo -e "\033[33mNo arguments passed, quitting...\033[0m"
        return 2
    }
    [[ -z "$TMPDIR" ]] && {
        echo -e "\033[31m\$TMPDIR is missing\033[0m"
        return 1
    }

    local count=0
    local warningPrinted="false"
    for arg in $@ ;do
        let count+=1
        if [[ $count > 2 ]] ;then # Ignores after 2nd argument
            [[ "$warningPrinted" == "false" ]] && {
                warningPrinted="true"
                echo -e "\033[33mOnly 2 arguments are used\033[0m"
            }
            continue
        fi
        case "$arg" in
            @(--help|-h))
                echo -e "Play VGMs options:\n" \
                    "   --help, -h:\n" \
                    "       Shows this page\n" \
                    "   --headless, -hl:\n" \
                    "       Runs this program in the background\n" \
                    "   --show-warnings, -w:\n" \
                    "       Shows ffmpeg warnings"
                return
            ;;
            @(--headless|-hl))
                local isHeadless="true"
                continue
            ;;
            @(--show-warnings|-w))
                local showWarnings="true"
                continue
            ;;
        esac

        # In case it's an archive
        if [[ $(7z l "$arg" &>/dev/null; echo $?) == 0 ]] ;then
            7z x "$1" -o"$TMPDIR/${arg/.*/}"
            local location="$TMPDIR/${arg/.*/}"
        elif [[ -d "$arg" ]] ;then # Checks if it even exists
            local location="$arg"
        else
            echo -e "\033[33mInvalid argument '$arg' passed, quitting...\033[0m"
            return 2
        fi
    done
    if [[ -z "$location" ]] ;then
        echo -e "\033[31mAn archive or folder is needed\033[0m"
        return 1
    fi

    pathPattern="${location%/}"/@(*.vgz|*.vgm|*.cmf|*.dro)
    for f in $pathPattern ;do
        if [[ "$f" == "$pathPattern" ]] ;then
            echo -e "\033[33mNo compatible file found, quitting...\033[0m"
            return 2
        fi
        local list+="vgm2wav \"$f\" -; "
    done

    if [[ "$isHeadless" == "true" ]] ;then
        if [[ "$showWarnings" == "true" ]] ;then
            eval "{ $list } | \
                mpv \
                    --profile=\"vgm\" \
                    --input-ipc-server=$TMPDIR/mpv.sock \
                    --no-terminal - &"
        else
            eval "{ $list } | \
                mpv \
                    --msg-level=ffmpeg/view=no,ffmpeg/audio=no,ffmpeg/demuxer=no \
                    --profile=\"vgm\" \
                    --input-ipc-server=$TMPDIR/mpv.sock \
                    --no-terminal - &"
            # msg-level=... to hide yellow msgs
        fi
    else
        if [[ "$showWarnings" == "true" ]] ;then
            eval "{ $list } | mpv --profile=\"vgm\" -"
        else
            eval "{ $list } | \
                mpv \
                    --msg-level=ffmpeg/view=no,ffmpeg/audio=no,ffmpeg/demuxer=no \
                    --profile=\"vgm\" -"
            # msg-level=... to hide yellow msgs
        fi
    fi
)
play_vgmFormats $@
