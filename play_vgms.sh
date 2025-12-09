#!/bin/bash
shopt -s extglob
play_vgmFormats() (
    run_audio() (
        eval "{ $1 } | \
            mpv \
                --msg-level=ffmpeg/view=no,ffmpeg/audio=no,ffmpeg/demuxer=no \
                --profile=\"big-cache,quality,fix-clicks\" \
                --input-ipc-server=$TMPDIR/mpv.sock \
                --no-terminal - &"
        # msg-level=... to hide yellow msgs
    )
    # Error if nothing has been given
    [[ -z $@ ]] && return 1
    [[ -z "$TMPDIR" ]] && {
        echo -e "\033[31m\$TMPDIR is missing\033[0m"
        return 1
    }

    # In case it's an archive
    if [[ $(7z l "$1" &>/dev/null; echo $?) == 0 ]] ;then
        7z x "$1" -o"$TMPDIR/${1/.*/}"
        local location="$TMPDIR/${1/.*/}"
    elif [[ $(7z l "$2" &>/dev/null; echo $?) == 0 ]] ;then
        7z x "$2" -o"$TMPDIR/${2/.*/}"
        local location="$TMPDIR/${2/.*/}"
    elif [[ -d "$1" ]] ;then # Checks if it even exists
        local location="$1"
    elif [[ -d "$2" ]] ;then
        local location="$2"
    else
        echo -e "\033[31mAn archive or folder is needed\033[0m"
        return 1
    fi

    for f in "${location%/}"/@(*.vgz|*.vgm|*.cmf|*.dro) ;do
        local list+="vgm2wav \"$f\" -; "
    done

    if [[ "$1" == "headless" ]] ;then
        run_audio "$list"
    elif [[ "$2" == "headless" ]] ;then
        run_audio "$list"
    else
        eval "{ $list } | \
            mpv \
                --msg-level=ffmpeg/view=no,ffmpeg/audio=no,ffmpeg/demuxer=no \
                --profile=\"big-cache,quality,fix-clicks\" -"
        # msg-level=... to hide yellow msgs
    fi
)
play_vgmFormats ${@}
