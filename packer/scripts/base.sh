#!/bin/bash -x
source /etc/profile

# partition the disk (http://www.rodsbooks.com/gdisk/sgdisk.html)
sgdisk -n 1:0:+128M -t 1:8300 -c 1:"linux-boot" \
       -n 2:0:+32M  -t 2:ef02 -c 2:"bios-boot"  \
       -n 3:0:+1G   -t 3:8200 -c 3:"swap"       \
       -n 4:0:0     -t 4:8300 -c 4:"linux-root" \
       -p $SYSTEMDRIVE

sleep 1

# format partitions, mount swap
printenv
mkswap "$SYSTEMDRIVE""3"
swapon "$SYSTEMDRIVE""3"
mkfs.ext2 "$SYSTEMDRIVE""1"
mkfs.ext4 "$SYSTEMDRIVE""4"

# mount other partitions
mount "$SYSTEMDRIVE""4" "$chroot" && cd "$chroot" && mkdir boot && mount /dev/sda1 boot

# download stage 3, unpack it, delete the stage3 archive file
echo $stage3url
echo $stage3file
echo $stage3current
wget -nv --tries=5 "$stage3url"
tar xpf "$stage3file" && rm "$stage3file"

# prepeare chroot, update env
mount -t proc none "$chroot/proc"
mount --rbind /dev "$chroot/dev"

# copy nameserver information, save build timestamp
cp /etc/resolv.conf "$chroot/etc/"
date -u > "$chroot/etc/vagrant_box_build_time"

# retrieve and extract latest portage tarball
chroot "$chroot" wget --tries=5 "${portageurl}"
chroot "$chroot" tar -xjpf portage-latest.tar.bz2 -C /usr
chroot "$chroot" rm -rf portage-latest.tar.bz2
chroot "$chroot" env-update

# bring up network interface and sshd on boot (Alt. for new systemd naming scheme, enp0s3)
#chroot "$chroot" /bin/bash <<DATAEOF
#cd /etc/conf.d
#sed -i "s/eth0/enp0s3/" /etc/udhcpd.conf
#echo 'config_enp0s3=( "dhcp" )' >> net
#ln -s net.lo /etc/init.d/net.enp0s3
#rc-update add net.enp0s3 default
#rc-update add sshd default
#DATAEOF

# bring up network interface and sshd on boot (for older systemd naming scheme, eth0)
chroot "$chroot" /bin/bash <<DATAEOF
ln -s /dev/null /etc/udev/rules.d/80-net-name-slot.rules
DATAEOF
chroot "$chroot" /bin/bash <<DATAEOF
cd /etc/conf.d
echo 'config_eth0=( "dhcp" )' >> net
ln -s net.lo /etc/init.d/net.eth0
rc-update add net.eth0 default
rc-update add sshd default
DATAEOF

# set fstab
cat <<DATAEOF > "$chroot/etc/fstab"
# <fs>                  <mountpoint>    <type>          <opts>                   <dump/pass>
"$SYSTEMDRIVE""1"               /boot           ext2            noauto,noatime           1 2
"$SYSTEMDRIVE""3"               none            swap            sw                       0 0
"$SYSTEMDRIVE""4"               /               ext4            noatime                  0 1
none                    /dev/shm        tmpfs           nodev,nosuid,noexec      0 0
DATAEOF

# set make options
cat <<DATAEOF > "$chroot/etc/portage/make.conf"
CHOST="$chost"

CFLAGS="-mtune=generic -O2 -pipe"
CXXFLAGS="\${CFLAGS}"

ACCEPT_KEYWORDS="$accept_keywords"
MAKEOPTS="-j$((1 + $nr_cpus)) -l$nr_cpus.5"
EMERGE_DEFAULT_OPTS="-j$nr_cpus --quiet-build=y"
FEATURES="\${FEATURES} parallel-fetch"
USE="nls cjk unicode"

PYTHON_TARGETS="python2_7 python3_2 python3_3"
USE_PYTHON="3.2 2.7"

# english only
LINGUAS="en"

# for X support if needed
INPUT_DEVICES="evdev"
VIDEO_CARDS="virtualbox"

# Additional portage overlays (space char separated)
PORTDIR_OVERLAY="/usr/local/portage"

# Including /usr/local/portage overlay
source "/usr/local/portage/make.conf"
DATAEOF

# Create an empty portage overlay
mkdir -p "$chroot/usr/local/portage"

touch "$chroot/usr/local/portage/make.conf"
chown root:portage "$chroot/usr/local/portage/make.conf"
chmod g+s "$chroot/usr/local/portage/make.conf"
chmod 775 "$chroot/usr/local/portage/make.conf"

mkdir -p "$chroot/usr/local/portage/profiles"
echo "local_repo" >> "$chroot/usr/local/portage/profiles/repo_name"
chown root:portage "$chroot/usr/local/portage" "$chroot/usr/local/portage/profiles/repo_name"
chmod g+s "$chroot/usr/local/portage" "$chroot/usr/local/portage/profiles/repo_name"
chmod 775 "$chroot/usr/local/portage" "$chroot/usr/local/portage/profiles/repo_name"

mkdir -p "$chroot/usr/local/portage/metadata"
echo "masters = gentoo" >> "$chroot/usr/local/portage/metadata/layout.conf"
chown root:portage "$chroot/usr/local/portage/metadata/layout.conf"
chmod g+s "$chroot/usr/local/portage/metadata/layout.conf"
chmod 775 "$chroot/usr/local/portage/metadata/layout.conf"

# This distribution does not like flags described in single files
# all 'package.*', except 'package.keywords', should be directories.
mkdir -p "$chroot/etc/portage/package.license"
mkdir -p "$chroot/etc/portage/package.use"
mkdir -p "$chroot/etc/portage/package.accept_keywords"
mkdir -p "$chroot/etc/portage/package.mask"
mkdir -p "$chroot/etc/portage/package.unmask"

# set localtime
chroot "$chroot" ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime

# set locale
chroot "$chroot" /bin/bash <<DATAEOF
echo LANG=\"$locale\" > /etc/env.d/02locale
echo LANG_ALL=\"$locale\" >> /etc/env.d/02locale
echo LANGUAGE=\"$locale\" >> /etc/env.d/02locale
env-update && source /etc/profile
DATAEOF

# NOTE: LC_ALL, LC_TYPE will be set in vagrant.sh

# update portage tree to most current state
# emerge-webrsync is recommended by Gentoo for first sync
chroot "$chroot" emerge-webrsync
