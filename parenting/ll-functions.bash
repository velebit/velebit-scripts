# functions for luka-*

# these can be overridden by the scripts
run=()
log=(echo)

no_unlock_days=( )

# colors
good () { echo -e '\e[34m'; }
warn () { echo -e '\e[33m'; }
bad ()  { echo -e '\e[31m'; }
end ()  { echo -e '\e[0m'; }

is_done() { echo "$(good)done$(end)"; }
failed()  { echo "$(bad)FAILED$(end)"; }

combine_tokens () {
    local a="$1"; shift
    local b="$1"; shift
    if [ -z "$a" ]; then
        echo "$b"  # even if b is empty
    elif [ -z "$b" ]; then
        echo "$a"
    elif [ "x$a" = "x$b" ]; then
        echo "$a"
    else
        echo "mixed"
    fi
}

lst2comma () {
    # either separate args, whitespace-delimited, or both
    echo "$*" | sed -e 's/^  *//;s/  *$//;s/  */,/g'
}

pidlist () {
    # arguments are a list of command names
    ps -C "$(lst2comma "$@")" -o pid=
}
dms () {
    pidlist sddm lightdm
}
screenlockers () {
    pidlist xscreensaver xflock4
}
children () {
    # arguments are a list of PIDs
    ps --ppid "$(lst2comma "$@")" -o pid=
}
users_cmds () {
    # arguments are a list of PIDs
    ps --pid "$(lst2comma "$@")" -o user=,comm= | sed -e 's/  */:/g' \
        | sort | uniq
}
cmd_line_long () {
    # arguments are a list of PIDs
    ps --pid "$(lst2comma "$@")" --cols 65536 -o args=
}

as_user () {
    local user="$1"; shift
    # remaining arguments are a command line
    local uid="$(id -u "$user")"
    sudo -u "$user" \
        env DISPLAY=:0 XAUTHORITY=/home/"$user"/.Xauthority \
            XDG_RUNTIME_DIR=/run/user/"$uid" \
            "$@"
}
run_as_user () {
    local user="$1"; shift
    # remaining arguments are a command line
    local uid="$(id -u "$user")"
    "${run[@]}" \
        sudo -u "$user" \
        env DISPLAY=:0 XAUTHORITY=/home/"$user"/.Xauthority \
            XDG_RUNTIME_DIR=/run/user/"$uid" \
            "$@"
}

get_user_sessions () {
    local who="$1"; shift
    local pids=( $(dms) )
    while [ "${#pids[@]}" -gt 0 ]; do
        local ret=
        for s in $(users_cmds "${pids[@]}"); do
            case "$s" in
                "$who":*-session*)
                    echo "${s#$who:}"; ret=0 ;;         # 0 = true
                "$who":*)   ;;
                root:*)     ;;
                *:*)
                    if [ -z "$ret" ]; then ret=1; fi ;; # default false
            esac
        done
        if [ -n "$ret" ]; then return $ret; fi
        pids=( $(children "${pids[@]}") )
    done
    return 1   # false
}

get_user_process_pids () {
    local user="$1"; shift
    # remaining arguments are command names
    local pids=( $(pidlist "$@") )
    for p in "${pids[@]}"; do
        case "$(users_cmds "$p")" in
            "$user":*) echo "$p" ;;
        esac
    done
}

get_user_minecraft_pids () {
    local user="$1"; shift
    local java_pids=( $(get_user_process_pids "$user" java) )
    for p in "${java_pids[@]}"; do
        case "$(cmd_line_long "$p")" in
            # Native Minecraft runs from net.minecraft.client.main.Main
            *\ net.minecraft.client.*)  echo "$p" ;;
            # MultiMC runs from org.multimc.EntryPoint
            *\ org.multimc.*)  echo "$p" ;;
        esac
    done
}

user2name () {
    local who="$1"; shift
    case "$who" in
        bert) echo "$who" ;;
        *)    echo "${who^}" ;;
    esac
}

get_account_locked_status () {
    local who="$1"; shift
    case "$(passwd -S "$who")" in
        "$who"\ L\ *) echo -n "1" ;;
        "$who"\ P\ *) echo -n "0" ;;
        "$who"\ NP\ *)
            echo "$(warn)Warning: $who has no password$(end)" >&2
            echo -n "np" ;;
        *)
            echo "$(warn)Warning: can't understand 'passwd -S' for $who$(end)" >&2
            echo -n "x" ;;
    esac
    case "$(chage -l "$who" | sed -e '/Account expires/!d')" in
        *:*never*)          echo -n " 0" ;;
        *:*"Jan 02, 1970"*) echo -n " 1" ;;
        *)
            echo "$(warn)Warning: can't understand 'chage -l' for $who$(end)" >&2
            echo -n " x" ;;
    esac
}
is_account_locked () {
    local who="$1"; shift
    case "$(get_account_locked_status "$who")" in
        "1 1") return 0 ;;
        *)     return 1 ;;
    esac
}
is_account_unlocked () {
    local who="$1"; shift
    case "$(get_account_locked_status "$who")" in
        "0 0") return 0 ;;
        *)     return 1 ;;
    esac
}
    
