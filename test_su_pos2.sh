#!/bin/bash
su -s /bin/bash root -c 'echo "0: $0"; echo "1: $1"; echo "2: $2"; exec echo "args:" "$@"' "config_file" "arg1" "arg2"
