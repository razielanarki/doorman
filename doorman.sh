#!/usr/bin/env -S bash
#============================================================================
# DOORMAN: a Procfile runner / foreman clone for BASH
#============================================================================
# Copyright (C) 2020 //  Raziel Anarki <razielanarki@semmi.se>
#----------------------------------------------------------------------------
# shellcheck disable=SC1090,SC2028,SC2034,SC2155

  set +o errexit      # don't exit on nonzero exit status
  set +o monitor      # disable job control
  set -o pipefail     # pipe commands exit statuses

  shopt -s lastpipe   # last command in a pipeline runs in the current shell
  shopt -s xpg_echo   # echo implies echo -e

#----------------------------------------------------------------------------
# constants

  readonly    DOORMAN="$(basename "${0}")"
  readonly    DOORMAN_VERSION='1.0.7'

  readonly -a DOORMAN_TRAP=(EXIT HUP INT ABRT TERM KILL)
  readonly -A DOORMAN_LOGS=([out]=37 [err]=31 [log]=34)
  readonly -a DOORMAN_PROC=(36 33 32 35 34 96 93 92 95 94)

  readonly    DEFAULT_PROCFILE="./Procfile"
  readonly    DEFAULT_ENVFILE="./.env"

#----------------------------------------------------------------------------
# configurable settings

  declare    DOORMAN_ROOTDIR=''
  declare    DOORMAN_PROCFILE=${DEFAULT_PROCFILE}
  declare -a DOORMAN_ENVFILES=("${DEFAULT_ENVFILE}")

  declare    DOORMAN_WAITOPT=''
  declare -i DOORMAN_RESTART=$((1))
  declare -i DOORMAN_TIMEOUT=$((0))

#----------------------------------------------------------------------------

  function doorman::header
  {
    local off text c head em self ver in copy by docker bash;
    doorman::colors off text c head em self ver in copy by docker bash;

    echo "$(cat <<-LOGO
			 ${self}  ___   ___   ___   ___                 ${off}
			 ${self} | | \ / / \ / / \ | |_) |\/|  /\  |\ | ${off}
			 ${self} |_|_/ \_\_/ \_\_/ |_| \ |  | /--\ | \| ${c}:( v${ver}${DOORMAN_VERSION}${c} ):${off}
			 ${self}                                        ${off}
			${c}#${self} DOORMAN ${c}//${h1} a Procfile runner ${c}/${h1} foreman clone for${bash} BASH ${off}
			 ${copy} Copyright ${c}(${text}C${c})${copy} 2020 ${c}//${by} Raziel Anarki ${c}<${em}razielanarki@semmi.se${c}>${off}\n
			LOGO
    ) "
  }

  function doorman::usage
  {
    cat <<-USAGE
			# usage:

			  $ ${DOORMAN} [-h|--help]
			  $ ${DOORMAN} [-v|--version]
			  $ ${DOORMAN} [-p PROCFILE] [[-e ENVFILE] ...] [-d PATH] [-f|-w] [-r [MAXTRIES]] [-t [SECONDS]]

			# available options:

			  -h, --help               ~ Display this help and exit.
			  -v, --version            ~ Display version number and exit.

			  -p, --procfile=PROCFILE  ~ Specify an alternate {Procfile} to use instead of '${DEFAULT_PROCFILE/./\$PATH}'.
			  -e, --env=ENVFILE        ~ Specify additional {DotEnv} ('.env') files to load after '${DEFAULT_ENVFILE/./\$PATH}'.
			  -d, --directory=PATH     ~ Specify an alternate directory to use as the root directory, which will be
			                           ~ used as the directory where commands in the {Procfile} will be executed,
			                           ~ and where '.env' files will be searched for.
			                           ~ The default root directory is the directory containing the Procfile.

			  -f, --fail-one           ~ Shut down when {ANY} process exits, terminating remaining processes.
			  -w, --wait-all           ~ Shut down only after {ALL} processes have exited. This is the default mode.

			  -r, --restart[=MAXTRIES] ~ Restart processes which have exited, with an optional limit on the maximum tries.
			                           ~ When the argument is present with the optional {=MAXTRIES} parameter omitted,
			                           ~ the value defaults to 0, which means no restart limit.
			                           ~ Otherwise {Doorman} lets processes fail after running them {=MAXTRIES} times,
			                           ~ Without the {--restart} argument, each process runs only once.

			  -t, --timeout[=SECONDS]  ~ Set a shutdown timeout in seconds each process is given to terminate
			                           ~ before being sent a {@KILL} signal in the event of {Doorman} shutting down.
			                           ~ When the argument is present with the optional {=SECONDS} parameter omitted,
			                           ~ the timeout defaults to 3 seconds.
			                           ~ Without the {--timeout} argument, processes are {@KILL}ed immediately.
		USAGE
  } > >(doorman::color::usage)

