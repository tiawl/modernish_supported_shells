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

_autoreconf ()
{
  unset -v status
  if ! autoreconf "${@}" > /dev/null 2>&1
  then
    status='1'
  fi
  IFS=' '
  printf "%s \033[38;5;$(( 2 - ${status:-0} ))m%bautoreconf %s%b\n" "${PS4}" "${bold}" "${*}" "${reset}"
  IFS="${old_ifs}"
  return "${status:-0}"
}

_make ()
{
  unset -v status
  if ! make "${@}" > /dev/null 2>&1
  then
    status='1'
  fi
  IFS=' '
  printf "%s \033[38;5;$(( 2 - ${status:-0} ))m%bmake %s%b\n" "${PS4}" "${bold}" "${*}" "${reset}"
  IFS="${old_ifs}"
  return "${status:-0}"
}

_eval ()
{
  unset -v status
  if ! eval "${@}" > /dev/null 2>&1
  then
    status='1'
  fi
  IFS=' '
  printf "%s \033[38;5;$(( 2 - ${status:-0} ))m%b%s%b\n" "${PS4}" "${bold}" "${*}" "${reset}"
  IFS="${old_ifs}"
  return "${status:-0}"
}

_mv ()
{
  unset -v status
  if ! mv "${@}" > /dev/null 2>&1
  then
    status='1'
  fi
  IFS=' '
  printf "%s \033[38;5;$(( 2 - ${status:-0} ))m%bmv %s%b\n" "${PS4}" "${bold}" "${*}" "${reset}"
  IFS="${old_ifs}"
  return "${status:-0}"
}

install_bash ()
{
  cd "${MOUNT}/bash"
  _git -C "${MOUNT}/bash" reset --hard
  _git -C "${MOUNT}/bash" clean -f -x -d :/
  _git -C "${MOUNT}/bash" checkout "${1}"
  _eval "${MOUNT}/bash"/configure --prefix=/usr --without-bash-malloc --with-installed-readline
  _make -C "${MOUNT}/bash"
  _make -C "${MOUNT}/bash" install
}

