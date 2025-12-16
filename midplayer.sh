#!/bin/bash
#shellcheck disable=SC2004,SC2219
shopt -s extglob
play_midis() (
    # --------------------- Colors --
    local esc="\033["

    local Green="${esc}32m"
    local Red="${esc}31m"
    local Gray="${esc}90m"
    local Yellow="${esc}33m"
    local NORMAL="${esc}0m"
    # ------------------------------------
    # Error if nothing has been given
    [[ -z $* ]] && {
        echo -e "${Red}No arguments passed, quitting...${NORMAL}"
        return 2
    }
    [[ -z "$TMPDIR" ]] && {
        echo -e "${Yellow}\$TMPDIR is missing${NORMAL}"
        return 1
    }

    local ia=0
    for arg in "$@" ;do
        let ia+=1
        case "$arg" in
            --help|-h)
                echo -e "Play midis options:\n" \
                    "   file.mid, file.sf2, an archive or folder:\n" \
                    "       Required to run the script properly\n" \
                    "   --help, -h:\n" \
                    "       Shows this page\n" \
                    "   --headless, -hl:\n" \
                    "       Runs this program in the background\n" \
                    "   --show-warnings, -w:\n" \
                    "       Shows ffmpeg warnings\n"
                    "   --loop, -l\n" \
                    "       Loop each songs n amount of times\n" \
                    "   --profile, -p:\n" \
                    "       Add custom profiles to mpv\n" \
                    "   --index, -i:\n" \
                    "       Skip to index of playlist\n" \
                    "       (Negative index are allowed, e.g -1 means penultimate)\n" \
                    "   --gain, -g:\n" \
                    "       Adjust gain from 0 to 800\n" \
                    "   --sample-rate, -r:\n" \
                    "       Change sample rate\n" \
                    "           any number between:\n" \
                    "           • 4000, lowest\n" \
                    "           • 400000, max\n" \
                    "   --interpolation, -ip:\n" \
                    "       Change interpolation method\n" \
                    "           0, none\n" \
                    "           1, linear\n" \
                    "           2, cubicSpline\n" \
                    "           3, lagrange\n" \
                    "           4, newtonPolynomial\n" \
                    "           5, modifiedGauss\n"
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
            --interpolation|-ip)
                local interpolationArg="true"
                continue
            ;;
            --loop|-l)
                local loopArg="true"
                continue
            ;;
            --profile|-p)
                local profileArg="true"
                continue
            ;;
            --index|-i)
                local indexArg="true"
                continue
            ;;
            +([0-9.-]))
                # Checks for the number arguments
                [[ ! -z "$gainArg" ]] && {
                    unset gainArg
                    # bc for floating point numbers
                    # can't do without it
                    if [[ $(bc <<< "$arg >= 0 && $arg <= 800") == 1 ]] ;then
                        gain="$arg"
                    else
                        echo -e "${Red}Can't use that kind of gain$NORMAL"
                        return 1
                    fi
                    continue
                }
                [[ ! -z "$sampleRateArg" ]] && {
                    unset sampleRateArg
                    if (( $arg >= 4000 )) && (( $arg <= 400000 )) ;then
                        sampleRate="$arg"
                    else
                        echo -e "${Red}Can't use that kind of sample-rate$NORMAL"
                        return 1
                    fi
                    continue
                }
                [[ ! -z "$loopArg" ]] &&
                ! (( $arg < 0 )) && {
                    local loop="$arg"
                    unset loopArg
                    continue
                }
                [[ ! -z "$indexArg" ]] &&
                [[ -z "$index" ]] && {
                    local index=$arg
                    (( $arg < 0 )) && let index=$arg+1
                    (( $arg == 0 )) && local index="1"
                    continue
                }
            ;;
            *)
                [[ -z "$sampleRate" ]] &&
                [[ ! -z "$sampleRateArg" ]] && {
                    #
                    # Handy shortcuts
                    #
                    shopt -s nocasematch
                    if [[ "$arg" == "max" ]] ;then
                        unset sampleRateArg
                        sampleRate=400000
                        continue
                    elif [[ "$arg" == "lowest" ]] ;then
                        unset sampleRateArg
                        sampleRate=4000
                        continue
                    fi
                    shopt -u nocasematch
                }

                [[ ! -z "$profileArg" ]] && {
                    unset profileArg
                    local mpvProfiles="--profile=$arg"
                    continue
                }
                [[ ! -z "$sampleRateArg" ]] ||
                [[ ! -z "$gainArg" ]] && {
                    echo -e "${Red}Missing argument, quitting...$NORMAL"
                    return 1
                }
            ;;
        esac
        # In case they're not set
        [[ -z "$gain" ]] && local gain=30
        [[ -z "$sampleRate" ]] && local sampleRate=48000
        [[ -z "$interpolation" ]] && local interpolation=4
        # For when there's only --loop
        [[ -z "$loop" ]] && [[ ! -z "$loopArg" ]] &&
            local loop="1"
        # Default for loops
        [[ -z "$loop" ]] && [[ -z "$loopArg" ]] &&
            local loop="0"
        [[ -z "$index" ]] && local index=1

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
                cubicSpline|cubic-spline|2)
                    interpolation=2
                    unset interpolationArg
                    continue
                ;;
                lagrange|3)
                    interpolation=3
                    unset interpolationArg
                    continue
                ;;
                newtonPolynomial|newton-polynomial|4)
                    interpolation=4
                    unset interpolationArg
                    continue
                ;;
                modifiedGauss|modified-gauss|5)
                    interpolation=5
                    unset interpolationArg
                    continue
                ;;
                *)
                    echo -e "${Yellow}Only available: ${NORMAL}\n" \
                        " ${Green}none[${NORMAL}0${Green}]$NORMAL, \n  ${Green}linear[${NORMAL}1${Green}]$NORMAL, \n  ${Green}cubicSpline[${NORMAL}2${Green}]$NORMAL, \n  ${Green}lagrange[${NORMAL}3${Green}]$NORMAL, \n  ${Green}newtonPolynomial[${NORMAL}4${Green}]$NORMAL, \n  ${Green}modifiedGauss[${NORMAL}5${Green}]$NORMAL"
                    return 2
                ;;
            esac
            shopt -u nocasematch
        }

        # In case it's an archive
        if [[ -f "$arg" ]] &&
        [[ $(7z l "$arg" &>/dev/null; echo $?) == 0 ]] ;then
            7z x "$arg" -o"$TMPDIR/${arg/.*/}"
            local location="$TMPDIR/${arg/.*/}"
            continue
        elif [[ -d "$arg" ]] ;then
            # Checks if it even exists
            # and it's directory
            local location="$arg"
            continue
        elif [[ -f "$arg" ]] && [[ "$arg" =~ (.mid|.sf2)$ ]] ;then
            # User provided list
            local location="user provided files"
            let previousIa=$ia-1
            [[ "$arg" == *.sf2 ]] &&
            [[ "$(eval "echo \$$previousIa")" != *.mid ]] && {
                echo -e "${Red}A soundfont must be preceeded by a midi file$NORMAL"
                return 1
            }
            local usersFileList+=("$arg")
            continue
        elif [[ -f "$arg" ]] && [[ "$arg" =~ (.cfg)$ ]] ;then
        #
        # —————— Start of .cfg file reader ——————
        #
            local allConfigFilePaths=() \
                    allConfigGains=() \
                    allConfigInterpolations=() \
                    allConfigSampleRates=() \
                    allConfigLoops=() \
                    allConfigLoopCutsStart=() \
                    allConfigLoopCutsEnd=()
            local regexFilePath="(.*\.mid) (.*\.sf2)" \
                regexGains="^(gain|g) ([0-9,.]+)$" \
                regexSampleRates="^(sample-rate|r|sampleRate) ([0-9]+|max|lowest)$" \
                regexInterpolations="^(interpolation|i) ([0-9]+|none|linear|modifiedGauss|modified-gauss|newtonPolynomial|newton-polynomial|lagrange|cubicSpline|cubic-spline)$" \
                regexLoops="^(loop|l) ([0-9]+)$" \
                regexLoopCutsStart="^(loop-cut-start|loopCutStart|lcs) ([0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2}[0-9.]*|[0-9.]+)$"
            regexLoopCutsEnd="^(loop-cut-end|loopCutEnd|lce) ([0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2}[0-9.]*)(-{1}[0-9.]+)*$"
            echo -e "${Gray}Reading from file...$NORMAL"
            local oldWhileIndex=-2
            local whileIndex=-1
            local currentLine=0
            local totalLines
            totalLines="$(cat "$arg" | wc -l)"
            while read -r line ;do
                let currentLine+=1
                #  this is weird but it works ↓
                [[ "$line" == @( *|#*|$(echo -e "\n")) ]] && continue
                # Sees the 2 files needed on the line
                [[ "$line" =~ $regexFilePath ]] && {
                    # Initially it waits.
                    # When a new couple of files appear,
                    # it starts looking for something that isn't set already
                    # and adds it by itself in case of it missing
                    [[ "$oldWhileIndex" != -2 ]] && {
                        [[ -z "${allConfigGains[$whileIndex]}" ]] &&
                            allConfigGains+=(30)
                        [[ -z "${allConfigSampleRates[$whileIndex]}" ]] &&
                            allConfigSampleRates+=(48000)
                        [[ -z "${allConfigInterpolations[$whileIndex]}" ]] &&
                            allConfigInterpolations+=(4)
                        [[ -z "${allConfigLoops[$whileIndex]}" ]] &&
                            allConfigLoops+=(0)
                        [[ -z "${allConfigLoopCutsStart[$whileIndex]}" ]] &&
                            allConfigLoopCutsStart+=(0)
                        [[ -z "${allConfigLoopCutsEnd[$whileIndex]}" ]] &&
                            allConfigLoopCutsEnd+=("no")
                    }
                    let oldWhileIndex+=1
                    let whileIndex+=1
                    allConfigFilePaths+=("$whileIndex=${BASH_REMATCH[1]}=${BASH_REMATCH[2]}")
                    continue
                }
                # Sees a setting for the gain
                [[ "$line" =~ $regexGains ]] && {
                    local configValue=${BASH_REMATCH[2]}
                    if [[ $(bc <<< "$configValue >= 0 && $configValue <= 800") == 1 ]] ;then
                        allConfigGains+=("$configValue")
                        continue
                    else
                        echo -e "${Red}Can't use that kind of gain$NORMAL"
                        return 1
                    fi
                }
                # Sees it again for the sample rate
                [[ "$line" =~ $regexSampleRates ]] && {
                    local configValue=${BASH_REMATCH[2]}
                    #
                    # Handy shortcuts
                    if [[ "$arg" == "max" ]] ;then
                        allConfigSampleRates+=(400000)
                        continue
                    elif [[ "$arg" == "lowest" ]] ;then
                        allConfigSampleRates+=(4000)
                        continue
                    fi
                    if (( $configValue >= 4000 )) && (( $configValue <= 400000 )) ;then
                        allConfigSampleRates+=("$configValue")
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
                        cubicSpline|cubic-spline|2)
                            allConfigInterpolations+=(2)
                            continue
                        ;;
                        lagrange|3)
                            allConfigInterpolations+=(3)
                            continue
                        ;;
                        newtonPolynomial|newton-polynomial|4)
                            allConfigInterpolations+=(4)
                            continue
                        ;;
                        modifiedGauss|modified-gauss|5)
                            allConfigInterpolations+=(5)
                            continue
                        ;;
                        *)
                            echo -e "${Yellow}Only available: ${NORMAL}\n" \
                                " ${Green}none[${NORMAL}0${Green}]$NORMAL, \n  ${Green}linear[${NORMAL}1${Green}]$NORMAL, \n  ${Green}cubicSpline[${NORMAL}2${Green}]$NORMAL, \n  ${Green}lagrange[${NORMAL}3${Green}]$NORMAL, \n  ${Green}newtonPolynomial[${NORMAL}4${Green}]$NORMAL, \n  ${Green}modifiedGauss[${NORMAL}5${Green}]$NORMAL"
                            return 2
                        ;;
                    esac
                    shopt -u nocasematch
                }
                # For the song loops
                [[ "$line" =~ $regexLoops ]] && {
                    local configValue="${BASH_REMATCH[2]}"
                    allConfigLoops+=("$configValue")
                }
                # For where to cut at the end of a song
                [[ "$line" =~ $regexLoopCutsStart ]] && {
                    local configValue="${BASH_REMATCH[2]}"
                    allConfigLoopCutsStart+=("$configValue")
                }
                [[ "$line" =~ $regexLoopCutsEnd ]] && {
                    local configValue="${BASH_REMATCH[2]}"
                    local possibleConfigValue="${BASH_REMATCH[3]}"
                    [[ ! -z "$possibleConfigValue" ]] && {
                        [[ $(command -v qalc &>/dev/null; echo $?) != 0 ]] && {
                            echo -e "${Red}qalc needs to be installed for this calculation($configValue$possibleConfigValue)$NORMAL"
                            return 1
                        }
                        local durationInS
                        durationInS="$(qalc --terse "$configValue to s")"
                        local reducedDuration
                        reducedDuration="$(qalc --terse "$durationInS $possibleConfigValue s to time")"
                        configValue=$reducedDuration
                    }
                    allConfigLoopCutsEnd+=("$configValue")
                }
                # Checks if something's missing even
                # even before the file read ends
                [[ "$currentLine" == "$totalLines" ]] && {
                    [[ -z "${allConfigGains[$whileIndex]}" ]] &&
                        allConfigGains+=(30)
                    [[ -z "${allConfigSampleRates[$whileIndex]}" ]] &&
                        allConfigSampleRates+=(48000)
                    [[ -z "${allConfigInterpolations[$whileIndex]}" ]] &&
                        allConfigInterpolations+=(4)
                    [[ -z "${allConfigLoops[$whileIndex]}" ]] &&
                        allConfigLoops+=(0)
                    [[ -z "${allConfigLoopCutsStart[$whileIndex]}" ]] &&
                        allConfigLoopCutsStart+=(0)
                    [[ -z "${allConfigLoopCutsEnd[$whileIndex]}" ]] &&
                        allConfigLoopCutsEnd+=("no")
                }
            done < <(echo -e "$(cat "$arg")\n")
        #       ↑ Pevents missing line at EOF ↑
        #
        # —————— End of .cfg file reader ——————
        #
        else
            echo -e "${Yellow}Invalid argument '$arg' passed, quitting...${NORMAL}"
            return 2
        fi
    done

    addCommandToList() {
        local ffmpegCommandCopy=$ffmpegCommand
        for (( il=0; il<=$loop; il++ )) ;do
            #
            # Using a cfg file
            #
            [[ "$useConfig" == "true" ]] && {
                [[ "$il" == "0" ]] && {
                    ffmpegCommand=$(
                        # shellcheck disable=SC2001
                        echo "$ffmpegCommand" | sed 's/-ss [0-9:.]* //g'
                    )
                }
                [[ "$il" -gt 0 ]] && ffmpegCommand=$ffmpegCommandCopy
                [[ "$il" == "$loop" ]] && {
                    ffmpegCommand=$(
                        # shellcheck disable=SC2001
                        echo "$ffmpegCommand" | sed 's/-to [0-9:.]* //g'
                    )
                }
                #
                # wav is the only format that works here
                #                        ↓
                list+="timidity \
                           --sampling-freq ${allConfigSampleRates[$indexOfConfigArray]} \
                           --quiet \
                           --output-mode w \
                           --output-file - \
                           -A${allConfigGains[$indexOfConfigArray]} \
                           --config-string 'soundfont $soundfont' \
                           --resample ${allConfigInterpolations[$indexOfConfigArray]} \
                           --interpolation gauss \
                           $midi 2>/dev/null \
                       $ffmpegCommand; "
                continue
            }
            list+="timidity \
                       --sampling-freq $sampleRate \
                       --quiet \
                       --output-mode w \
                       --output-file - \
                       -A$gain \
                       --config-string 'soundfont $soundfont' \
                       --resample $interpolation \
                       --interpolation gauss \
                       $midi 2>/dev/null; "
        done
    }
    local listOfFiles=()
    local listOfFilesIndexes=()
    # Looks inside the provided folder/extracted archive directory for the files
    while read -r lineOfFind ;do
        [[ "$lineOfFind" == *.mid ]] && listOfFilesIndexes+=("$lineOfFind")
        listOfFiles+=("$lineOfFind")
    done < <(
        [[ -z "$usersFileList" ]] &&
        [[ -z "$useConfig" ]] &&
            find "$location" \
                -maxdepth 1 \
                -iname '*.mid' \
                -or \
                -iname '*.sf2'
    )
    # User provided files
    [[ ! -z "$usersFileList" ]] && {
        listOfFiles=("${usersFileList[@]}")
        for ii in "${listOfFiles[@]}" ;do
            [[ "$ii" == *.mid ]] && listOfFilesIndexes+=("$ii")
        done
    }
    # User provided list of files inside a cfg file
    [[ "$useConfig" == "true" ]] && {
        # Loops the amount of songs and adds each file per song
        # to the main array, "allFilesFromConfig" which then is set
        # to listOfFiles for the next for loop below here
        for s in "${allConfigFilePaths[@]}" ;do
            OLDIFS=$IFS
            IFS="="
            set $s
            # Done like this because this way
            # it knows what index is in
            # (see below for the IFS)
            local allFilesFromConfig+=("$1=$2")
            local allFilesFromConfig+=("$1=$3")
            listOfFilesIndexes+=("$2")
            IFS=$OLDIFS
        done
        listOfFiles=("${allFilesFromConfig[@]}")
    }
    local midi=""
    local soundfont=""
    local if=0
    for f in "${listOfFiles[@]}" ;do
        # Skips to index
        [[ ! -z "$indexArg" ]] && {
            local actualF=$f
            [[ ! -z "$useConfig" ]] && {
                local OLDIFS=$IFS
                IFS="="
                set $actualF
                actualF=$2
                IFS=$OLDIFS
            }
            if [[ "${listOfFilesIndexes[$index-1]}" == "$actualF" ]] ;then
                unset indexArg
            elif [[ "$skipSf2" == "$actualF" ]] ;then
                unset skipSf2
                let if+=1
                continue
            else
                let if+=1
                skipSf2="${listOfFiles[$if]}"
                continue
            fi
        }
        case "$f" in
            *.mid)
                midi="$f"
                [[ "$useConfig" == "true" ]] && {
                    # In case it's a cfg file:
                    #   it changes the delimiter to an =,
                    #   gets the file and its current index,
                    #   plus how many loops to do
                    #
                    #   then it restores the IFS
                    local OLDIFS=$IFS
                    IFS="="
                    set $f
                    midi="$2"
                    indexOfConfigArray=$1
                    loop=${allConfigLoops[$1]}
                    IFS=$OLDIFS
                }
                [[ -z "$soundfont" ]] && continue
                addCommandToList
                unset midi
                unset soundfont
            ;;
            *.sf2)
                soundfont="$f"
                [[ "$useConfig" == "true" ]] && {
                    # Same as before
                    local OLDIFS=$IFS
                    IFS="="
                    set $f
                    soundfont="$2"
                    indexOfConfigArray=$1
                    loop=${allConfigLoops[$1]}
                    local loopCutStart="${allConfigLoopCutsStart[$1]}"
                    local loopCutEnd="${allConfigLoopCutsEnd[$1]}"
                    IFS=$OLDIFS
                    ffmpegCommand="| \
                        ffmpeg \
                            -hide_banner \
                            -i - \
                            -ss $loopCutStart \
                            -c:a copy \
                            -to $loopCutEnd \
                            -f wav \
                            pipe:1 2>/dev/null"
                    [[ "$loopCutStart" == "0" ]] &&
                    [[ ! "$loopCutEnd" =~ $regexLoopCutsEnd ]] && {
                        unset ffmpegCommand
                    }
                }
                [[ -z "$midi" ]] && continue
                addCommandToList
                unset midi
                unset soundfont
            ;;
            *)
                echo -e "${Red}No compatible file found, quitting...${NORMAL}"
                return 2
            ;;
        esac
    done

    #echo $list; exit
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
                    $mpvProfiles \
                    --no-terminal - &"
        else
            eval "{ $list } | \
                mpv \
                    --msg-level=ffmpeg/view=no,ffmpeg/audio=no,ffmpeg/demuxer=no \
                    $mpvProfiles \
                    --input-ipc-server=$TMPDIR/mpv.sock \
                    --no-terminal - &"
            # msg-level=... to hide yellow msgs
        fi
    else
        if [[ "$showWarnings" == "true" ]] ;then
            eval "{ $list } | mpv $mpvProfiles -"
        else
            eval "{ $list } | \
                mpv \
                    --msg-level=ffmpeg/view=no,ffmpeg/audio=no,ffmpeg/demuxer=no \
                    $mpvProfiles -"
            # msg-level=... to hide yellow msgs
        fi
    fi
)
play_midis "$@"
