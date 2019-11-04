#!/usr/bin/env bash
set -e

function die()
{
    echo "::error::$1"
    echo "------------------------------------------------------------------------------------------------------------------------"
    exit 1
}

[[ ${GITHUB_REF} = refs/heads/* ]] && git_branch="${GITHUB_REF##*/}"
[[ ${GITHUB_REF} = refs/tags/* ]] &&git_tag="${GITHUB_REF##*/}"

cat << END
------------------------------------------------------------------------------------------------------------------------
                      _   _                       _           _ _     _                 _                     
                     | | (_)                     | |         (_) |   | |               | |                    
            __ _  ___| |_ _  ___  _ __ ______ ___| |__  _   _ _| | __| |______ _ __ ___| | ___  __ _ ___  ___ 
           / _\` |/ __| __| |/ _ \| '_ \______/ _ \ '_ \| | | | | |/ _\` |______| '__/ _ \ |/ _ \/ _\` / __|/ _ \\
          | (_| | (__| |_| | (_) | | | |    |  __/ |_) | |_| | | | (_| |      | | |  __/ |  __/ (_| \__ \  __/
           \__,_|\___|\__|_|\___/|_| |_|     \___|_.__/ \__,_|_|_|\__,_|      |_|  \___|_|\___|\__,_|___/\___|
 
          https://github.com/hacking-gentoo/action-ebuild-release                         (c) 2019 Max Hacking 
------------------------------------------------------------------------------------------------------------------------
GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
GITHUB_REF=${GITHUB_REF}
git_branch=${git_branch}
git_tag=${git_tag}
------------------------------------------------------------------------------------------------------------------------
END


# Check for a GITHUB_WORKSPACE env variable
[[ -z "${GITHUB_WORKSPACE}" ]] && die "Must set GITHUB_WORKSPACE in env"
cd "${GITHUB_WORKSPACE}" || exit 2

# Check for an overlay
[[ -z "${INPUT_OVERLAY}" ]] && die "Must set overlay input"

# Check for a tag
[[ -z "${GITHUB_REF}" ]] && die "Expecting GITHUB_REF to be a tag"

# Check for repository deploy key.
[[ -z "${GHA_DEPLOY_KEY}" ]] && die "Must set GHA_DEPLOY_KEY"

# If there isn't a .gentoo directory in the base of the workspace then bail
[[ -d .gentoo ]] || die "No .gentoo directory in workspace root"

# Find the ebuild to test and strip the .gentoo/ prefix 
# e.g. dev-libs/hacking-bash-lib/hacking-bash-lib-9999.ebuild
ebuild_path=$(find .gentoo -iname '*-9999.ebuild' | head -1)
ebuild_path="${ebuild_path#*/}"
[[ -z "${ebuild_path}" ]] && die "Unable to find a template ebuild"

# Calculate the ebuild name e.g. hacking-bash-lib-9999.ebuild
ebuild_name="${ebuild_path##*/}"
[[ -z "${ebuild_name}" ]] && die "Unable to calculate ebuild name"

# Calculate the ebuild package name e.g. hacking-bash-lib
ebuild_pkg="${ebuild_path%-*}"
ebuild_pkg="${ebuild_pkg##*/}"
[[ -z "${ebuild_pkg}" ]] && die "Unable to calculate ebuild package"

# Calculate the ebuild package category
ebuild_cat="${ebuild_path%%/*}"
[[ -z "${ebuild_cat}" ]] && die "Unable to calculate ebuild category"

# Work out from the tag what version we are releasing.
# e.g. hacking-bash-lib-1.0.0
ebuild_ver="${GITHUB_REF##*/}"
[[ ${ebuild_ver} =~ ^${ebuild_pkg}-.* ]] || die "Unexpected release version - ${ebuild_ver}"

# Work out the version number only
ebuild_numver="${ebuild_ver#${ebuild_pkg}-}"

# Display our findings thus far
echo "Located ebuild at ${ebuild_path}"
echo "  in category ${ebuild_cat}"
echo "    for ${ebuild_pkg}"
echo "      version ${ebuild_ver} - ${ebuild_numver}"
echo "        with name ${ebuild_name}"

# Configure ssh
eval "$(ssh-agent -s)"
mkdir -p /root/.ssh
ssh-keyscan github.com >> /root/.ssh/known_hosts
echo "${GHA_DEPLOY_KEY}" | ssh-add -
ssh-add -l

# Configure git
git config --global user.name "${GITHUB_ACTOR}"
git config --global user.email "${GITHUB_ACTOR}@github.com"

# Checkout the overlay.
mkdir ~/overlay
cd ~/overlay
git init
git remote add github "git@github.com:${INPUT_OVERLAY}.git"
git pull github --ff-only "${INPUT_OVERLAY_BRANCH:-master}"

# Copy everything from the template to the new ebuild directory.
mkdir -p "${ebuild_cat}/${ebuild_pkg}"
cp "${GITHUB_WORKSPACE}/.gentoo/${ebuild_cat}/${ebuild_pkg}"/* "${ebuild_cat}/${ebuild_pkg}/"

# Create the new ebuild - 9999 live version.
unexpand --first-only -t 4 "${GITHUB_WORKSPACE}/.gentoo/${ebuild_path}" > "${ebuild_cat}/${ebuild_pkg}/${ebuild_name}"
sed-or-die "GITHUB_REPOSITORY" "${GITHUB_REPOSITORY}" "${ebuild_cat}/${ebuild_pkg}/${ebuild_name}"
sed-or-die "GITHUB_REF" "master" "${ebuild_cat}/${ebuild_pkg}/${ebuild_name}"

# Fix up the KEYWORDS variable in the new ebuild - 9999 live version.
# shellcheck disable=SC1090
source "${ebuild_cat}/${ebuild_pkg}/${ebuild_name}"
# shellcheck disable=SC2005,SC2046
new_keywords=$(echo $(for k in $KEYWORDS ; do echo "~${k}"; done))
sed-or-die '^KEYWORDS.*' "KEYWORDS=\"${new_keywords}\"" "${ebuild_cat}/${ebuild_pkg}/${ebuild_name}"

# Create the new ebuild - $ebuild_ver version.
unexpand --first-only -t 4 "${GITHUB_WORKSPACE}/.gentoo/${ebuild_path}" > "${ebuild_cat}/${ebuild_pkg}/${ebuild_ver}.ebuild"
sed-or-die "GITHUB_REPOSITORY" "${GITHUB_REPOSITORY}" "${ebuild_cat}/${ebuild_pkg}/${ebuild_ver}.ebuild"
sed-or-die "GITHUB_REF" "master" "${ebuild_cat}/${ebuild_pkg}/${ebuild_ver}.ebuild"

# Build manifests
ebuild "${ebuild_cat}/${ebuild_pkg}/${ebuild_name}" manifest
ebuild "${ebuild_cat}/${ebuild_pkg}/${ebuild_ver}.ebuild" manifest

# Add it to git
git add .

# Check it with repoman
repoman --straight-to-stable -dx full

# Commit the new ebuild.
git commit -m "Automated release of ${ebuild_cat}/${ebuild_pkg} version ${ebuild_numver}"
git push --set-upstream github master:"${INPUT_OVERLAY_BRANCH:-master}"

echo "------------------------------------------------------------------------------------------------------------------------"