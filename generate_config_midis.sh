#!/bin/bash
#shellcheck disable=SC2004,SC2219
shopt -s extglob
set -e

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
            echo -e "Generates a config file for midis:\n" \
                "   file.mid, file.sf2, an archive or folder:\n" \
                "       Necessary to get the durations\n" \
                "   --help, -h:\n" \
                "       Shows this help page\n"//
            return 0
        fi
        if [[ -d "$arg" ]] ;then
            local location="${1%/}"
            continue
        else
            local location="."
            continue
        fi
        if [[ -f "$arg" ]] &&
        [[ "$arg" =~ (.mid|.sf2)$ ]] ;then
            local listOfFiles+=("$arg")
            continue
        fi
    done
    local list=()
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
    local firstTime="true"
    for f in "${list[@]}" ;do
        case "$f" in
            *.mid)
                midi="$f"
                continue
            ;;
            *.sf2)
                [[ "$firstTime" == "true" ]] && {
                    unset firstTime
                    {
                        echo "# Auto-generated file by generate_config_midis.sh"
                    } >> "config.cfg"
                }
                {
                    echo "$midi $f"
                    echo "interpolation 4"
                    echo "sample-rate 48000"
                    echo "gain 70"
                    echo "loop 0"
                    echo "loop-cut-start 0"
                    echo "loop-cut-end"
                    echo ""
                } >> "config.cfg"
                unset midi
            ;;
        esac
    done
)
get_duration_midis "$@"
