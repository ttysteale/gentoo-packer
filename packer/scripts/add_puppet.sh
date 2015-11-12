#!/bin/bash
source /etc/profile

# install Puppet
chroot "$chroot" /bin/bash <<DATAEOF
RUBY_TARGETS="ruby20" emerge puppet
DATAEOF
