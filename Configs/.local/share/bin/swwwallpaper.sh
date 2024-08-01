#!/usr/bin/env sh


#// lock instance
lockFile="/tmp/hyde$(id -u)$(basename ${0}).lock"
[ -e "${lockFile}" ] && echo "An instance of the script is already running..." && exit 1
touch "${lockFile}"
trap 'rm -f ${lockFile}' EXIT


#// define functions
Wall_Cache()
{
    wallExt="${wallList[setIndex]##*.}"

    ln -fs "${wallList[setIndex]}" "${wallSet}"
    ln -fs "${wallList[setIndex]}" "${wallCur}"

    Preprocess_MP4

    "${scrDir}/swwwallcache.sh" -w "${wallJpg}" #&> /dev/null
    "${scrDir}/swwwallbash.sh" "${wallJpg}" #&

    Postprocess_MP4

    ln -fs "${thmbDir}/${wallHash[setIndex]}.sqre" "${wallSqr}"
    ln -fs "${thmbDir}/${wallHash[setIndex]}.thmb" "${wallTmb}"
    ln -fs "${thmbDir}/${wallHash[setIndex]}.blur" "${wallBlr}"
    ln -fs "${thmbDir}/${wallHash[setIndex]}.quad" "${wallQad}"
    ln -fs "${dcolDir}/${wallHash[setIndex]}.dcol" "${wallDcl}"
}

Wall_Change()
{
    curWall="$(set_hash "${wallSet}")"
    for i in "${!wallHash[@]}" ; do
        if [ "${curWall}" == "${wallHash[i]}" ] ; then
            if [ "${1}" == "n" ] ; then
                setIndex=$(( (i + 1) % ${#wallList[@]} ))
            elif [ "${1}" == "p" ] ; then
                setIndex=$(( i - 1 ))
            fi
            break
        fi
    done
    Wall_Cache
}

Preprocess_MP4()
{
    wallJpg="${wallList[setIndex]}"

    if [ "${wallExt}" == "mp4" ] ; then
        [ -d "${cacheDir}/themes/${hydeTheme}" ] || mkdir -p "${cacheDir}/themes/${hydeTheme}"

        mp4Sha=$(set_hash "${wallJpg}")
        imageName=$(basename "${wallList[setIndex]}.jpg")
        wallJpg="${cacheDir}/themes/${hydeTheme}/${imageName}"

        [ -f "${wallJpg}" ] || ffmpeg -y -i "${wallList[setIndex]}" -ss 00:00:01.000 -vframes 1 "${wallJpg}"

        jpgSha=$(set_hash "${wallJpg}")
    fi
}

Postprocess_MP4()
{
    if [ "${wallExt}" == "mp4" ] ; then
        cp -f "${thmbDir}/${jpgSha}.blur" "${thmbDir}/${mp4Sha}.blur"
        cp -f "${thmbDir}/${jpgSha}.quad" "${thmbDir}/${mp4Sha}.quad"
        cp -f "${thmbDir}/${jpgSha}.sqre" "${thmbDir}/${mp4Sha}.sqre"
        cp -f "${thmbDir}/${jpgSha}.thmb" "${thmbDir}/${mp4Sha}.thmb"
        cp -f "${dcolDir}/${jpgSha}.dcol" "${dcolDir}/${mp4Sha}.dcol"
    fi
}

Wall_Set()
{
    Kill_Mpv

    local x_wall=$(readlink -f "${wallSet}")
    local wallExt="${x_wall##*.}"
 
    echo ":: applying wall :: \"${x_wall}\""
    if [ "${wallExt}" == "mp4" ] ; then
        Mpv_Set
    else
        Swww_Set
    fi
}

Swww_Set()
{
    swww img "$(readlink "${wallSet}")" \
    --transition-bezier .43,1.19,1,.4 \
    --transition-type "${xtrans}" \
    --transition-duration "${wallTransDuration}" \
    --transition-fps "${wallFramerate}" \
    --invert-y \
    --transition-pos "$(hyprctl cursorpos | grep -E '^[0-9]' || echo "0,0")" &
}

Kill_Mpv()
{
    if [ -e $mpvPid ] ; then
        kill $(cat $mpvPid)
	rm -f $mpvPid
    fi
}

Mpv_Set()
{
    mpvpaper -o "no-audio --loop-file" "*" "$wallSet" &
    echo "$!" > "$mpvPid"
}

#// set variables
scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/globalcontrol.sh"
wallSet="${hydeThemeDir}/wall.set"
wallCur="${cacheDir}/wall.set"
wallSqr="${cacheDir}/wall.sqre"
wallTmb="${cacheDir}/wall.thmb"
wallJpg="${cacheDir}/wall.jpg"
wallBlr="${cacheDir}/wall.blur"
wallQad="${cacheDir}/wall.quad"
wallDcl="${cacheDir}/wall.dcol"
mpvPid="${XDG_CONFIG_HOME:-$HOME/.config}/swww/mpv.pid"


#// check wall
setIndex=0
[ ! -d "${hydeThemeDir}" ] && echo "ERROR: \"${hydeThemeDir}\" does not exist" && exit 0
wallPathArray=("${hydeThemeDir}")
wallPathArray+=("${wallAddCustomPath[@]}")
get_hashmap "${wallPathArray[@]}"
[ ! -e "$(readlink -f "${wallSet}")" ] && echo "fixig link :: ${wallSet}" && ln -fs "${wallList[setIndex]}" "${wallSet}"


#// evaluate options
while getopts "nps:" option ; do
    case $option in
    n ) # set next wallpaper
        xtrans="grow"
        Wall_Change n
        ;;
    p ) # set previous wallpaper
        xtrans="outer"
        Wall_Change p
        ;;
    s ) # set input wallpaper
        if [ ! -z "${OPTARG}" ] && [ -f "${OPTARG}" ] ; then
            get_hashmap "${OPTARG}"
        fi
        Wall_Cache
        ;;
    * ) # invalid option
        echo "... invalid option ..."
        echo "$(basename "${0}") -[option]"
        echo "n : set next wall"
        echo "p : set previous wall"
        echo "s : set input wallpaper"
        exit 1 ;;
    esac
done


#// check swww daemon
swww query &> /dev/null
if [ $? -ne 0 ] ; then
    swww-daemon --format xrgb &
    swww query && swww restore
fi


#// set defaults
[ -z "${xtrans}" ] && xtrans="grow"
[ -z "${wallFramerate}" ] && wallFramerate=60
[ -z "${wallTransDuration}" ] && wallTransDuration=0.4


#// apply wallpaper
Wall_Set


