#!/bin/bash
#shellcheck disable=SC2004,SC2219
shopt -s extglob

get_duration_midis() (
    # Error if nothing has been given
    [[ -z $* ]] && {
        echo -e "\033[31mNo arguments passed, quitting...\033[0m"
        return 2
    }
    [[ -z "$TMPDIR" ]] && {
        echo -e "\033[33m\$TMPDIR is missing\033[0m"
        return 1
    }
    for arg in "$@" ;do
        if [[ "$arg" == @(--help|-h) ]] ;then
            echo -e "Shows duration of provided midis:\n" \
                "   file.mid, file.sf2, an archive or folder:\n" \
                "       Necessary to get the durations\n" \
                "   --help, -h:\n" \
                "       Shows this help page\n" \
                "   --essentials, -e:\n" \
                "       Shows only the name and the duration\n"
            return 0
        fi
        if [[ "$arg" == @(--essentials|-e) ]] ;then
            local onlyEssentials="true"
            continue
        fi
        if [[ "$arg" == @(--only-duration|-d) ]] ;then
            local onlyDuration="true"
            continue
        fi
        if [[ -f "$arg" ]] &&
        [[ $(7z l "$arg" &>/dev/null; echo $?) == 0 ]] ;then
            7z x "$arg" -o"$TMPDIR/${arg/.*/}"
            local location="$TMPDIR/${arg/.*/}"
            continue
        fi
        if [[ -d "$arg" ]] ;then
            local location="${arg%/}"
            continue
        fi
        if [[ -f "$arg" ]] &&
        [[ "$arg" =~ (.mid|.sf2)$ ]] ;then
            local listOfFiles+=("$arg")
            continue
        fi
    done
    [[ "$location" == "" ]] &&
    [[ -z "$listOfFiles" ]] && {
        echo -e "\033[31;1mA file or folder is required\033[0m"
        return 1
    }
    local list=()
    [[ -z "$onlyEssentials" ]] && echo "$location"/:
    while read -r lineOfFind ;do
        list+=("$lineOfFind")
    done < <(
        [[ -z "$listOfFiles" ]] &&
            find "$location" \
                -maxdepth 1 \
                -iname '*.mid' \
                -or \
                -iname '*.sf2'
    )
    [[ ! -z "$listOfFiles" ]] && list=("${listOfFiles[@]}")
    local midi=""
    for f in "${list[@]}" ;do
        case "$f" in
            *.mid)
                midi="$f"
                continue
            ;;
            *.sf2)
                # Gets the duration by running through the entire song
                # and then prints out name and duration in sexagesimal
                local duration
                duration=$(
                    timidity \
                        -x "soundfont '$f'" \
                        --output-file - \
                        --output-mode w \
                        "$midi" 2>/dev/null \
                    | ffprobe \
                        -show_frames \
                        -show_entries "frame=pts_time" \
                        -print_format "compact=nk=1:p=0" \
                        -sexagesimal \
                        - 2>/dev/null \
                    | tail --lines 1
                )
                local durationInS+=("$(qalc --terse "$duration to seconds") +")
                if [[ -z "$onlyEssentials" ]] ;then
                    echo "  $(basename "${midi%.mid}") —→ $duration"
                elif [[ ! -z "$onlyDuration" ]] &&
                     [[ ! -z "$onlyEssentials" ]] ;then
                    echo "$duration"
                else
                    echo "$(basename "${midi%.mid}") $duration"
                fi
                unset midi
            ;;
        esac
    done
    [[ -z "$onlyEssentials" ]] && {
        echo "Total duration:"
        echo "  $(qalc --terse "${durationInS[@]}")"
    }
)
get_duration_midis "$@"
