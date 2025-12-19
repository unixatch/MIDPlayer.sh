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
            #                                       ↓ this is disgusting but it works ↓
            # Range from 0 to 800
            local regexGainRange="([0-9.]|[2-8.][0-9.]|1[0-9.]|9[0-9.]|[2-7.][0-9.][0-9.]|1[1-9.][0-9.]|10[0-9.]|80[0-0.])$"
            # Range from 4000 to 400000
            local regexSampleRateRange="([5-8.][0-9.][0-9.][0-9.]|4[1-9.][0-9.][0-9.]|40[1-9.][0-9.]|400[0-9.]|9[0-8.][0-9.][0-9.]|99[0-8.][0-9.]|999[0-9.]|[2-8.][0-9.][0-9.][0-9.][0-9.]|1[1-9.][0-9.][0-9.][0-9.]|10[1-9.][0-9.][0-9.]|100[1-9.][0-9.]|1000[0-9.]|9[0-8.][0-9.][0-9.][0-9.]|99[0-8.][0-9.][0-9.]|999[0-8.][0-9.]|9999[0-9.]|[2-3.][0-9.][0-9.][0-9.][0-9.][0-9.]|1[1-9.][0-9.][0-9.][0-9.][0-9.]|10[1-9.][0-9.][0-9.][0-9.]|100[1-9.][0-9.][0-9.]|1000[1-9.][0-9.]|10000[0-9.]|40000[0-0.])$"

            # All of these regexes check if there are 2 files
            # before the option being searched, don't select more than
            # $regexMaxLines and if the option isn't found,
            # select at the very least the 2 files before the option
            # so that the default values can be applied
            local regexMaxLines="8"
            local regexFilePath="(.*\.mid) (.*\.sf2)" \
                regexGains="^(.*.mid .*.sf2)(?:(?:.*\n){1,$regexMaxLines}(?:gain|g)( $regexGainRange)*)?" \
                regexSampleRates="^(.*.mid .*.sf2)(?:(?:.*\n){1,$regexMaxLines}(?:sample-rate|r|sampleRate)( $regexSampleRateRange| max| lowest)*)?" \
                regexInterpolations="^(.*.mid .*.sf2)(?:(?:.*\n){1,$regexMaxLines}(?:interpolation|i)( [0-5]| none| linear| modifiedGauss| modified-gauss| newtonPolynomial| newton-polynomial| lagrange| cubicSpline| cubic-spline)*)?" \
                regexLoops="^(.*.mid .*.sf2)(?:(?:.*\n){1,$regexMaxLines}(?:loop|l)( [0-9]+)*)?" \
                regexLoopCutsStart="^(.*.mid .*.sf2)(?:(?:.*\n){1,$regexMaxLines}(?:loop-cut-start|loopCutStart|lcs)( [0-9.]+)*)?"
            regexLoopCutsEnd="^(.*.mid .*.sf2)(?:(?:.*\n){1,$regexMaxLines}(?:loop-cut-end|loopCutEnd|lce)( [0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2}[0-9.]*)(-{1}[0-9.]+)*)?"

            echo -e "${Gray}Reading from file...$NORMAL"
            local fileConfig
            fileConfig="$(cat "$arg")"
            ased() (
                # Advanced sed
                "sed" \
                    --regexp-extended \
                    "$@"
            )
            local grepdFilePaths
            grepdFilePaths="$(
                echo "$fileConfig" \
                    | "grep" --perl-regexp "$regexFilePath" \
                    | awk '{
                        substitution=gensub( \
                            /(.*\.mid) (.*\.sf2)/,
                            "\\1=\\2",
                            "g",
                            $0 \
                        )
                        print NR-1"="substitution
                    }'
            )"
            grepdGains="$(
                # shellcheck disable=2030
                local defaultGain=30
                echo "$fileConfig" \
                    | pcre2grep \
                        --multiline \
                        --only-matching=1 \
                        --only-matching=2 \
                        "$regexGains" \
                    | ased \
                        --expression 's/.* ([0-9.]+)$/\1/' \
                        --expression t \
                        --expression "s/^.*\.mid .*\.sf2.*/$defaultGain/"
            )"
            grepdSampleRates="$(
                local defaultSampleRate=48000
                echo "$fileConfig" \
                    | pcre2grep \
                        --multiline \
                        --only-matching=1 \
                        --only-matching=2 \
                        "$regexSampleRates" \
                    | ased \
                        --expression 's/.* ([0-9.]+)$/\1/' \
                        --expression t \
                        --expression "s/^.*\.mid .*\.sf2.*/$defaultSampleRate/"
            )"
            grepdInterpolations="$(
                local defaultInterpolation=4
                echo "$fileConfig" \
                    | pcre2grep \
                        --multiline \
                        --only-matching=1 \
                        --only-matching=2 \
                        "$regexInterpolations" \
                    | ased \
                        --expression 's/.* ([0-5])/\1/' \
                            --expression t \
                        --expression 's/.* none$/0/' \
                            --expression t \
                        --expression 's/.* linear$/1/' \
                            --expression t \
                        --expression 's/.* (cubicSpline|cubic-spline)$/2/' \
                            --expression t \
                        --expression 's/.* lagrange$/3/' \
                            --expression t \
                        --expression 's/.* (newtonPolynomial|newton-polynomial)$/4/' \
                            --expression t \
                        --expression 's/.* (modifiedGauss|modified-gauss)$/5/' \
                            --expression t \
                        --expression "s/^.*\.mid .*\.sf2.*/$defaultInterpolation/" \
            )"
            grepdLoops="$(
                local defaultLoop=0
                echo "$fileConfig" \
                    | pcre2grep \
                        --multiline \
                        --only-matching=1 \
                        --only-matching=2 \
                        "$regexLoops" \
                    | ased \
                        --expression 's/.* ([0-9]+)$/\1/' \
                        --expression t \
                        --expression "s/^.*\.mid .*\.sf2.*/$defaultLoop/"
            )"
            grepdLoopCutStarts="$(
                local defaultLoopCutStart=0
                echo "$fileConfig" \
                    | pcre2grep \
                        --multiline \
                        --only-matching=1 \
                        --only-matching=2 \
                        "$regexLoopCutsStart" \
                    | ased \
                        --expression 's/.* ([0-9.]+)$/\1/' \
                        --expression t \
                        --expression "s/^.*\.mid .*\.sf2.*/$defaultLoopCutStart/"
            )"
            grepdLoopCutEnds="$(
                echo "$fileConfig" \
                    | pcre2grep \
                        --multiline \
                        --only-matching=2 \
                        --only-matching=3 \
                        "$regexLoopCutsEnd" \
                    | ased \
                        --expression 's/.* ([0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2}[0-9.]*)(-{1}[0-9.]+)*$/\1\2/' \
                    | awk '{
                        group1 = gensub(\
                            /([0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2}[0-9.]*)(-{1}[0-9.]+)*/,
                            "\\1",
                            "g",
                            $0 \
                        )
                        group2 = gensub( \
                            /([0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2}[0-9.]*)(-{1}([0-9.]+))*/,
                            "\\3",
                            "g",
                            $0 \
                        )
                        if (group2 != "") {
                            split(group1, time, ":");
                            totalSeconds = \
                                (time[1] * 3600) + \
                                (time[2] * 60) + \
                                time[3]
                            difference = (totalSeconds - group2)

                            hours = int(difference / 3600);
                            minutes = int(difference / 60);
                            remaining_seconds = \
                                difference - (hours * 3600 + minutes * 60)

                            formatted_seconds = sprintf(\
                                "%.6f",
                                remaining_seconds \
                            )
                            # Print in hh:mm:ss.ms format
                            print \
                                hours ":" \
                                (minutes < 10 ? "0" : "") \
                                minutes ":" \
                                (int(formatted_seconds) < 10 ? "0" : "") \
                                formatted_seconds;
                        } else {
                            print group1
                        }
                    }'
            )"
            mapfile -t allConfigFilePaths <<< "$grepdFilePaths"
            mapfile -t allConfigGains <<< "$grepdGains"
            mapfile -t allConfigSampleRates <<< "$grepdSampleRates"
            mapfile -t allConfigInterpolations <<< "$grepdInterpolations"
            mapfile -t allConfigLoops <<< "$grepdLoops"
            mapfile -t allConfigLoopCutsStart <<< "$grepdLoopCutStarts"
            mapfile -t allConfigLoopCutsEnd <<< "$grepdLoopCutEnds"
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
                    ffmpegCommand="${ffmpegCommand/-ss [0-9:.]* -c/-c}"
                }
                [[ "$il" -gt 0 ]] && ffmpegCommand=$ffmpegCommandCopy
                [[ "$il" == "$loop" ]] && {
                    ffmpegCommand="${ffmpegCommand/-to [0-9:.]* -f/-f}"
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
                           --config-string \"soundfont '$soundfont'\" \
                           --resample ${allConfigInterpolations[$indexOfConfigArray]} \
                           --interpolation gauss \
                           '$midi' 2>/dev/null \
                       $ffmpegCommand || exit 4; "
                continue
            }
            # shellcheck disable=2089
            list+="timidity \
                       --sampling-freq $sampleRate \
                       --quiet \
                       --output-mode w \
                       --output-file - \
                       -A$gain \
                       --config-string \"soundfont '$soundfont'\" \
                       --resample $interpolation \
                       --interpolation gauss \
                       '$midi' 2>/dev/null || exit 4; "
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
    [[ ! -z "$useConfig" ]] && {
        listOfFiles+=("${allConfigFilePaths[@]}")
        mapfile -t listOfFilesIndexes < <(
            echo "${allConfigFilePaths[@]}" \
                | sed -E 's/sf2 /sf2\\\n/g' \
                | awk -F "=" '{print $2}' \
                | sed -E 's/sf2\n/sf2 /g'
        )
    }
    local midi=""
    local soundfont=""
    local finalRegexLoopCutEnd="[0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2}[0-9.]*(-{1}[0-9.]+)*"
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
        [[ "$useConfig" == "true" ]] && {
            # In case it's a cfg file:
            #   it changes the delimiter to an =,
            #   gets the files and its current index,
            #   plus how many loops to do
            #
            #   then it restores the IFS
            local OLDIFS=$IFS
            IFS="="
            set $f
            midi="$2"
            soundfont="$3"
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
            [[ ! "$loopCutEnd" =~ $finalRegexLoopCutEnd ]] && {
                unset ffmpegCommand
            }
            addCommandToList
            unset midi
            unset soundfont
            continue
        }
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
            *)
                echo -e "${Red}No compatible file found, quitting...${NORMAL}"
                return 2
            ;;
        esac
    done

    #echo $list
    #exit
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