install_busybox ()
{
  cd "${MOUNT}/busybox"
  tmp="$(mktemp)"
  readonly tmp
  _git -C "${MOUNT}/busybox" reset --hard
  _git -C "${MOUNT}/busybox" clean -f -x -d :/
  _git -C "${MOUNT}/busybox" checkout "${1}"
  _make -C "${MOUNT}/busybox" defconfig
  if [ "$(printf '1_24_2\n%s\n' "${1}" | sort -V -r | head -n 1)" = '1_24_2' ]
  then
    sed 's/^\(CONFIG_FEATURE_INETD_RPC\)=y$/# \1 is not set/g' "${MOUNT}/busybox/.config" > "${tmp}"
    _mv --force "${tmp}" "${MOUNT}/busybox/.config"
    sed ':begin;N;s/^# else\n#  include <utmpx\.h>$/\0\n#  include <utmp.h>\n#  if defined _PATH_UTMP \&\& !defined _PATH_UTMPX\n#    define _PATH_UTMPX _PATH_UTMP\n# endif/;tbegin;P;D' "${MOUNT}/busybox/include/libbb.h" > "${tmp}"
    _mv --force "${tmp}" "${MOUNT}/busybox/include/libbb.h"
  fi
  if [ "$(printf '1_23_2\n%s\n' "${1}" | sort -V -r | head -n 1)" = '1_23_2' ]
  then
    sed 'N;N;s/^\(#ifdef HAVE_NET_ETHERNET_H\n\)\(# include <net\/ethernet\.h>\n\)\(#endif\)$/\/\/ \1\/\/ \2\/\/ \3/' "${MOUNT}/busybox/networking/ifplugd.c" > "${tmp}"
    _mv --force "${tmp}" "${MOUNT}/busybox/networking/ifplugd.c"
  elif [ "$(printf '1_18_5\n%s\n' "${1}" | sort -V -r | head -n 1)" = '1_18_5' ]
  then
    sed 's/^#include <net\/ethernet\.h>$/\/\/ \0/' "${MOUNT}/busybox/networking/ifplugd.c" > "${tmp}"
    _mv --force "${tmp}" "${MOUNT}/busybox/networking/ifplugd.c"
  fi
  if [ "$(printf '1_21_1\n%s\n' "${1}" | sort -V -r | head -n 1)" = '1_21_1' ]
  then
    sed 's/^# include <net\/if_slip\.h>$/# include <linux\/if_slip.h>/' "${MOUNT}/busybox/networking/ifconfig.c" > "${tmp}"
    _mv --force "${tmp}" "${MOUNT}/busybox/networking/ifconfig.c"
    sed 's/^#include <net\/if_packet\.h>$/\/\/ \0/' "${MOUNT}/busybox/networking/libiproute/iplink.c" > "${tmp}"
    _mv --force "${tmp}" "${MOUNT}/busybox/networking/libiproute/iplink.c"
  fi
  if [ "$(printf '1_20_2\n%s\n' "${1}" | sort -V -r | head -n 1)" = '1_20_2' ]
  then
    sed 's/_PATH_VARRUN"/"\/var\/run\//' "${MOUNT}/busybox/networking/ifplugd.c" > "${tmp}"
    _mv --force "${tmp}" "${MOUNT}/busybox/networking/ifplugd.c"
  fi
  if [ "$(printf '1_19_4\n%s\n' "${1}" | sort -V -r | head -n 1)" = '1_19_4' ]
  then
    sed 's/^#include <linux\/ext2_fs\.h>$/#include <ext2fs\/ext2_fs.h>/;s/s_log_frag_size/s_log_cluster_size/;s/s_frags_per_group/s_clusters_per_group/;s/EXT2_FEATURE_COMPAT_RESIZE_INO/\0DE/' "${MOUNT}/busybox/util-linux/mkfs_ext2.c" > "${tmp}"
    _mv --force "${tmp}" "${MOUNT}/busybox/util-linux/mkfs_ext2.c"
    sed 's/^\(CONFIG_FEATURE_MOUNT_NFS\)=y$/# \1 is not set/g' "${MOUNT}/busybox/.config" > "${tmp}"
    _mv --force "${tmp}" "${MOUNT}/busybox/.config"
  fi
  if [ "${1}" = '1_19_1' ]
  then
    sed 's/^#include "libbb\.h"$/\0\n#ifdef HAVE_MNTENT_H/;s/^#ifdef HAVE_MNTENT_H$//' "${MOUNT}/busybox/libbb/match_fstype.c" > "${tmp}"
    _mv --force "${tmp}" "${MOUNT}/busybox/libbb/match_fstype.c"
  fi
  _make -C "${MOUNT}/busybox" busybox
  _make -C "${MOUNT}/busybox" CONFIG_PREFIX=/usr install
}

install_dash ()
{
  cd "${MOUNT}/dash"
  _git -C "${MOUNT}/dash" reset --hard
  _git -C "${MOUNT}/dash" clean -f -x -d :/
  _git -C "${MOUNT}/dash" checkout "${1}"
  if [ -f "${MOUNT}/dash"/autogen.sh ]
  then
    _eval "${MOUNT}/dash"/autogen.sh
  else
    _autoreconf --force --install
  fi
  _eval "${MOUNT}/dash"/configure --prefix=/usr
  _make -C "${MOUNT}/dash"
  _make -C "${MOUNT}/dash" install
}

install_mksh ()
{
  cd "${MOUNT}/${1}"
  chmod 700 "${MOUNT}/${1}"/Build.sh
  _eval "${MOUNT}/${1}"/Build.sh
  install -c -s -o root -m 555 "${MOUNT}/${1}"/mksh /usr/bin/mksh
}

