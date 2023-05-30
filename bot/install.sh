#! /usr/bin/env modernish
#! use safe

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

main ()
{
  wd=$(_dirname ${ME}; chdir ${REPLY}/..; pwd -P)
  readonly wd

  sudo -E ${wd}/bot/_install.sh
}

main "${@}"
