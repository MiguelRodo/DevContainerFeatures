#!/usr/bin/env bash
set -e

# install scripts
# ---------------------

source scripts/hf-install.sh

source scripts/git-auth.sh

source scripts/git-clone.sh

source scripts/workspace-add.sh

source scripts/shellrc-config.sh

# run scripts
# ---------------------

# install Hugging Face
if [ "$INSTALLHUGGINGFACE" = "true" ]; then
  repos-hf-install --hf-scope "$HUGGINGFACEINSTALLSCOPE"
fi