lock_account () {
    local who="$1"; shift
    local name="$(user2name "$who")"
    if is_account_locked "$who"; then
        "${log[@]}" "${name}'s account $(good)was already locked$(end)." >&2
        return 0
    fi
    "${log[@]}" "Locking ${name}'s account..." >&2
    if ! "${run[@]}" usermod -L -e 1 "$who"; then
        "${log[@]}" "...$(failed), exiting." >&2
        exit 2
    fi
    "${log[@]}" "...$(is_done)." >&2
}

unlock_account () {
    local who="$1"; shift
    local name="$(user2name "$who")"
    if is_account_unlocked "$who"; then
        "${log[@]}" "${name}'s account $(good)was already unlocked$(end)." >&2
        return 0
    fi
    "${log[@]}" "Unlocking ${name}'s account..." >&2
    if ! "${run[@]}" usermod -U -e '' "$who"; then
        "${log[@]}" "...$(failed), exiting." >&2
        exit 2
    fi
    "${log[@]}" "...$(is_done)." >&2
}

lock_screen () {
    local retval=0
    local session_found lock_log
    for s in $(get_user_sessions "$user"); do
        session_found=yes
        case "$s" in
            lxqt-session)
                "${log[@]}" "Trying to lock the screen..." >&2
                lock_log="/tmp/lock_log.$$"
                if ! run_as_user "$user" \
                     xscreensaver-command -lock > "$lock_log" 2>&1; then
#                     lxqt-leave --lockscreen > "$lock_log" 2>&1; then
                    sed -e 's/^/  /' "$lock_log"
                    case "$(cat "$lock_log")" in
                        *": already locked"*)
                            "${log[@]}" "...$(warn)was already locked$(end)." \
                                        >&2
                            ;;
                        *)
                            "${log[@]}" "...$(failed), will try rebooting!." \
                                        >&2
                            retval=1
                            ;;
                    esac
                else
                    "${log[@]}" "...$(is_done)." >&2
                fi
                rm -f "$lock_log"
                ;;
            *)
                "${log[@]}" "$(warn)Unknown session '$s', locking skipped.$(end)" >&2
                ;;
        esac
    done
    if [ -z "$session_found" ]; then
        "${log[@]}" "$(warn)$(user2name "$user") does not seem to be logged in.$(end)" >&2
    fi
    return "$retval"
}

set_perms_oct () {
    local path="$1"; shift
    local perms_oct="$1"; shift
    local perms_name="$1"; shift
    case "$(stat -c '%a' "$path" 2>/dev/null)" in
        "")
            "${log[@]}" "${path} not found, skipped." >&2 ;;
        "$perms_oct")
            "${log[@]}" "${path} $(good)was already $perms_name$(end)." >&2 ;;
        *)
            "${log[@]}" "Setting ${path} permissions to $perms_name..." >&2
            if ! "${run[@]}" chmod "$perms_oct" "$path"; then
                "${log[@]}" "...$(failed), exiting." >&2
                exit 3
            fi
            "${log[@]}" "...$(is_done)." >&2
            ;;
    esac
}

lock_dir () {
    local path="$1"; shift
    set_perms_oct "$path" 700 "locked"
}
unlock_dir () {
    local path="$1"; shift
    set_perms_oct "$path" 711 "unlocked/protected"
}
fully_unlock_dir () {
    local path="$1"; shift
    set_perms_oct "$path" 755 "fully unlocked"
}
lock_executable_file () {
    local path="$1"; shift
    set_perms_oct "$path" 700 "locked"
}
unlock_executable_file () {
    local path="$1"; shift
    set_perms_oct "$path" 755 "unlocked"
}

kill_user_minecraft () {
    local user="$1"; shift
    local pids=( $(get_user_minecraft_pids "$user") )
    if [ "${#pids[@]}" -gt 0 ]; then
        "${log[@]}" "Killing $(user2name "$user")'s Minecraft processes..." >&2
        if ! "${run[@]}" kill -HUP "${pids[@]}"; then
            "${log[@]}" "...$(failed)." >&2
        else
            "${log[@]}" "...$(is_done)." >&2
        fi
    else
        "${log[@]}" "$(user2name "$user") does not seem to be running $name." >&2
    fi
}

