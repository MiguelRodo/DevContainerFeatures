# Dev Container Features

We provide several devcontainer features.

## Example Contents

This repository contains a _collection_ of two Features - `hello` and `color`. These Features serve as simple feature implementations.  Each sub-section below shows a sample `devcontainer.json` alongside example usage of the Feature.

### `git-xet`

Install Git Xet CLI (see [here](https://xethub.com/assets/docs/getting-started/install)).

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/MiguelRodo/DevContainerFeatures/git-xet:1": {
            "version": "latest"
        }
    }
}
```

To log in to XetHub, you'll need to run the following command:

```bash
git xet login -u <xethub-username> -e <xethub-email> -p <xethub-pat> 
```

The above command, with an auto-generated PAT, can be obtaind [here](https://xethub.com/user/settings/pat).


### Install Apptainer

Install Apptainer.

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/MiguelRodo/DevContainerFeatures/apptainer:1": {
            "version": "latest"
        }
    }
}
```
