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

## Basic Use

### 1. Create a `.gentoo` folder in the root of your repository.

### 2. Create a live ebuild template in the appropriate sub-directory.

`.gentoo/dev-libs/hacking-bash-lib/hacking-bash-lib-9999.ebuild`

```bash
# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="A library script to log output and manage the generated log files"
HOMEPAGE="https://github.com/GITHUB_REPOSITORY"
LICENSE="LGPL-3"

if [[ ${PV} = *9999* ]]; then
    inherit git-r3
    EGIT_REPO_URI="https://github.com/GITHUB_REPOSITORY"
    EGIT_BRANCH="GITHUB_REF"
else
    SRC_URI="https://github.com/GITHUB_REPOSITORY/archive/${PV}.tar.gz -> ${P}.tar.gz"
fi

KEYWORDS=""
IUSE="test"
SLOT="0"

RESTRICT="!test? ( test )"

RDEPEND="app-arch/bzip2
    mail-client/mutt
    sys-apps/util-linux"
DEPEND="test? (
    ${RDEPEND}
    dev-util/bats-assert
    dev-util/bats-file
)"

src_test() {
    bats --tap tests || die "Tests failed"
}

src_install() {
    einstalldocs

    insinto /usr/lib
    doins usr/lib/*
}
```

The special markers `GITHUB_REPOSITORY` and `GITHUB_REF` will be automatically replaced with appropriate values
when the action is executed.

If you use an empty `KEYWORDS` variable then the best possible keywords, based on the keywords of all dependencies,
will be used.  NOTE: If no dependencies are specified then an empty `KEYWORDS` variable will result in an empty 
`KEYWORDS` variable being used in the final ebuild.

### 3. Create a metadata.xml file

`.gentoo/dev-libs/hacking-bash-lib/metadata.xml`

```xml
<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE pkgmetadata SYSTEM "http://www.gentoo.org/dtd/metadata.dtd">

<pkgmetadata>
    <maintainer type="person">
        <email>overlay-maintainer@example.com</email>
        <name>Overlay Maintainer</name>
    </maintainer>
    <upstream>
        <maintainer>
	    <email>default-package-maintainer@example.com</email>
	    <name>Default Package Maintainer</name>
	</maintainer>
	<bugs-to>https://github.com/MADhacking/bash-outlogger/issues</bugs-to>
	<doc>https://github.com/MADhacking/bash-outlogger</doc>
    </upstream>
</pkgmetadata>
```

### 4. Create a GitHub workflow file

`.github/workflows/release-package.yml`

```yaml
name: Release Package

on:
  release:
    types: [published, edited]

jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - uses: hacking-gentoo/action-ebuild-release@v1
      with:
        auth_token: ${{ secrets.PR_TOKEN }}
        deploy_key: ${{ secrets.DEPLOY_KEY }}
        overlay_repo: hacking-gentoo/overlay
```

### 5. (Optional) Create tokens / keys for automatic deployment

#### Configuring `PR_TOKEN`

The above workflow requires a [personal access token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line) be configured for the user running the release action.

This access token will need to be made available to the workflow using the [secrets](https://help.github.com/en/github/automating-your-workflow-with-github-actions/virtual-environments-for-github-actions#creating-and-using-secrets-encrypted-variables)
feature and will be used to authenticate when creating a new pull request.

#### Configuring `DEPLOY_KEY`

The above workflow also requires a [deploy key](https://developer.github.com/v3/guides/managing-deploy-keys/#deploy-keys)
be configured for the destination repository.

This deploy key will also need to be made available to the workflow using the [secrets](https://help.github.com/en/github/automating-your-workflow-with-github-actions/virtual-environments-for-github-actions#creating-and-using-secrets-encrypted-variables)
feature.