kill_user_process () {
    local user="$1"; shift
    local name="$1"; shift
    local pids=( $(get_user_process_pids "$user" "$name") )
    if [ "${#pids[@]}" -gt 0 ]; then
        "${log[@]}" "Killing $(user2name "$user")'s $name processes..." >&2
        if ! "${run[@]}" kill -HUP "${pids[@]}"; then
            "${log[@]}" "...$(failed)." >&2
        else
            "${log[@]}" "...$(is_done)." >&2
        fi
    else
        "${log[@]}" "$(user2name "$user") does not seem to be running $name." >&2
    fi
}

lock_flatpak_graphics () {
    local app="$1"; shift
    case "`flatpak override --show "$app" | grep '^sockets='`" in
        *"!x11;"*"!wayland;"*"!fallback-x11;"*)
            "${log[@]}" "Graphics access for ${app} $(good)was already locked$(end)." >&2 ;;
        *)
            "${log[@]}" "Locking graphics access for ${app}..." >&2
            if ! "${run[@]}" flatpak override \
                                 --nosocket=x11 \
                                 --nosocket=wayland \
                                 --nosocket=fallback-x11 \
                                 "$app"; then
                "${log[@]}" "...$(failed), exiting." >&2
                exit 4
            fi
            "${log[@]}" "...$(is_done)." >&2
            ;;
    esac
}
unlock_flatpak () {
    local app="$1"; shift
    case "`flatpak override --show "$app"`" in
        "")
            "${log[@]}" "${app} $(good)was already unlocked$(end)." >&2 ;;
        *)
            "${log[@]}" "Resetting permissions for ${app}..." >&2
            if ! "${run[@]}" flatpak override \
                                 --reset \
                                 "$app"; then
                "${log[@]}" "...$(failed), exiting." >&2
                exit 4
            fi
            "${log[@]}" "...$(is_done)." >&2
            ;;
    esac
}

is_flatpak_user_app_running () {
    local user="$1"; shift
    local app="$1"; shift
    local entries="$(as_user "$user" flatpak ps --columns=inst,app \
                     | awk '($2=="'"$app"'")')"
    [ -n "$entries" ]
}
kill_flatpak_user_app () {
    local user="$1"; shift
    local app="$1"; shift
    if is_flatpak_user_app_running "$user" "$app"; then
        "${log[@]}" "Killing $(user2name "$user")'s $app app..." >&2
        if ! run_as_user "$user" flatpak kill "$app"; then
            "${log[@]}" "...$(failed)." >&2
        else
            "${log[@]}" "...$(is_done)." >&2
        fi
    else
        "${log[@]}" "$(user2name "$user") does not seem to be running $app." >&2
    fi
}

notify () {
    local user="$1"; shift
    local summary="$1"; shift
    local body="$1"; shift
    local icon="${1:-user-available}"; shift
    local app_name="$1"; shift

    # Notable icons:
    # system-lock-screen, system-shutdown, user-available (talk bubble?),
    # appointment-soon, appointment-missed, dialog-information,
    # dialog-warning, dialog-error
    # See also:
    # https://specifications.freedesktop.org/icon-naming-spec/icon-naming-spec-latest.html

    local cmd_line=( notify-send )
    cmd_line+=( -t 0 )
    if [ -n "$app_name" ]; then
        cmd_line+=( -a "$app_name" )
    fi
    cmd_line+=( -i "$icon" )
    if [ -z "$summary" ]; then
        cmd_line+=( "$body" )  # even if empty value
    elif [ -z "$body" ]; then
        cmd_line+=( "$summary" )
    else
        cmd_line+=( "$summary" "$body" )
    fi
    run_as_user "$user" "${cmd_line[@]}"
}

pulseaudio_get_mute_state_all () {
    local user="$1"; shift
    local line common_state mute_state
    while IFS='' read -r line; do
        line="${line//[ 	]/ }"
        line="${line//  / }"; line="${line//  / }"; line="${line//  / }"
        case "$line" in
            Sink\ *)  # new sink
                common_state="$(combine_tokens "$common_state" "$mute_state")"
                # If a Mute: line is not seen, that probably means not
                # muted, but assuming we need to update is conservative
                mute_state=unknown
                ;;
            \ Mute:\ yes*)  mute_state=true ;;
            \ Mute:\ no*)   mute_state=false ;;
        esac
    done < <(run_as_user "$user" pactl list sinks)
    # the last sink isn't followed by a Sink line, so process it here
    common_state="$(combine_tokens "$common_state" "$mute_state")"
    if [ -z "$common_state" ]; then common_state=undefined; fi
    echo "$common_state"
}

