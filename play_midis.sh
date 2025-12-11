#!/bin/bash
shopt -s extglob
shopt -s nocaseglob
play_midis() (
    # --------------------- Per i colori --
    local esc="\033["

    local Green="${esc}32m"
    local Red="${esc}31m"
    local Yellow="${esc}33m"
    local NORMAL="${esc}0m"
    # ------------------------------------
    # Error if nothing has been given
    [[ -z $@ ]] && {
        echo -e "${Red}No arguments passed, quitting...${NORMAL}"
        return 2
    }
    [[ -z "$TMPDIR" ]] && {
        echo -e "${Yellow}\$TMPDIR is missing${NORMAL}"
        return 1
    }

    for arg in $@ ;do
        case "$arg" in
            @(--help|-h))
                echo -e "Play midis options:\n" \
                    "   file.mid, file.sf2 or folder:\n" \
                    "       Required to run the script properly\n" \
                    "   --help, -h:\n" \
                    "       Shows this page\n" \
                    "   --headless, -hl:\n" \
                    "       Runs this program in the background\n" \
                    "   --loop, -l\n" \
                    "       Loop each songs n amount of times\n" \
                    "   --gain, -g:\n" \
                    "       Adjust gain\n" \
                    "   --sample-rate, -r:\n" \
                    "       Change sample rate\n" \
                    "           any number between:\n" \
                    "           • 8000, lowest\n" \
                    "           • 96000, max\n" \
                    "   --interpolation, -i:\n" \
                    "       Change interpolation method\n" \
                    "           0, none\n" \
                    "           1, linear\n" \
                    "           4, fourthOrder\n" \
                    "           7, seventhOrder\n" \
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
            @(--gain|-g))
                local gainArg="true"
                continue
            ;;
            @(--sample-rate|-r))
                local sampleRateArg="true"
                continue
            ;;
            @(--interpolation|-i))
                local interpolationArg="true"
                continue
            ;;
            @(--loop|-l))
                local loopArg="true"
                continue
            ;;
            +([0-9]))
                [[ ! -z "$gainArg" ]] && {
                    unset gainArg
                    if (( $arg >= 0 )) && (( $arg <= 10 )) ;then
                        gain="$arg"
                    else
                        echo -e "${Red}Can't use that kind of gain$NORMAL"
                        return 1
                    fi
                    continue
                }
                [[ ! -z "$sampleRateArg" ]] && {
                    unset sampleRateArg
                    if (( $arg >= 8000 )) && (( $arg <= 96000 )) ;then
                        sampleRate="$arg"
                    else
                        echo -e "${Red}Can't use that kind of sample-rate$NORMAL"
                        return 1
                    fi
                    continue
                }
                [[ ! -z "$loopArg" ]] && {
                    let loop+="$arg"
                    unset loopArg
                    continue
                }
            ;;
            *)
                [[ -z "$gain" ]] && local gain=0.28

                [[ -z "$sampleRate" ]] &&
                [[ ! -z "$sampleRateArg" ]] && {
                    shopt -s nocasematch
                    if [[ "$arg" == "max" ]] ;then
                        unset sampleRateArg
                        sampleRate=96000
                        continue
                    elif [[ "$arg" == "lowest" ]] ;then
                        unset sampleRateArg
                        sampleRate=8000
                        continue
                    fi
                    shopt -u nocasematch
                }

                [[ ! -z "$sampleRateArg" ]] ||
                [[ ! -z "$gainArg" ]] && {
                    echo -e "${Red}Missing argument, quitting...$NORMAL"
                    return 1
                }
                [[ -z "$sampleRate" ]] && local sampleRate=48000
                [[ -z "$interpolation" ]] && local interpolation=4
                [[ -z "$loop" ]] && [[ ! -z "$loopArg" ]] &&
                    local loop="1"
                [[ -z "$loop" ]] && [[ -z "$loopArg" ]] &&
                    local loop="0"
            ;;
        esac
        [[ ! -z "$interpolationArg" ]] && {
            shopt -s nocasematch
            case "$arg" in
                none|0)
                    interpolation=0
                    unset interpolationArg
                    continue
                ;;
                linear|1)
                    interpolation=1
                    unset interpolationArg
                    continue
                ;;
                fourthorder|4)
                    interpolation=4
                    unset interpolationArg
                    continue
                ;;
                seventhorder|7)
                    interpolation=7
                    unset interpolationArg
                    continue
                ;;
                *)
                    echo -e "${Yellow}Only available: ${NORMAL}\n" \
                            "   ${Green}none[${NORMAL}0${Green}]$NORMAL, ${Green}linear[${NORMAL}1${Green}]$NORMAL, ${Green}fourthOrder[${NORMAL}4${Green}]$NORMAL, ${Green}seventhOrder[${NORMAL}7${Green}]$NORMAL"
                    return 2
                ;;
            esac
            shopt -u nocasematch
        }

        # In case it's an archive
        if [[ $(7z l "$arg" &>/dev/null; echo $?) == 0 ]] ;then
            7z x "$1" -o"$TMPDIR/${arg/.*/}"
            local location="$TMPDIR/${arg/.*/}"
        elif [[ -d "$arg" ]] ;then # Checks if it even exists
            local location="$arg"
        elif [[ -f "$arg" ]] && [[ "$arg" =~ (.mid|.sf2)$ ]] ;then
            local location="user provided files"
            local fileList+=("$arg")
        else
            echo -e "${Yellow}Invalid argument '$arg' passed, quitting...${NORMAL}"
            return 2
        fi
    done

    addCommandToList() {
        local mix="'$midi' '$soundfont'"
        for (( i=0; i<=$loop; i++ )) ;do
            list+="fluidsynth \
                       --sample-rate $sampleRate \
                       --quiet \
                       --audio-file-type au \
                       --fast-render - \
                       --gain $gain \
                       --load-config <(echo 'interp $interpolation') \
                       $mix 2>/dev/null; "
        done
    }
    local pathPattern="${location%/}"/@(*.mid|*.sf2)
    [[ ! -z "$fileList" ]] && pathPattern=${fileList[@]}
    local midi=""
    local soundfont=""
    for f in $pathPattern ;do
        case "$f" in
            *.mid)
                midi="$f"
                [[ -z "$soundfont" ]] && continue
                addCommandToList
                unset midi
                unset soundfont
            ;;
            *.sf2)
                soundfont="$f"
                [[ -z "$midi" ]] && continue
                addCommandToList
                unset midi
                unset soundfont
            ;;
            "$pathPattern")
                echo -e "${Red}No compatible file found, quitting...${NORMAL}"
                return 2
            ;;
        esac
    done

    echo $list; exit
    [[ -z "$list" ]] && {
        echo -e "${Yellow}Something is missing, forgot a soundfont/midi?${NORMAL}"
        return 1
    }
    if [[ "$isHeadless" == "true" ]] ;then
        if [[ "$showWarnings" == "true" ]] ;then
            eval "{ $list } | \
                mpv \
                    --input-ipc-server=$TMPDIR/mpv.sock \
                    --profile=fluidsynth \
                    --no-terminal - &"
        else
            eval "{ $list } | \
                mpv \
                    --msg-level=ffmpeg/view=no,ffmpeg/audio=no,ffmpeg/demuxer=no \
                    --profile=fluidsynth \
                    --input-ipc-server=$TMPDIR/mpv.sock \
                    --no-terminal - &"
            # msg-level=... to hide yellow msgs
        fi
    else
        if [[ "$showWarnings" == "true" ]] ;then
            eval "{ $list } | mpv --profile=fluidsynth -"
        else
            eval "{ $list } | \
                mpv \
                    --msg-level=ffmpeg/view=no,ffmpeg/audio=no,ffmpeg/demuxer=no \
                    --profile=fluidsynth -"
            # msg-level=... to hide yellow msgs
        fi
    fi
)
play_midis $@
