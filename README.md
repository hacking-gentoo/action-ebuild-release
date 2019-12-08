# action-ebuild-release

Automatically create an ebuild from a template and deploy it to a repository whenever a new
package is released.

## Functionality

Once configured creating a release will trigger the workflow and automatically:
  * create a new ebuild for the released version
  * calculate best possible `KEYWORDS`, if required
  * fetch package archives
  * regenerate manifest files
  * perform QA tests using [repoman](https://wiki.gentoo.org/wiki/Repoman)
  * deploy to an overlay repository
  * create / update a pull request

Automatic pre-release testing can be easily included using
[action-ebuild-test](https://github.com/hacking-gentoo/action-ebuild-test).

## Basic Usage

An example workflow:

```yaml
name: Release Package

on:
  release:
    types: [published, edited]

jobs:
  ebuild:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - uses: hacking-gentoo/action-ebuild-release@next
      with:
        auth_token: ${{ secrets.PR_TOKEN }}
        deploy_key: ${{ secrets.DEPLOY_KEY }}
        overlay_repo: hacking-gentoo/overlay    
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

If you use an empty `KEYWORDS` variable then the best possible keywords, based on the keywords of all dependencies,
will be used.  NOTE: If no dependencies are specified then an empty `KEYWORDS` variable will result in an empty 
`KEYWORDS` variable being used in the final ebuild.

And the usual [metadata.xml](https://devmanual.gentoo.org/ebuild-writing/misc-files/metadata/index.html)

## Configuring `PR_TOKEN`

The above workflow requires a [personal access token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line) be configured for the user running the release action.

This access token will need to be made available to the workflow using the [secrets](https://help.github.com/en/github/automating-your-workflow-with-github-actions/virtual-environments-for-github-actions#creating-and-using-secrets-encrypted-variables)
feature and will be used to authenticate when creating a new pull request.

## Configuring `DEPLOY_KEY`

The above workflow also requires a [deploy key](https://developer.github.com/v3/guides/managing-deploy-keys/#deploy-keys)
be configured for the destination repository.

This deploy key will also need to be made available to the workflow using the [secrets](https://help.github.com/en/github/automating-your-workflow-with-github-actions/virtual-environments-for-github-actions#creating-and-using-secrets-encrypted-variables)
feature.
