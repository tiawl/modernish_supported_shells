#!/bin/sh

repo='supported-shells'

logs=${WD:-${wd}}/trace
readme=${WD:-${wd}}/README.md

shells='bash busybox dash mksh yash zsh'

bash_url='https://git.savannah.gnu.org/git/bash.git'
busybox_url='https://git.busybox.net/busybox'
dash_url='https://git.kernel.org/pub/scm/utils/dash/dash.git'
mksh_url='http://www.mirbsd.org/MirOS/dist/mir/mksh/'
modernish_url='https://github.com/modernish/modernish.git'
yash_url='https://scm.osdn.net/gitroot/yash/yash.git'
zsh_url='https://github.com/zsh-users/zsh.git'

readonly repo shells \
         logs readme \
         bash_url busybox_url dash_url mksh_url modernish_url yash_url zsh_url
