#! /usr/bin/env modernish
#! use safe
#! use sys/cmd/harden
#! use sys/dir/countfiles
#! use var/arith
#! use var/local
#! use var/loop

_basename ()
{
  set -- ${1%"${1##*[!/]}"}
  set -- ${1##*/}
  REPLY=${1:-/}
}

_dirname ()
{
  set -- ${1:-.}
  set -- ${1%%"${1##*[!/]}"}

  if not str empty ${1##*/*}
  then
    set -- '.'
  fi

  set -- ${1%/*}
  set -- ${1%%"${1##*[!/]}"}
  REPLY=${1:-/}
}

bot ()
{
  harden -X date
  harden -X grep
  harden -X git
  harden -X wget
  harden -X pandoc

  PS4='[$(date "+%F %T") L${LINENO} e${?}] '
  readonly PS4

  set -x

  if is dir ${modernish_wd}
  then
    git -C ${supported_shells_wd} reset --hard > /dev/null 2>&1
    git -C ${supported_shells_wd} clean -f -x -d :/ > /dev/null 2>&1
    git -C ${modernish_wd} pull > /dev/null 2>&1
  else
    git clone ${modernish_url} ${modernish_wd} > /dev/null 2>&1
  fi

  if lt $(git -C ${modernish_wd} log -1 --format=%ct) $(git -C ${supported_shells_wd} log -1 --format=%ct)
  then
    LOCAL _shell
    BEGIN
      LOOP for _shell in shells
      DO
        countfiles -s ${supported_shells_wd}/trace/${_shell}

        push IFS
        IFS=${CCn}

        case ${_shell} in
        ( bash )    set -- $(git ls-remote --tags --refs ${bash_url} 'refs/tags/bash-*') ;;
        ( busybox ) set -- $(git ls-remote --tags --refs ${busybox_url}) ;;
        ( dash )    set -- $(git ls-remote --tags --refs ${dash_url}) ;;
        ( mksh )    set -- $(wget -q -O - ${mksh_url} | pandoc -f html -t plain | grep -o 'mksh-R.*gz');;
        ( yash )    set -- $(git ls-remote --tags --refs ${yash_url}) ;;
        ( zsh )     set -- $(git ls-remote --tags --refs ${zsh_url} 'refs/tags/zsh-*') ;;
        ( * )       die "Unknow shell: ${_shell}" ;;
        esac

        pop IFS

        set -- $(( ${#} - ${REPLY} ))

        if gt ${1} 0
        then
          MAX_CPU=25 ${supported_shells_wd}/cpulimiter.sh -f 0 -t ${1} -s ${_shell}
        fi
      DONE
    END
  else
    MAX_CPU=75 ${supported_shells_wd}/cpulimiter.sh
  fi

  if not str empty "$(git ls-files --other --directory --exclude-standard)$(git diff --name-only)"
  then
    git -C ${supported_shells_wd} add -A > /dev/null 2>&1
    if str eq ${update:-} modernish
    then
      git -C ${supported_shells_wd} commit -m '[update - trace] New modernish version' > /dev/null 2>&1
    else
      git -C ${supported_shells_wd} commit -m "[update] New trace for: $(for changed in $(git -C ${supported_shells_wd} diff --name-only --cached --diff-filter=AM); do _dirname ${changed}; _basename ${REPLY}; new="${REPLY}${new+,}${new:-}"; done; printf '%s' "${new}")" > /dev/null 2>&1
    fi
    git -C ${supported_shells_wd} pull > /dev/null 2>&1
    git -C ${supported_shells_wd} push > /dev/null 2>&1
  fi
}

main ()
{
  harden -X mkdir
  harden -X cp
  harden -X mv
  harden -X rm

  supported_shells_wd=/opt/bot/supported_shells
  modernish_wd=/opt/modernish
  readonly supported_shells_wd

  if is dir ${supported_shells_wd}
  then
    git -C ${supported_shells_wd} reset --hard > /dev/null 2>&1
    git -C ${supported_shells_wd} clean -f -x -d :/ > /dev/null 2>&1
    git -C ${supported_shells_wd} pull > /dev/null 2>&1
  else
    git clone https://github.com/tiawl/modernish_supported_shells.git ${supported_shells_wd} > /dev/null 2>&1
    git -C ${supported_shells_wd} config user.name 'tiawl-bot' > /dev/null 2>&1
    git -C ${supported_shells_wd} config user.email 'p.tomas431@laposte.net' > /dev/null 2>&1
  fi

  . ${supported_shells_wd}/const.sh

  log_dir=/var/log/${repo}
  log=${log_dir}/bot.log

  readonly log log_dir

  mkdir -p ${log_dir}

  bot "${@}" >> ${log} 2>&1
}

main "${@}"
