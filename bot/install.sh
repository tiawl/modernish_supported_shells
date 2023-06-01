#! /usr/bin/env modernish
#! use sys/cmd/harden
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
  # Check bot dependencies before installing
  harden -X chown
  harden -X cp
  harden -X date
  harden -X env
  harden -X envsubst
  harden -X grep
  harden -X git
  harden -X mkdir
  harden -X mv
  harden -X pandoc
  harden -X pwd
  harden -X rev
  harden -X rm
  harden -X sed
  harden -X stat
  harden -X systemctl
  harden -X tac
  harden -X wget

  wd=$(_dirname ${ME}; chdir ${REPLY}/..; pwd -P)
  readonly wd

  sudo -E ${wd}/bot/_install.sh
}

main "${@}"
