#!/bin/bash
bash -c 'echo "0: $0"; echo "1: $1"; echo "2: $2"; exec echo "args:" "$@"' "config_file" "-i" "input.mmd" "-o" "output.png"
