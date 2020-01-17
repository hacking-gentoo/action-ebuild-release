#!/usr/bin/env bash
set -e

# shellcheck disable=SC1090
if ! source "${GITHUB_ACTION_LIB:-/usr/lib/github-action-lib.sh}"; then
	echo "::error::Unable to locate github-action-lib.sh"
	exit 1
fi

[[ ${GITHUB_REF} = refs/heads/* ]] && git_branch="${GITHUB_REF##*/}"
[[ ${GITHUB_REF} = refs/tags/* ]] && git_tag="${GITHUB_REF##*/}"

cat << END
------------------------------------------------------------------------------------------------------------------------
                      _   _                       _           _ _     _                 _                     
                     | | (_)                     | |         (_) |   | |               | |                    
            __ _  ___| |_ _  ___  _ __ ______ ___| |__  _   _ _| | __| |______ _ __ ___| | ___  __ _ ___  ___ 
           / _\` |/ __| __| |/ _ \| '_ \______/ _ \ '_ \| | | | | |/ _\` |______| '__/ _ \ |/ _ \/ _\` / __|/ _ \\
          | (_| | (__| |_| | (_) | | | |    |  __/ |_) | |_| | | | (_| |      | | |  __/ |  __/ (_| \__ \  __/
           \__,_|\___|\__|_|\___/|_| |_|     \___|_.__/ \__,_|_|_|\__,_|      |_|  \___|_|\___|\__,_|___/\___|
 
          https://github.com/hacking-gentoo/action-ebuild-release                    (c) 2019-2020 Max Hacking 
------------------------------------------------------------------------------------------------------------------------
INPUT_PACKAGE_ONLY="${INPUT_PACKAGE_ONLY}"
GITHUB_ACTOR="${GITHUB_ACTOR}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY}"
GITHUB_REF="${GITHUB_REF}"
git_branch="${git_branch}"
git_tag="${git_tag}"
------------------------------------------------------------------------------------------------------------------------
END

# Check for a GITHUB_WORKSPACE env variable
[[ -z "${GITHUB_WORKSPACE}" ]] && die "Must set GITHUB_WORKSPACE in env"
cd "${GITHUB_WORKSPACE}" || exit 2

# Check for a tag
[[ -z "${GITHUB_REF}" ]] && die "Expecting GITHUB_REF to be a tag"

# Check for an overlay
[[ -z "${INPUT_OVERLAY_REPO}" ]] && die "Must set INPUT_OVERLAY_REPO"

# Check for repository deploy key.
[[ -z "${INPUT_DEPLOY_KEY}" ]] && die "Must set INPUT_DEPLOY_KEY"

# If there isn't a .gentoo directory in the base of the workspace then bail
[[ -d .gentoo ]] || die "No .gentoo directory in workspace root"

# Find the ebuild template and get its category, package and name
ebuild_path=$(find_ebuild_template)
ebuild_cat=$(get_ebuild_cat "${ebuild_path}")
ebuild_pkg=$(get_ebuild_pkg "${ebuild_path}")
ebuild_name=$(get_ebuild_name "${ebuild_path}")

# Work out from the tag what version we are releasing.
ebuild_ver=$(get_ebuild_ver "${GITHUB_REF}")

# Calculate overlay branch name
overlay_branch="${INPUT_OVERLAY_BRANCH:-${ebuild_cat}/${ebuild_pkg}}"

# Display our findings thus far
echo "Located ebuild at ${ebuild_path}"
echo "  in category ${ebuild_cat}"
echo "    for ${ebuild_pkg}"
echo "      version ${ebuild_ver}"
echo "        with name ${ebuild_name}"

# Configure ssh
configure_ssh "${INPUT_DEPLOY_KEY}"

# Configure git
configure_git "${GITHUB_ACTOR}"

# Checkout the overlay (master).
checkout_overlay_master "${INPUT_OVERLAY_REPO}"

# Check out the branch or create a new one
checkout_or_create_overlay_branch "${overlay_branch}"

# Try to rebase.
rebase_overlay_branch

# Add the overlay to repos.conf
repo_name="$(configure_overlay)"

# Ensure that this ebuild's category is present in categories file.
check_ebuild_category "${ebuild_cat}"

# Copy everything from the template to the new ebuild directory.
copy_ebuild_directory "${ebuild_cat}" "${ebuild_pkg}"

# Create the new ebuild - 9999 live version.
create_live_ebuild "${ebuild_cat}" "${ebuild_pkg}" "${ebuild_name}"

# Create the new ebuild - $ebuild_ver version.
create_new_ebuild "${ebuild_cat}" "${ebuild_pkg}" "${ebuild_ver}" "${ebuild_path}" "${repo_name}"

# Add it to git
git_add_files

# Check it with repoman
repoman_check

# Commit the new ebuild.
git_commit "Automated release of ${ebuild_cat}/${ebuild_pkg} version ${ebuild_ver}"

# Push git repo branch
git_push "${overlay_branch}"

# Create a pull request
if [[ -n "${INPUT_AUTH_TOKEN}" ]]; then
	title="Automated release of ${ebuild_cat}/${ebuild_pkg}"
	msg="Automatically generated pull request to update overlay for release of ${ebuild_cat}/${ebuild_pkg}"
	create_pull_request "${overlay_branch}" "master" "${title}" "${msg}" "false" 
fi

echo "------------------------------------------------------------------------------------------------------------------------"
