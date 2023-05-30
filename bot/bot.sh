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

_git ()
{
  git -c include.path=~user/.gitconfig "${@}"
}

bot ()
{
  PS4="[e\${?:-0}] "
  readonly PS4

  set -x
  date '+%F %T'

  if is dir ${modernish_wd}
  then
    if not str in $(git config --get-all --system safe.directory) safe.directory=${modernish_wd}
    then
      git config --system --add safe.directory ${modernish_wd} > /dev/null 2>&1
    fi
    _git -C ${modernish_wd} reset --hard > /dev/null 2>&1
    _git -C ${modernish_wd} clean -f -x -d :/ > /dev/null 2>&1
    _git -C ${modernish_wd} pull > /dev/null 2>&1
  else
    _git clone ${modernish_url} ${modernish_wd} > /dev/null 2>&1
    if not str in $(git config --get-all --system safe.directory) ${modernish_wd}
    then
      git config --system --add safe.directory ${modernish_wd} > /dev/null 2>&1
    fi
  fi

  if gt $(_git -C ${modernish_wd} log -1 --format=%ct) $(_git -C ${wd} log -1 --format=%ct)
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
        ( bash )    set -- $(_git ls-remote --tags --refs ${bash_url} 'refs/tags/bash-*') ;;
        ( busybox ) set -- $(_git ls-remote --tags --refs ${busybox_url}) ;;
        ( dash )    set -- $(_git ls-remote --tags --refs ${dash_url}) ;;
        ( mksh )    set -- $(http_proxy=$(_git config --get http.proxy) https_proxy=$(_git config --get https.proxy) wget -q -O - ${mksh_url} | pandoc -f html -t plain | grep -o 'mksh-R.*gz') ;;
        ( yash )    set -- $(_git ls-remote --tags --refs ${yash_url}) ;;
        ( zsh )     set -- $(_git ls-remote --tags --refs ${zsh_url} 'refs/tags/zsh-*') ;;
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

  if not str empty "$(_git -C ${wd} ls-files --other --directory --exclude-standard)$(_git -C ${wd} diff --name-only)"
  then
    _git -C ${wd} add ${logs} ${readme} > /dev/null 2>&1
    if str eq ${update:-} modernish
    then
      _git -C ${wd} commit -m '[update - trace] New modernish version' > /dev/null 2>&1
    else
      _git -C ${wd} commit -m "[update] New trace for: $(for changed in $(_git -C ${wd} diff --name-only --cached --diff-filter=AM); do _dirname ${changed}; _basename ${REPLY}; new="${REPLY}${new+,}${new:-}"; done; printf '%s' "${new}")" > /dev/null 2>&1
    fi
    _git -C ${wd} pull > /dev/null 2>&1
    _git -C ${wd} push > /dev/null 2>&1
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
  harden -X pandoc
  harden -X pwd
  harden -X wget

  if not extern -v -p git > /dev/null 2>&1
  then
    die 'This script needs git utility to run bot when using a proxy.'
  fi

  wd=$(_dirname ${ME}; chdir ${REPLY}/..; pwd -P)
  modernish_wd=/opt/modernish
  readonly wd modernish_wd

  . ${wd}/const.sh

  if not str in $(git config --system --get-all safe.directory) ${wd}
  then
    git config --system --add safe.directory ${wd} > /dev/null 2>&1
  fi
  _git -C ${wd} reset --hard > /dev/null 2>&1
  _git -C ${wd} clean -f -x -d :/ > /dev/null 2>&1
  _git -C ${wd} pull > /dev/null 2>&1

  log_dir=/var/log/${repo}
  log=${log_dir}/bot.log

  readonly log log_dir

  mkdir -p ${log_dir}

  bot "${@}" >> ${log} 2>&1

  rev ${log} | cut -b -10000000 | rev > ${log}
}

main "${@}"