install_yash ()
{
  cd "${MOUNT}/yash"
  tmp="$(mktemp)"
  readonly tmp
  _git -C "${MOUNT}/yash" reset --hard
  _git -C "${MOUNT}/yash" clean -f -x -d :/
  _git -C "${MOUNT}/yash" checkout "${1}"
  _eval "${MOUNT}/yash"/configure --prefix=/usr
  if [ "$(printf '2.44\n%s\n' "${1}" | sort -V -r | head -n 1)" = '2.44' ]
  then
    if [ -f "${MOUNT}/yash/arith.c" ]
    then
      sed 's/extern int iswdigit(wint_t wc);/\/\/\0/g' "${MOUNT}/yash/arith.c" > "${tmp}"
      _mv --force "${tmp}" "${MOUNT}/yash/arith.c"
    fi
  fi
  if [ "${1}" = '2.33' ]
  then
    sed 's/#define YASH_SIG_H/\0\n#include <sys\/types.h>\n/g' "${MOUNT}/yash/sig.h" > "${tmp}"
    _mv --force "${tmp}" "${MOUNT}/yash/sig.h"
  fi
  if [ "$(printf '2.31\n%s\n' "${1}" | sort -V -r | head -n 1)" = '2.31' ]
  then
    _make -C "${MOUNT}/yash"
  elif [ "$(printf '2.43\n%s\n' "${1}" | sort -V -r | head -n 1)" = '2.43' ]
  then
    _make -C "${MOUNT}/yash" yash tester mofiles
  else
    _make -C "${MOUNT}/yash" yash share/config tester mofiles
  fi
  if [ "$(printf '2.15\n%s\n' "${1}" | sort -V -r | head -n 1)" = '2.15' ]
  then
    _make -C "${MOUNT}/yash" install
  else
    _make -C "${MOUNT}/yash" install-binary
  fi
}

install_zsh ()
{
  cd "${MOUNT}/zsh"
  tmp="$(mktemp)"
  readonly tmp
  _git -C "${MOUNT}/zsh" reset --hard
  _git -C "${MOUNT}/zsh" clean -f -x -d :/
  _git -C "${MOUNT}/zsh" checkout "${1}"
  _eval "${MOUNT}/zsh"/Util/preconfig
  sed 's/^\(AC_PROG_LN\)  /\1_S/g' "${MOUNT}/zsh/configure.ac" > "${tmp}"
  _mv --force "${tmp}" "${MOUNT}/zsh/configure.ac"
  sed 's/@LN@/@LN_S@/g' "${MOUNT}/zsh/Src/Makefile.in" > "${tmp}"
  _mv --force "${tmp}" "${MOUNT}/zsh/Src/Makefile.in"
  if [ ! -f "${MOUNT}/zsh"/configure ]
  then
    _autoreconf --force --install
  fi
  _eval "${MOUNT}/zsh"/configure --prefix=/usr
  if [ -d "${MOUNT}/zsh/Doc" ]
  then
    printf 'all:\n' > "${MOUNT}/zsh/Doc/Makefile"
  fi
  _make -C "${MOUNT}/zsh"
  _make -C "${MOUNT}/zsh" install.bin install.modules install.fns
}

main ()
{
  set -e
  CDPATH=
  old_ifs="${IFS}"
  color="$(printf '%b' "\033[38;5;${1}m")"
  shift
  bold="$(printf '%b' '\033[1m')"
  reset="$(printf '%b' '\033[m')"
  PS4="[${color}${bold}${DOCKER_NAME}${reset}] >"

  readonly old_ifs PS4

  case "${1}" in
  ( bash )    install_bash    "${2}" ;;
  ( busybox ) install_busybox "${2}" ;;
  ( dash )    install_dash    "${2}" ;;
  ( mksh )    install_mksh    "${2}" ;;
  ( yash )    install_yash    "${2}" ;;
  ( zsh )     install_zsh     "${2}" ;;
  ( * )                              ;;
  esac
}

main "${@}"