#----------------------------------------------------------------------------

  # https://www.fvue.nl/wiki/Bash:_Passing_variables_by_reference
  function fvue::upvars
  {
    while (( $# )); do [ "${1}" ] && [ "${2}" ] &&
    unset -v "${1}" && eval "${1}=\"\${2}\""; shift 2; done
  }

  function doorman::colors
  {
    local off=''    text='' c=''
    local h1=''     arg=''  val=''
    local err=''    help='' em=''
    local var=''    num=''  str=''
    local self=''   ver=''  in=''
    local copy=''   by=''
    local docker='' bash=''
    local task=''   args=''
    local warn=''   erritem=''

    [ "$(tput colors)" -ge 8 ] &&
    {
      off="\033[m";       text="\033[;37m";   c="\033[;37;2m";
      h1="\033[;32;1m";   arg="\033[;33m";    val="\033[;36;3m";
      err="\033[;31m";    help="\033[;32m";   em="\033[;33;3m";
      var="\033[;34m";    num="\033[;35;1m";  str="\033[;36m";
      self="\033[;33;1m"; ver="\033[;37m";    in="\033[;34;1m";
      copy="\033[;36;1m"; by="\033[;34;1m";
      docker="\033[;36m"; bash="\033[;35;1m";
      task="\033[;32;1m"; args="\033[;32m";
      warn="\033[;33;1m"; erritem="\033[;31;1m";
    }

    local -a _upvars=() _upargs=()
    while (( $# )); do _upvars+=("$1"); _upargs+=("$1" "${!1}"); shift; done
    ((${#_upvars[@]})) && local "${_upvars[@]}" && fvue::upvars "${_upargs[@]}"
  }

  function doorman::symbols
  {
    local prompt="$" altern="❘" ellips="ꓺ" astrsk="∗" pvalue=":-"
    local lv1="∷" lv2="»" lv3="›"

    local -a _upvars=() _upargs=()
    while (( $# )); do _upvars+=("$1"); _upargs+=("$1" "${!1}"); shift; done
    ((${#_upvars[@]})) && local "${_upvars[@]}" && fvue::upvars "${_upargs[@]}"
  }

  function doorman::color::usage
  {
    local q="\\\\"
    local q1="${q}1" q2="${q}2" q3="${q}3" q4="${q}4" q5="${q}5" q6="${q}6" q7="${q}7"
    local indent="  "

    local off text c h1 arg val help em var num str self bash
    doorman::colors off text c h1 arg val help em var num str self bash

    local prompt altern ellips astrsk pvalue lv1 lv2 lv3 li
    doorman::symbols prompt altern ellips astrsk pvalue lv1 lv2 lv3 li

    gawk "{ln=\$0;$(cat <<-COLORER
			gsub(/\[+/, "${c}&${val}", ln);
			gsub(/[()]/, "${c}&${help}", ln);
			gsub(/^# /, "${c}${lv1}${h1} ", ln);
			gsub(/\{=/, "{${val}", ln);
			gsub(/\{@/, "{${arg}", ln);
			gsub(/\.\.+/, "${ellips}", ln);
			gsub(/*/, "${astrsk}", ln);
			gsub(/^\s+-/, "${indent}${c}${lv2}${text} -", ln);
			ln=gensub(/^##(.*)$/, "\n\t>${indent}${c}${lv2}${text}${q1} ${off}", "g", ln);
			gsub(/^\s*\\$\s/, "\t>${indent}${c}${prompt}${self} ", ln);
			ln = gensub(/^-( ([^ ]| \| )+ )(${ellips})?/,
			    "${indent}${indent}${c}${lv3}${arg}${q1}${text}${c}${q3}${off}", "g", ln);
			gsub(/\s+~\s/, "\t${help}", ln);
			ln = gensub(/(;[0-9]*m|\W)( ?--|-)(([a-z][-a-z]*)?([ =])?([A-Z][-A-Z]*)?(\033)?)?/,
			    "${q1}${text}${q2}${arg}${q4}${text}${q5}${val}${q6}${off}${q7}", "g", ln);
			ln = gensub(/([^\$])?\{([^}]+)\}/, "${q1}${em}${q2}${help}", "g", ln);
			gsub(/\|/, "${c}${altern}${arg}", ln);
			ln = gensub(/([\.,:])( |\033|$)/, "${c}${q1}${help}${q2}", "g", ln);
			ln = gensub(/'([^']+)'/, "${c}'${str}${q1}${c}'${help}", "g", ln);
			ln = gensub(/(\[\033\[[;0-9]+m):/, "[${help}","g", ln);
			ln = gensub(/(\[\033\[[;0-9]+m)([a-zA-Z][-a-zA-Z]*)?:/, "[${val}${q2}${c}${pvalue}${help}","g", ln);
			ln = gensub(/(\033\[[;0-9]*m)?=([a-zA-Z][-a-zA-Z]*)/, "${text}=${val}${q2}${off}", "g", ln);
			ln = gensub(/([0-9]+)([^;0-9m])/, "${num}${q1}${help}${q2}", "g", ln);
			gsub(/\\\$\w+/, "${var}&${str}", ln);
			gsub(/BASH/, "${bash}&${help}", ln);
			gsub(/\](( \033\[[;0-9]*m\[+| ${ellips}\])+)?| ?${ellips}/, "${c}&${off}", ln);
			gsub(/$/, "${off}", ln);
			print gensub(/(\033\[[;0-9]*m)+\033/, "\033", "g", ln);
		COLORER
    )}" | column -ts $'\t' | sed -e 's/^\s*>//'
  }

  # to do
  # --l, --logs=DIR   : specify directory for logfiles
  # --b, --base-port : set $PORT for each process
  # [options] -- [start [procname] [procname] ... | run [cmd] [arg] [arg] ...]

  function doorman::error
  {
    local d=$'\c[[;33;1m' a=$'\c[[;33m' p=$'\c[[;37;2m' e=$'\c[[;31m' o=$'\c[[m'
    echo "$d$DOORMAN$p: $e${*}$o" | sed -Ee "s/'(--)?([^']*)'/$p'\1$a\2$p'$e/;s/ --/ $p--$e/" >&2
  }

#----------------------------------------------------------------------------
# getopt implementation

  readonly   DOORMAN_OPTS='d:hve:fp:r::t::w'
  readonly   DOORMAN_LONG='directory:,help,version,env:,fail-one,procfile:,restart::,timeout::,wait-all'

  # works similar to the util-linux version of getopt, except:
  # - does not allow "alternative" (aka single dash) long opts
  # - does not support '+' prefix for short opts
  # - always prints errors (to stderr) and output (to stdout)
  # - always quotes args & not-opts, in BASH syntax (using '-s)
  # + CAN parse empty optional args for shortopts
  function doorman::getopt
  {
    local -a in=("${@}") out=() not=()
    local -i id=0 add=0 pos=0
    local cur next name arg
    local has opt eq bef

    while (( id < ${#in[@]} )); do
      cur="${in[id]}"; next="${in[id+1]}"

      [ "${cur}" = '--' ] &&
      {
        [ ${add} -eq 1 ] && out+=("''")
        break
      }

      [ "${cur:0:2}" = '--' ] &&
      {
        [ ${add} -eq 1 ] && out+=("''")
        (( add = 0, pos = 0, id++ ))

        local IFS='='; echo "${cur:2}==!" | read -r name arg eq

        def=${DOORMAN_LONG#*"${name}"}; has=${def:0:1}; opt=${def:1:1}
        bef=${DOORMAN_LONG: -${#def} - ${#name} - 1:1}

        [ "${def}" = "${DOORMAN_LONG}" ] ||
        [ ! "${bef:-,}" = ',' ] || [ ! "${has//[,:]/}," = ',' ] &&
          doorman::error "unrecognized option '${cur}'" &&
          continue

        [ "${has}" = ':' ] && [ "${eq:0:1}" = '!' ] &&
        {
          [ ! "${opt}" = ':' ] && arg=${next} && (( id++ ))
          [   "${opt}" = ':' ] && add=$((1))
        }

        [ ! "${has}" = ':' ] && [ "${eq:0:1}" = '=' ] && [ ${add} -ne 1 ] &&
          doorman::error "option '--${name}' doesn't allow an argument" &&
          continue

        out+=("--${name}")
        [ "${has}" = ':' ] && [ ${add} -ne 1 ] && out+=("'${arg}'")
        continue
      }

      [ "${cur:0:1}" = '-' ] && [ ! "${cur}" = '-' ] &&
      {
        [ ${add} -eq 1 ] && out+=("''")
        (( add = 0, pos = pos ? pos : 1 ))

        name=${cur:pos:1}; arg=${cur:pos + 1}
        def=${DOORMAN_OPTS#*"${name}"}; has=${def:0:1}; opt=${def:1:1}

        [ "${has}" = ':' ] && (( pos = 0 ))

        (( pos && pos + 1 < ${#cur} ? pos++ : (id++, pos = 0) ))

        [ "${def}" = "${DOORMAN_OPTS}" ] &&
          doorman::error "invalid option -- '${name}'" &&
          continue

        [ "${has}" = ':' ] && [ "${arg:-!}" = '!' ] &&
        {
          [ ! "${opt}" = ':' ] && arg=${next} && (( id++ ))
          [   "${opt}" = ':' ] && add=$((1))
        }

        out+=("-${name}")
        [ "${has}" = ':' ] && [ ${add} -ne 1 ] && out+=("'${arg}'")
        continue
      }

      [ ${add} -eq 1 ] && out+=("'${cur}'")
      [ ${add} -eq 0 ] && not+=("'${cur}'")

      (( add = 0, pos = 0, id++ ))
    done

    [ ${add} -eq 1 ] && out+=('')

    out+=('--' "${not[@]}")
    while (( ++id < ${#in[@]} )); do out+=("'${in[id]}'"); done

    echo '' "${out[@]}"
  }

#----------------------------------------------------------------------------
# parse and re-set args, capture errors via fd#5

  declare -a OPTERRORS

  # parse args with getopt and capture stderr
  # shellcheck disable=SC2046 # resplit output of getopt
  { set -- $(chmod u+w /dev/fd/5 && doorman::getopt "${@}" 2>/dev/fd/5); readarray -tu5 OPTERRORS; } 5< <(echo -en '')

  # log getopt errors, if any
  [ "${#OPTERRORS[@]}" -gt 0 ] &&
    for message in "${OPTERRORS[@]}"; do echo "${message}"; done &&
    exit 64 # "command line usage error"

#----------------------------------------------------------------------------
# process re-parsed args

  while [ $# -gt 0 ]; do
    declare opt=${1}; shift   # get current option , shift args
    declare arg=${1:1:-1}     # " dequote " next option
    case "${opt}" in
      -h|--help)      doorman::header;doorman::usage; exit;;
      -v|--version)   echo "${DOORMAN_VERSION}"; exit;;
      -p|--procfile)  DOORMAN_PROCFILE=${arg};  shift;;
      -e|--env)       DOORMAN_ENVFILES+=("${arg}"); shift;;
      -d|--directory) DOORMAN_ROOTDIR=${arg}; shift;;
      -f|--fail-one)  DOORMAN_WAITOPT='-n';;
      -w|--wait-all)  DOORMAN_WAITOPT='';;
      -r|--restart)   DOORMAN_RESTART=$((${arg:-0})); shift;;
      -t|--timeout)   DOORMAN_TIMEOUT=$((${arg:-3})); shift;;
      --) break;;     # end of options
       *) exit 70;;   # "internal software error"
    esac                # or unknown option, shouldn't happen
  done

  [ "${BASH_VERSINFO[0]}" -ge 5 ] &&
  { # use 'wait -f' if BASH 5+
    [ "${DOORMAN_WAITOPT}" =  ''  ] && DOORMAN_WAITOPT='-f'
    [ "${DOORMAN_WAITOPT}" = '-n' ] && DOORMAN_WAITOPT='-fn'
  }

#----------------------------------------------------------------------------

  # check if procfile exists, ..
  [ ! -e "${DOORMAN_PROCFILE}" ] &&
    doorman::error "procfile '$(realpath "${DOORMAN_PROCFILE}")' does not exist" &&
    exit 74 # "i/o error"

  # .. is readable, ..
  [ ! -r "${DOORMAN_PROCFILE}" ] &&
    doorman::error "procfile '$(realpath "${DOORMAN_PROCFILE}") is not readable" &&
    exit 66 # "cannot open input"

  # .. and has processes defined
  [ "$(wc -w < "${DOORMAN_PROCFILE}")" = 0 ] &&
    doorman::error "procfile '$(realpath "${DOORMAN_PROCFILE}")' appears empty" &&
    exit 78 # "configuration error"

#----------------------------------------------------------------------------

  declare -a PROC_NAMES PROC_CMDS
  declare -i PADNAMES=${#DOORMAN}

  function doorman::parse
  {
    local line name IFS=$' \t'
    local -i ID=0

    while read -r line; do
      [ ! "${line}" ] || [ "${line:0:1}" = '#' ] && continue
      PROC_NAMES[ID]=$(echo "${line%%:*}" | xargs)
      PROC_CMDS[ID]=${line#*:} # $(local -a cmd=(${line#*:}); echo "${cmd[*]}")
      (( ID++ ))
    done < "${DOORMAN_PROCFILE}"

    PADNAMES=$(for name in "${PROC_NAMES[@]}"; do echo "${#name}"; done | sort -nr | head -1)
  }

  doorman::parse

#----------------------------------------------------------------------------
# logging co-process

   # the logging process
  function doorman::logger
  {
    local ID name stream message; local IFS='|'

    # set logger coprocess name, and ignore traps
    printf 'doorman::logger' > "/proc/${BASHPID}/comm"
    trap -- '' "${DOORMAN_TRAP[@]}"

    # read, colorize and echo log lines sent from subprocesses
    while read -rs ID name stream message; do
      printf "%b%-${PADNAMES}b %b %b\033[;m\n" \
        "\033[;$([ "${ID}" = "00" ] && echo "33;1" || echo "$((DOORMAN_PROC[ID % ${#DOORMAN_PROC[@]}]))")m" \
        "${name}" "\033[;37;2m|\033[;${DOORMAN_LOGS["${stream}"]}m" "${message}"
    done
  }

  # redirect logger output to stdout via fd#6 and read input from fd#7
  exec 6>&1; coproc DOORMAN_LOGGER { doorman::logger 1>&6; }
  exec 7>&"${DOORMAN_LOGGER[1]}"

  # doorman error log
  function doorman::log { echo "00|doorman|err|${*}"; } >&7

  # prefix a line with a var and send to the logger
  function doorman::logline
  {
    local IFS=$'\n'; printf "%.15s" "logline ${1}" > "/proc/${BASHPID}/comm"
    while read -rs line; do echo "${ID}|${PS}|${1}|${line}"; done
  } >&7

#----------------------------------------------------------------------------
# trapping signals

  # send a signal to processes
  function doorman::kill
  {
    local -a pids; local IFS=$'\n'

    jobs -p | grep -Fxv "${DOORMAN_LOGGER_PID}" | read -ra pids
    [ ${#pids[@]} -eq 0 ] && return 0

    doorman::log "sending \033[;33m${1:-INT}\033[;31m to remaining \033[;33m${#pids[@]}\033[;31m processes..."
    kill -s "${1:-INT}" -- "${pids[@]}"

    jobs -p | grep -Fxv "${DOORMAN_LOGGER_PID}" | read -ra pids
    [ ${#pids[@]} -eq 0 ]
  }

  # main trap handler
  function doorman::trap
  {
    doorman::log "received \033[;33m${2}\033[;31m with status \033[;$(($1 ? 31 : 32))m${1}"
    trap -- '' "${DOORMAN_TRAP[@]}" # ignore repeat traps

    doorman::kill TERM ||
    {
      [ "${DOORMAN_TIMEOUT}" -gt 0 ] &&
        doorman::log "sleeping for \033[;33m${DOORMAN_TIMEOUT}\033[;31m seconds, allowing processes terminate..." &&
        sleep "${DOORMAN_TIMEOUT}" &&
        doorman::kill KILL
    }

    return $(($1))
  }

  # shellcheck disable=SC2064 # we want ${signal} to expand while setting the trap
  for signal in "${DOORMAN_TRAP[@]}"; do
    trap "doorman::trap \$? '${signal}'" "${signal}"
  done

#----------------------------------------------------------------------------
# run processes

  # set our process name
  printf "%.15s" "${DOORMAN}" > "/proc/${BASHPID}/comm"

  # set root directory for .env-s / pwd for processes
  [ ! "${PWD}" = "${DOORMAN_ROOTDIR:=$(dirname "$(realpath "${DOORMAN_PROCFILE}")")}" ] &&
    pushd "${DOORMAN_ROOTDIR}" >& /dev/null

  echo "root'${DOORMAN_ROOTDIR}'"

  # load available env files
  for envfile in "${DOORMAN_ENVFILES[@]}"; do
    [ ! -r "${envfile}" ] && continue
    set -o allexport; source "${envfile}"; set +o allexport
  done

  # start processes
  for ID in "${!PROC_NAMES[@]}"; do
    declare PS=${PROC_NAMES[ID]}
    (
      declare restart=$((DOORMAN_RESTART))
      echo "starting \033[;34m${ID}\033[;36m as\033[;94m PID\033[;37;2m=\033[;33m${BASHPID}" >&3
      trap -- '' "${DOORMAN_TRAP[@]}"
      printf "%.15s" "${PS}" > "/proc/${BASHPID}/comm"
      while true; do
        bash -c "exec ${PROC_CMDS[ID]@P}"; declare -i status=$?
        echo "process exited with status: \033[;$((status ? 31 : 32))m${status}" >&3
        [ $((--restart)) -eq 0 ] && break
        echo "restarting..." >&3
      done
      # echo "process stopped, last status: \033[;$((status ? 31 : 32))m${status}" >&3
    ) 3> >(doorman::logline 'log') 2> >(doorman::logline 'err') 1> >(doorman::logline 'out') &
  done

  # reset pwd
  popd >& /dev/null

  # wait for processes to terminate
  # shellcheck disable=SC2046 # re-split to get individual PIDs
  wait ${DOORMAN_WAITOPT} $(jobs -p | grep -Fxv "${DOORMAN_LOGGER_PID}" | xargs)