pulseaudio_set_mute_state_all () {
    local user="$1"; shift
    local muted="$1"; shift
    local s
    local num=0
    for s in $(run_as_user "$user" pactl list short sinks \
                   | awk '{print $1}'); do
        if run_as_user "$user" pactl set-sink-mute "$s" "$muted"; then
            num="$((num+1))"
        fi
    done
    if [ "$num" -gt 0 ]; then
        "${log[@]}" "Set $(user2name "$user")'s audio muting to" \
            "$(good)$muted$(end) for $(good)$num sink(s)$(end)." >&2
    else
        "${log[@]}" "Set $(user2name "$user")'s audio muting to" \
            "$(warn)$muted$(end) for $(warn)$num sink(s)$(end)." >&2
    fi
}

mute_all () {
    local user="$1"; shift
    if [ "$(pulseaudio_get_mute_state_all "$user")" = true ]; then
        "${log[@]}" "$(user2name "$user")'s audio is already" \
            "$(good)muted$(end)." >&2
    else
        # includes unknown and mixed states
        pulseaudio_set_mute_state_all "$user" true
    fi
}

unmute_all () {
    local user="$1"; shift
    if [ "$(pulseaudio_get_mute_state_all "$user")" = false ]; then
        "${log[@]}" "$(user2name "$user")'s audio is already" \
            "$(good)unmuted$(end)." >&2
    else
        # includes unknown and mixed states
        pulseaudio_set_mute_state_all "$user" false
    fi
}

clear_at_queue () {
    local queue="$1"; shift
    local jobs=( $(atq -q "$queue" | awk '{print $1}') )
    if [ "${#jobs[@]}" -gt 0 ]; then
        "${run[@]}" atrm "${jobs[@]}"
    fi
}
schedule_commands () {
    local queue="$1"; shift
    local timespec="$1"; shift
    local i
    for i in "$@"; do echo "$i"; done \
        | "${run[@]}" at -M -q "$queue" "$timespec"
}
script_command () {
    local script="$1"; shift
    local user="$1"; shift
    echo "\"$(dirname "$(realpath "$0")")/$script\" -u \"$user\""
}

AT_QUEUE_RELOCK=c
DEFAULT_BEDTIME='19:30'

clear_relock_queue () {
    clear_at_queue "$AT_QUEUE_RELOCK"
}
schedule_lock () {
    local user="$1"; shift
    local timespec="$1"; shift

    local pretty
    local timestamp="$(date --date="$timespec" '+%s')"
    if [ -z "$timestamp" ]; then
        echo "$(bad)Error: Could not parse '$timespec' as a time!$(end)" >&2
        return 1
    fi
    local dist="$(("$timestamp" - "$(date '+%s')"))"
    if [[ "$dist" -ge -43200 ]] && [[ "$dist" -le -21600 ]] && \
           [[ "$(date --date="@$timestamp" '+%H')" -lt 12 ]]; then
        pretty="$(date --date="@$timestamp" '+%Y-%m-%d %H:%M:%S')"
        echo "$(bad)Error: $pretty is in the past, did you forget 'pm'?" >&2
        return 2
    elif [[ "$dist" -le 0 ]]; then
        pretty="$(date --date="@$timestamp" '+%Y-%m-%d %H:%M:%S')"
        echo "Error: $pretty is in the past!" >&2
        return 2
    fi

    clear_relock_queue \
        || return 3
    if [[ "$dist" -gt 300 ]]; then
        local pre_timestamp="$(($timestamp-300))"
        schedule_commands \
            "$AT_QUEUE_RELOCK" \
            "$(date --date="@$pre_timestamp" '+%H:%M %Y-%m-%d')" \
            "$(script_command 'luka-message' "$user") --icon=lock 'Lock warning' 'SQ will lock in 5 minutes'" \
            "for i in 4 3 2; do" \
            "  sleep 60" \
            "  $(script_command 'luka-message' "$user") --icon=clock 'Lock warning' \"SQ will lock in \$i minutes\"" \
            "done" \
            "sleep 60" \
            "$(script_command 'luka-message' "$user") --icon=clock 'Lock warning' 'SQ will lock in 1 minute'" \
            || return 4
    fi
    schedule_commands \
        "$AT_QUEUE_RELOCK" \
        "$(date --date="@$timestamp" '+%H:%M %Y-%m-%d')" \
        "$(script_command 'luka-lock' "$user")" \
        || return 5
    return 0
}
schedule_lock_at_bedtime () {
    local user="$1"; shift
    schedule_lock "$user" "$DEFAULT_BEDTIME"
}
