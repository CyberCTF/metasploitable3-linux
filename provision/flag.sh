#!/bin/sh
# Places the player's flag (CTF_FLAG_MAIN, given by the launcher) where only root reads it:
# getting it means a root shell on the machine. Without one (CI, a run by hand) the
# development flag. Runs before the build, which reboots the machine when it ends.
set -eu
dev='FLAG{dev-metasploitable3-linux}'
umask 077
printf '%s\n' "${CTF_FLAG_MAIN:-$dev}" > /root/flag.txt
chown root:root /root/flag.txt
chmod 400 /root/flag.txt
