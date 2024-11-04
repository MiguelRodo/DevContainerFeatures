#!/usr/bin/env bash

set -e

PATH_POST_CREATE_COMMAND=/usr/local/bin/config-bashrc-d-post-create-command
cp cmd/post-create-command "$PATH_POST_CREATE_COMMAND"
chmod 755 "$PATH_POST_CREATE_COMMAND"

SOURCE_BASHRC_D="$SOURCEBASHRCD"

if [ "$SOURCE_BASHRC_D" = "true" ]; then
    cp cmd/bashrc-d /usr/local/bin/config-bashrc-d-post-create-command
    chmod 755 /usr/local/bin/config-bashrc-d-post-create-command
    echo "/usr/local/bin/config-bashrc-d-post-create-command" >> "$PATH_POST_CREATE_COMMAND"
fi

echo " " >> "$PATH_POST_CREATE_COMMAND"
