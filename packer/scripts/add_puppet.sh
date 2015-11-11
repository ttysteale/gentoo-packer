#!/bin/bash
source /etc/profile

# install Puppet
chroot "$chroot" /bin/bash <<DATAEOF
emerge puppet
DATAEOF