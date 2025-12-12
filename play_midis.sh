#!/bin/bash
shopt -s extglob
play_midis() (
    # --------------------- Per i colori --
    local esc="\033["

    local Green="${esc}32m"
    local Red="${esc}31m"
    local Gray="${esc}90m"
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
            --help|-h)
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
            --headless|-hl)
                local isHeadless="true"
                continue
            ;;
            --config|-c)
                local useConfig="true"
                continue
            ;;
            --show-warnings|-w)
                local showWarnings="true"
                continue
            ;;
            --gain|-g)
                local gainArg="true"
                continue
            ;;
            --sample-rate|-r)
                local sampleRateArg="true"
                continue
            ;;
            --interpolation|-i)
                local interpolationArg="true"
                continue
            ;;
            --loop|-l)
                local loopArg="true"
                continue
            ;;
            +([0-9]))
                # Checks for the number arguments
                [[ ! -z "$gainArg" ]] && {
                    unset gainArg
                    # bc for floating point numbers
                    # can't do without it
                    if [[ $(bc <<< "$arg >= 0 && $arg <= 10") == 1 ]] ;then
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
                # In case they're not set
                [[ -z "$gain" ]] && local gain=0.28

                [[ -z "$sampleRate" ]] &&
                [[ ! -z "$sampleRateArg" ]] && {
                    #
                    # Handy shortcuts
                    #
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
                # For when there's only --loop
                [[ -z "$loop" ]] && [[ ! -z "$loopArg" ]] &&
                    local loop="1"
                # Default for loops
                [[ -z "$loop" ]] && [[ -z "$loopArg" ]] &&
                    local loop="0"
            ;;
        esac
        # Checks the argument for the interpolation option
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
        elif [[ -d "$arg" ]] ;then
            # Checks if it even exists
            # and it's directory
            local location="$arg"
        elif [[ -f "$arg" ]] && [[ "$arg" =~ (.mid|.sf2)$ ]] ;then
            # User provided list
            local location="user provided files"
            local fileList+=("$arg")
        elif [[ -f "$arg" ]] && [[ "$arg" =~ (.cfg)$ ]] ;then
        #
        # —————— Start of .cfg file reader ——————
        #
            local allConfigFilePaths=() \
                    allConfigGains=() \
                    allConfigInterpolations=() \
                    allConfigSampleRates=() \
                    allConfigLoops=() \
                    allConfigLoopCuts=()
            local regexFilePath="(.*\.mid) (.*\.sf2)" \
                regexGains="^(gain|g) ([0-9,.]+)$" \
                regexSampleRates="^(sample-rate|r|sampleRate) ([0-9]+|max|lowest)$" \
                regexInterpolations="^(interpolation|i) ([0-9]+|none|linear|fourthorder|seventhorder)$" \
                regexLoops="^(loop|l) ([0-9]+)$" \
                regexLoopCuts="^(loop-cut|loopCut|lc) ([0-9]{2}:[0-9]{2}:[0-9]{2})$"
            echo -e "${Gray}Reading from file...$NORMAL"
            local oldWhileIndex=-2
            local whileIndex=-1
            while read line ;do
                # Sees the 2 files needed on the line
                [[ "$line" =~ $regexFilePath ]] && {
                    # Initially it waits.
                    # When a new couple of files appear,
                    # it starts looking for something that isn't set already
                    # and adds it by itself in case of it missing
                    [[ "$oldWhileIndex" != -2 ]] && {
                        [[ -z "${allConfigGains[$oldWhileIndex]}" ]] &&
                            allConfigGains+=(0.28)
                        [[ -z "${allConfigSampleRates[$oldWhileIndex]}" ]] &&
                            allConfigSampleRates+=(48000)
                        [[ -z "${allConfigInterpolations[$oldWhileIndex]}" ]] &&
                            allConfigInterpolations+=(4)
                        [[ -z "${allConfigLoops[$oldWhileIndex]}" ]] &&
                            allConfigLoops+=(0)
                        [[ -z "${allConfigLoopCuts[$oldWhileIndex]}" ]] &&
                            allConfigLoopCuts+=()
                    }
                    allConfigFilePaths+=("${BASH_REMATCH[1]} ${BASH_REMATCH[2]}")
                    let oldWhileIndex=$oldWhileIndex+1
                    let whileIndex=$whileIndex+1
                    continue
                }
                # Sees a setting for the gain
                [[ "$line" =~ $regexGains ]] && {
                    local configValue=${BASH_REMATCH[2]}
                    if [[ $(bc <<< "$configValue >= 0 && $configValue <= 10") == 1 ]] ;then
                        allConfigGains+=($configValue)
                        continue
                    else
                        echo -e "${Red}Can't use that kind of gain$NORMAL"
                        return 1
                    fi
                }
                # Sees it again for the sample rate
                [[ "$line" =~ $regexSampleRates ]] && {
                    local configValue=${BASH_REMATCH[2]}
                    if [[ "$arg" == "max" ]] ;then
                        allConfigSampleRates+=(96000)
                        continue
                    elif [[ "$arg" == "lowest" ]] ;then
                        allConfigSampleRates+=(8000)
                        continue
                    fi
                    if (( $configValue >= 8000 )) && (( $configValue <= 96000 )) ;then
                        allConfigSampleRates+=($configValue)
                        continue
                    else
                        echo -e "${Red}Can't use that kind of sample-rate$NORMAL"
                        return 1
                    fi
                }
                # Again for the interpolation
                [[ "$line" =~ $regexInterpolations ]] && {
                    local configValue=${BASH_REMATCH[2]}
                    shopt -s nocasematch
                    case "$configValue" in
                        none|0)
                            allConfigInterpolations+=(0)
                            continue
                        ;;
                        linear|1)
                            allConfigInterpolations+=(1)
                            continue
                        ;;
                        fourthorder|4)
                            allConfigInterpolations+=(4)
                            continue
                        ;;
                        seventhorder|7)
                            allConfigInterpolations+=(7)
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
                # For the song loops
                [[ "$line" =~ $regexLoops ]] && {
                    local configValue=(${BASH_REMATCH[2]})
                    allConfigLoops+=($configValue)
                }
                # For where to cut at the end of a song
                [[ "$line" =~ $regexLoopCuts ]] && {
                    local configValue=(${BASH_REMATCH[2]})
                    allConfigLoopCuts+=($configValue)
                }
            done < "$arg"
        #
        # —————— End of .cfg file reader ——————
        #
        else
            echo -e "${Yellow}Invalid argument '$arg' passed, quitting...${NORMAL}"
            return 2
        fi
    done

    addCommandToList() {
        local mix="'$midi' '$soundfont'"
        for (( i=0; i<=$loop; i++ )) ;do
            #
            # Using a cfg file
            #
            [[ "$useConfig" == "true" ]] && {
                #
                # au is the only format that works here
                #                             ↓
                list+="fluidsynth \
                           --sample-rate ${allConfigSampleRates[$indexOfConfigArray]} \
                           --quiet \
                           --audio-file-type au \
                           --fast-render - \
                           --gain ${allConfigGains[$indexOfConfigArray]} \
                           --load-config <(echo 'interp ${allConfigInterpolations[$indexOfConfigArray]}') \
                           $mix 2>/dev/null; "
                continue
            }
            list+="fluidsynth \
                       --sample-rate $sampleRate \
                       --quiet \
                       --audio-file-type au \
                       --fast-render - \
                       --gain $gain \
                       --load-config <(echo 'interp $interpolation') \
                       $mix 2>/dev/null; "
                  # ffmpeg \
                  #    -hide_banner \
                  #    -i - \
                  #    -c:a copy \
                  #    -to 00:01:10 \
                  #    -f matroska \
                  #    pipe:1 2>/dev/null
        done
    }
    local pathPattern="${location%/}"/@(*.mid|*.sf2)
    # User provided list of files
    [[ ! -z "$fileList" ]] && pathPattern=${fileList[@]}
    [[ "$useConfig" == "true" ]] && {
        # Loops the amount of songs and adds each file per song
        # to the main array, "allFiles" which then is set
        # to pathPattern for the next for loop below here
        for (( i=0; i<${#allConfigFilePaths[@]}; i++ )) ;do
            for s in ${allConfigFilePaths[$i]} ;do
                # Done like this because this way
                # it knows what index is in
                # (see below for the IFS)
                local allFiles+=("$s=$i")
            done
        done
        pathPattern=${allFiles[@]}
    }
    local midi=""
    local soundfont=""
    echo $pathPattern
    for f in $pathPattern ;do
        case "$f" in
            *.mid|*.mid=+([0-9]))
                midi="$f"
                [[ "$useConfig" == "true" ]] && {
                    # In case it's a cfg file:
                    #   it changes the delimiter to an =,
                    #   gets the file and its current index,
                    #   plus how many loops to do
                    #
                    #   then it restores the IFS
                    OLDIFS=$IFS
                    IFS="="
                    set $f
                    midi="$1"
                    indexOfConfigArray=$2
                    loop=${allConfigLoops[$2]}
                    IFS=$OLDIFS
                }
                [[ -z "$soundfont" ]] && continue
                addCommandToList
                unset midi
                unset soundfont
            ;;
            *.sf2|*.sf2=+([0-9]))
                soundfont="$f"
                [[ "$useConfig" == "true" ]] && {
                    # Same as before
                    OLDIFS=$IFS
                    IFS="="
                    set $f
                    soundfont="$1"
                    indexOfConfigArray=$2
                    loop=${allConfigLoops[$2]}
                    IFS=$OLDIFS
                }
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
    # The actual work is done here thanks to
    # - fluidsynth;
    # - mpv;
    # - ffmpeg;
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
