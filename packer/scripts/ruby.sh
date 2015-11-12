#!/bin/bash
source /etc/profile

cat <<DATAEOF >> "$chroot/etc/portage/make.conf"
# use ruby 1.9
RUBY_TARGETS="ruby19"
DATAEOF

cat <<DATAEOF >> "$chroot/etc/portage/package.accept_keywords/ruby"
dev-util/ragel ~x86 ~amd64
DATAEOF

chroot "$chroot" /bin/bash <<DATAEOF
env-update && source /etc/profile
emerge --autounmask-write ruby:2.0
etc-update --automode -5
emerge ruby:2.0
eselect ruby set ruby20
DATAEOF
