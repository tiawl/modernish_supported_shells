#!/bin/sh

_git ()
{
  unset -v status
  if ! git "${@}" > /dev/null 2>&1
  then
    status='1'
  fi
  IFS=' '
  printf "%s \033[38;5;$(( 2 - ${status:-0} ))m%bgit %s%b\n" "${PS4}" "${bold}" "${*}" "${reset}"
  IFS="${old_ifs}"
  return "${status:-0}"
}

_wget ()
{
  unset -v status
  if ! wget "${@}" > /dev/null 2>&1
  then
    status='1'
  fi
  IFS=' '
  printf "%s \033[38;5;$(( 2 - ${status:-0} ))m%bwget %s%b\n" "${PS4}" "${bold}" "${*}" "${reset}"
  IFS="${old_ifs}"
  return "${status:-0}"
}

_tar ()
{
  unset -v status
  if ! tar "${@}" > /dev/null 2>&1
  then
    status='1'
  fi
  IFS=' '
  printf "%s \033[38;5;$(( 2 - ${status:-0} ))m%btar %s%b\n" "${PS4}" "${bold}" "${*}" "${reset}"
  IFS="${old_ifs}"
  return "${status:-0}"
}

_gzip ()
{
  unset -v status
  if ! gzip "${@}" > /dev/null 2>&1
  then
    status='1'
  fi
  IFS=' '
  printf "%s \033[38;5;$(( 2 - ${status:-0} ))m%bgzip %s%b\n" "${PS4}" "${bold}" "${*}" "${reset}"
  IFS="${old_ifs}"
  return "${status:-0}"
}

_cpio ()
{
  unset -v status
  if ! cpio "${@}" > /dev/null 2>&1
  then
    status='1'
  fi
  IFS=' '
  printf "%s \033[38;5;$(( 2 - ${status:-0} ))m%bcpio %s%b\n" "${PS4}" "${bold}" "${*}" "${reset}"
  IFS="${old_ifs}"
  return "${status:-0}"
}

main ()
{
  color="$(printf '%b' '\033[38;5;244m')"
  bold="$(printf '%b' '\033[1m')"
  reset="$(printf '%b' '\033[m')"
  PS4="[${color}${bold}${DOCKER_NAME}${reset}] >"
  old_ifs="${IFS}"
  tmp="$(mktemp)"
  from="${1}"
  to="${2}"
  ushells="${3}"

  . "${CONSTANTS}"

  readonly old_ifs tmp

  case " ${ushells} " in
  ( *' bash '* ) _git clone "${bash_url}" "${MOUNT}/bash" & ;;
  esac

  case " ${ushells} " in
  ( *' busybox '* ) _git clone "${busybox_url}" "${MOUNT}/busybox" & ;;
  esac

  case " ${ushells} " in
  ( *' dash '* ) _git clone "${dash_url}" "${MOUNT}/dash" & ;;
  esac

  case " ${ushells} " in
  ( *' busybox '*|*' bash '*|*' dash '*|*' mksh '*|*' yash '*|*' zsh '* )
    _git clone "${modernish_url}" "${MOUNT}/modernish" & ;;
  esac

  case " ${ushells} " in
  ( *' yash '* ) _git clone "${yash_url}" "${MOUNT}/yash" & ;;
  esac

  case " ${ushells} " in
  ( *' zsh '* ) _git clone "${zsh_url}" "${MOUNT}/zsh" & ;;
  esac

  case " ${ushells} " in
  ( *' mksh '* )
    mksh_R_urls="$(lynx --dump "${mksh_url}" | grep -E -o "${mksh_url}mksh-R.*gz" | sort -V -r)"

    readonly mksh_R_urls

    for mksh_R_url in ${mksh_R_urls}
    do
      if [ ${to} -gt 0 ]
      then
        to="$(( ${to} - 1 ))"
      else
        break
      fi
      if [ ${from} -gt 0 ]
      then
        from="$(( ${from} - 1 ))"
        continue
      fi
      mksh_R_archive="${mksh_R_url#"${mksh_url}"}"
      while :
      do
        if _wget -q -P "${MOUNT}" "${mksh_R_url}"
        then
          break
        fi
      done
      if [ "${mksh_R_archive#"${mksh_R_archive%????}"}" = '.tgz' ]
      then
        _tar -xzf "${MOUNT}/${mksh_R_archive}" -C "${MOUNT}"
        mv --force "${MOUNT}/mksh" "${MOUNT}/${mksh_R_archive%.tgz}"
        rm -f "${MOUNT}/${mksh_R_archive}"
      elif [ "${mksh_R_archive#"${mksh_R_archive%????????}"}" = '.cpio.gz' ]
      then
        _gzip --decompress "${MOUNT}/${mksh_R_archive}"
        _cpio --extract -D "${MOUNT}" -d < "${MOUNT}/${mksh_R_archive%.gz}"
        mv --force "${MOUNT}/mksh" "${MOUNT}/${mksh_R_archive%.cpio.gz}"
        rm -f "${MOUNT}/${mksh_R_archive%.gz}"
      fi
    done

    unset -v mksh_R_url mksh_R_archive ;;
  esac

  wait
}

main "${@}"
