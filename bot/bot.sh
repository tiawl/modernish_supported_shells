#! /usr/bin/env modernish
#! use safe
#! use sys/base/rev
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
  PS4="[e\${?:-0}] "
  readonly PS4

  set -x
  date '+%F %T'

  if is dir ${modernish_wd}
  then
    git -C ${modernish_wd} reset --hard > /dev/null 2>&1
    git -C ${modernish_wd} clean -f -x -d :/ > /dev/null 2>&1
    git -C ${modernish_wd} pull > /dev/null 2>&1
  else
    git clone ${modernish_url} ${modernish_wd} > /dev/null 2>&1
  fi

  if gt $(git -C ${modernish_wd} log -1 --format=%ct) $(git -C ${wd} log -1 --format=%ct)
  then
    MAX_CPU=75 ${wd}/cpulimiter.sh
    update=modernish
  else
    LOCAL _shell
    BEGIN
      LOOP for --split=' ' _shell in ${shells}
      DO
        countfiles -s ${wd}/trace/${_shell}

        push IFS
        IFS=${CCn}

        case ${_shell} in
        ( bash )    set -- $(git ls-remote --tags --refs ${bash_url} 'refs/tags/bash-*') ;;
        ( busybox ) set -- $(git ls-remote --tags --refs ${busybox_url}) ;;
        ( dash )    set -- $(git ls-remote --tags --refs ${dash_url}) ;;
        ( mksh )    set -- $(wget -q -O - ${mksh_url} | pandoc -f html -t plain | grep -o 'mksh-R.*gz') ;;
        ( yash )    set -- $(git ls-remote --tags --refs ${yash_url}) ;;
        ( zsh )     set -- $(git ls-remote --tags --refs ${zsh_url} 'refs/tags/zsh-*') ;;
        ( * )       die "Unknow shell: ${_shell}" ;;
        esac

        pop IFS

        set -- $(( ${#} - ${REPLY} ))

        if gt ${1} 0
        then
          MAX_CPU=25 ${wd}/cpulimiter.sh -f 0 -t ${1} -s ${_shell}
        fi
      DONE
    END
  fi

  if not str empty "$(git -C ${wd} ls-files --other --directory --exclude-standard)$(git -C ${wd} diff --name-only)"
  then
    git -C ${wd} add ${logs} ${readme} > /dev/null 2>&1
    if str eq ${update:-} modernish
    then
      git -C ${wd} commit -m '[update - trace] New modernish version' > /dev/null 2>&1
    else
      git -C ${wd} commit -m "[update] New trace for: $(for changed in $(git -C ${wd} diff --name-only --cached --diff-filter=AM); do _dirname ${changed}; _basename ${REPLY}; new="${REPLY}${new+,}${new:-}"; done; printf '%s' "${new}")" > /dev/null 2>&1
    fi
    git -C ${wd} pull > /dev/null 2>&1
    git -C ${wd} push > /dev/null 2>&1
  fi
}

main ()
{
  harden -X mkdir
  harden -X cp
  harden -X mv
  harden -X rm

  harden -X cut
  harden -X date
  harden -X grep
  harden -X git
  harden -X pandoc
  harden -X pwd
  harden -X wget

  wd=$(_dirname ${ME}; chdir ${REPLY}; pwd -P)/..
  modernish_wd=/opt/modernish
  readonly wd modernish_wd

  . ${wd}/const.sh

  if str in $(git -C ${wd} config --list) http.proxy=
  then
    git -C ${wd} config --unset http.proxy > /dev/null 2>&1
  fi
  if str in $(git -C ${wd} config --list) https.proxy=
  then
    git -C ${wd} config --unset https.proxy > /dev/null 2>&1
  fi
  if not is empty ${http_proxy:-}
  then
    git -C ${wd} config http.proxy ${http_proxy#http://} > /dev/null 2>&1
  fi
  if not is empty ${https_proxy:-}
  then
    git -C ${wd} config https.proxy ${https_proxy#http://} > /dev/null 2>&1
  fi
  git -C ${wd} reset --hard > /dev/null 2>&1
  git -C ${wd} clean -f -x -d :/ > /dev/null 2>&1
  git -C ${wd} pull > /dev/null 2>&1

  log_dir=/var/log/${repo}
  log=${log_dir}/bot.log

  readonly log log_dir

  mkdir -p ${log_dir}

  bot "${@}" >> ${log} 2>&1

  rev ${log} | cut -b -10000000 | rev > ${log}
}

main "${@}"
