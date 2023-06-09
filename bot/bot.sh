#! /usr/bin/env modernish
#! use safe
#! use sys/base/mktemp
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

clean ()
{
  if is reg ${log} && gt $(stat -c%s ${log}) 10000000
  then
    rev ${log} >| ${tmp}
    printf '%.10000000s\n' "$(tac ${tmp})" >| ${tmp}
    tac ${tmp} >| ${log}
    rev ${log} >| ${tmp}
    sed '1,/\[e0\] \/usr\/bin\/date +%F %T/d' ${tmp} >| ${log}
  fi
}

bot ()
{
  PS4="[e\${?:-0}] "
  readonly PS4

  set -x
  date '+%F %T'

  if not str in $(git config --includes --get-all --system include.path 2> /dev/null) ~user/.gitconfig
  then
    git config --system --add include.path ~user/.gitconfig > /dev/null 2>&1
  fi

  if is dir ${modernish_wd}
  then
    if not str in $(git config --includes --get-all --system safe.directory 2> /dev/null) ${modernish_wd}
    then
      git config --system --add safe.directory ${modernish_wd} > /dev/null 2>&1
    fi
    git -C ${modernish_wd} reset --hard > /dev/null 2>&1
    git -C ${modernish_wd} clean -f -x -d :/ > /dev/null 2>&1
    git -C ${modernish_wd} pull > /dev/null 2>&1
  else
    git clone ${modernish_url} ${modernish_wd} > /dev/null 2>&1
    if not str in $(git config --includes --get-all --system safe.directory 2> /dev/null) ${modernish_wd}
    then
      git config --system --add safe.directory ${modernish_wd} > /dev/null 2>&1
    fi
  fi

  if gt $(git -C ${modernish_wd} log -1 --format=%ct 2> /dev/null) $(git -C ${wd} log -1 --format=%ct 2> /dev/null)
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
        ( bash )    set -- $(git ls-remote --tags --refs ${bash_url} 'refs/tags/bash-*' 2> /dev/null) ;;
        ( busybox ) set -- $(git ls-remote --tags --refs ${busybox_url} 2> /dev/null) ;;
        ( dash )    set -- $(git ls-remote --tags --refs ${dash_url} 2> /dev/null) ;;
        ( mksh )    set -- $(env http_proxy=$(git config --includes --get http.proxy 2> /dev/null) https_proxy=$(git config --includes --get https.proxy 2> /dev/null) wget -q -O - ${mksh_url} | pandoc -f html -t plain | grep -o 'mksh-R.*gz') ;;
        ( yash )    set -- $(git ls-remote --tags --refs ${yash_url} 2> /dev/null) ;;
        ( zsh )     set -- $(git ls-remote --tags --refs ${zsh_url} 'refs/tags/zsh-*' 2> /dev/null) ;;
        ( * )       die "Unknown shell: ${_shell}" ;;
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

  if not str empty "$(git -C ${wd} ls-files --other --directory --exclude-standard 2> /dev/null)$(git -C ${wd} diff --name-only 2> /dev/null)"
  then
    git -C ${wd} add ${logs} ${readme} > /dev/null 2>&1
    if str eq ${update:-} modernish
    then
      git -C ${wd} commit -m '[update - trace] New modernish version' > /dev/null 2>&1
    else
      git -C ${wd} commit -m "[update] New trace for: $(for changed in $(git -C ${wd} diff --name-only --cached --diff-filter=AM 2> /dev/null); do _dirname ${changed}; _basename ${REPLY}; new="${REPLY}${new+,}${new:-}"; done; printf '%s' "${new}")" > /dev/null 2>&1
    fi
    git -C ${wd} pull > /dev/null 2>&1
    git -C ${wd} push > /dev/null 2>&1
  fi

  { set +x; } 2> /dev/null
}

main ()
{
  wd=$(_dirname ${ME}; chdir ${REPLY}/..; put ${PWD:-"$(pwd -P)"})
  modernish_wd=/opt/modernish
  readonly wd modernish_wd

  . ${wd}/const.sh

  mktemp -C -s
  tmp=${REPLY}
  log_dir=/var/log/bot
  log=${log_dir}/${repo}.log

  readonly tmp log log_dir

  trap 'clean' DIE EXIT

  harden -X mkdir
  harden -X cp
  harden -X mv
  harden -X rm

  harden -X date
  harden -X env
  harden -X grep
  harden -X pandoc
  harden -X rev
  harden -X sed
  harden -X stat
  harden -X tac
  harden -X wget

  if not extern -v -p git > /dev/null 2>&1
  then
    die 'This script needs git utility to run bot when using a proxy.'
  fi

  if not str in $(git config --includes --system --get-all safe.directory 2> /dev/null) ${wd}
  then
    git config --system --add safe.directory ${wd} > /dev/null 2>&1
  fi
  git -C ${wd} reset --hard > /dev/null 2>&1
  git -C ${wd} clean -f -x -d :/ > /dev/null 2>&1
  git -C ${wd} pull > /dev/null 2>&1

  mkdir -p ${log_dir}

  bot "${@}" >> ${log} 2>&1
}

main "${@}"
