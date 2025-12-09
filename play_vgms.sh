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
    run_audio() (
        eval "{ $1 } | \
            mpv \
                --msg-level=ffmpeg/view=no,ffmpeg/audio=no,ffmpeg/demuxer=no \
                --profile=\"vgm\" \
                --input-ipc-server=$TMPDIR/mpv.sock \
                --no-terminal - &"
        # msg-level=... to hide yellow msgs
    )

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
        if [[ "$arg" =~ ^(--help|-h) ]] ;then
            echo -e "Play VGMs options:\n" \
                "   --help, -h:\n" \
                "       Shows this page\n" \
                "   --headless, -hl:\n" \
                "       Runs this program in the background"
            return 0
        elif [[ "$arg" =~ ^(--headless|-hl) ]] ;then
            local isHeadless="true"
            continue
        fi

        # In case it's an archive
        if [[ $(7z l "$arg" &>/dev/null; echo $?) == 0 ]] ;then
            7z x "$1" -o"$TMPDIR/${arg/.*/}"
            local location="$TMPDIR/${arg/.*/}"
        elif [[ -d "$arg" ]] ;then # Checks if it even exists
            local location="$arg"
        else
            echo -e "\033[33mInvalid argument '$arg' passed, ignoring...\033[0m"
            continue 2
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
        run_audio "$list"
    else
        eval "{ $list } | \
            mpv \
                --msg-level=ffmpeg/view=no,ffmpeg/audio=no,ffmpeg/demuxer=no \
                --profile=\"vgm\" -"
        # msg-level=... to hide yellow msgs
    fi
)
play_vgmFormats $@
