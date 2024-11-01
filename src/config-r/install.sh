#!/usr/bin/env bash

set -e

PATH_POST_CREATE_COMMAND=/usr/local/lib/config-r-post-create-command
cp cmd/post-create-command "$PATH_POST_CREATE_COMMAND"
chmod 755 "$PATH_POST_CREATE_COMMAND"

SET_R_LIB_PATHS="$SETRLIBPATHS"
ENSURE_GITHUB_PAT_SET="$ENSUREGITHUBPATSET"
INSTALL_PAK_AND_BIOCMANAGER="$INSTALLPAKANDBIOCMANAGER"
RESTORE_RENV="$RESTORERENV"

if [ "$SET_R_LIB_PATHS" = "true" ]; then
    chmod 755 scripts/r-lib.sh
    scripts/r-lib.sh || {
      echo "Failed to define R library environment variables"
    }
fi

if [ "$ENSURE_GITHUB_PAT_SET" = "true" ]; then
    cp cmd/bashrc-d /usr/local/lib/config-r-bashrc-d
    chmod 755 /usr/local/lib/config-r-bashrc-d
    echo "/usr/local/lib/config-r-bashrc-d" >> "$PATH_POST_CREATE_COMMAND"
    cp cmd/github-pat /usr/local/lib/config-r-github-pat || {
      echo "Failed to copy cmd/github-pat"
    }
    chmod 755 /usr/local/lib/config-r-github-pat
    /usr/local/lib/config-r-github-pat || {
      echo "Failed to run config-r-github-pat"
    }
    echo "/usr/local/lib/config-r-github-pat" >> "$PATH_POST_CREATE_COMMAND" || {
      echo "Failed to add config-r-github-pat to post-create-command"
    }
fi

if [ "$INSTALL_PAK_AND_BIOCMANAGER" = "true" ]; then
    chmod 755 scripts/r-pkg-pak-and-biocmanager
    scripts/r-pkg-pak-and-biocmanager || {
      echo "Failed to install pak and biocmanager"
    }
fi

cp cmd/renv-restore /usr/local/lib/config-r-renv-restore
chmod 755 /usr/local/lib/config-r-renv-restore

if [ "$RESTORE_RENV" = "true" ]; then
    /usr/local/lib/config-r-renv-restore || {
      echo "Failed to restore R packages"
    }
fi

echo " " >> "$PATH_POST_CREATE_COMMAND"
