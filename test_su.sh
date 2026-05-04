#!/bin/bash
USERNAME=$(whoami)
su -s /bin/bash "$USERNAME" -c 'echo "0: $0"; echo "1: $1"; echo "2: $2"' "myconfig" "arg1" "arg2"
