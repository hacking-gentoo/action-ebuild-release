# action-ebuild-release

Automatically create an ebuild from a template and deploy it to a repository whenever a new
package is released.

## Functionality

Once configured creating a release will trigger the workflow and automatically:
  * create a new ebuild for the released version
  * fetch package archives
  * regenerate manifest files
  * perform QA tests using [repoman](https://wiki.gentoo.org/wiki/Repoman)
  * deploy to an overlay repository

Automatic pre-release testing can be easily included using
[action-ebuild-test](https://github.com/hacking-gentoo/action-ebuild-test).

## Basic Usage

An example workflow:

```yaml
name: Release Package

on:
  release:
    types: [published]

jobs:
  ebuild:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - uses: hacking-gentoo/action-ebuild-release@master
      with:
        overlay: hacking-actions/overlay-playground    
      env:
        GHA_DEPLOY_KEY: ${{ secrets.GHA_DEPLOY_KEY }}
```

You will also need to create an ebuild template:

```bash
# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="A test package"
HOMEPAGE="https://github.com/hacking-actions/test-package"
LICENSE="MIT"

if [[ ${PV} = *9999* ]]; then
    inherit git-r3
    EGIT_REPO_URI="https://github.com/GITHUB_REPOSITORY"
    EGIT_BRANCH="GITHUB_REF"
else
    SRC_URI="https://github.com/GITHUB_REPOSITORY/archive/${P}.tar.gz"
fi

KEYWORDS="amd64 x86"
SLOT="0"

RDEPEND=""
DEPEND=""

src_install() {
    ...
}
```

And the usual [metadata.xml](https://devmanual.gentoo.org/ebuild-writing/misc-files/metadata/index.html)

## Configuring `GHA_DEPLOY_KEY`

The above workflow also requires a [deploy key](https://developer.github.com/v3/guides/managing-deploy-keys/#deploy-keys)
be configured for the destination repository.

This deploy key will need to be made available to the workflow using the [secrets](https://help.github.com/en/github/automating-your-workflow-with-github-actions/virtual-environments-for-github-actions#creating-and-using-secrets-encrypted-variables)
feature.
