#!/bin/bash
#shellcheck disable=SC2004,SC2219
shopt -s extglob

generate_config() (
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
        if [[ "$arg" == @(--quiet|-q) ]] ;then
            local quiet="true"
            continue
        fi
        if [[ -d "$arg" ]] ;then
            local location="${arg%/}"
            continue
        else
            local location="."
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
    cd "$location" || exit 1
    local fileConfigName="config.cfg"
    [[ $(echo *.cfg | grep --quiet "config[0-9]*.cfg"; echo $?) == 0 ]] && {
        # In case there's already a config,
        # don't override it and create a new one
        possibleNumber=$(
            echo *.cfg \
            | sed 's/.*g\([0-9]*\).cfg/\1/g'
        )
        let possibleNumber+=1
        fileConfigName="${fileConfigName%.cfg}$possibleNumber.cfg"
    }
    for f in "${list[@]}" ;do
        case "$f" in
            *.mid)
                midi="$f"
                continue
            ;;
            *.sf2)
                [[ -z "$quiet" ]] && echo "Adding ${midi%.mid}"
                [[ "$firstTime" == "true" ]] && {
                    unset firstTime
                    {
                        echo "# Auto-generated file by generate_config_midis.sh"
                    } >> "$fileConfigName"
                }
                duration="$(get_duration_midis.sh -e -d "$midi" "$f")"
                {
                    echo "$midi $f"
                    echo "interpolation 4"
                    echo "sample-rate 48000"
                    echo "gain 30"
                    echo "loop 0"
                    echo "loop-cut-start 0"
                    echo "loop-cut-end $duration"
                    echo ""
                } >> "$fileConfigName"
                unset midi
            ;;
        esac
    done
)
generate_config "$@"
