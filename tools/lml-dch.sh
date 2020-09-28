#!/bin/bash

set -e

# Creates a changelog entry. This includes both Linux specific updates from linux-changelog, and mod
# launcher updates retrieved from docs.donutteam.com.
# Arguments:
#   - The mod launcher version.
# Outputs:
#   - Lines to prepend to the "changelog" file.
function lml_dch() {
  local -r lml_ver=$1

  if [[ -z $lml_ver ]]; then
    echo "Error: mod launcher version not specified."
    return 1
  fi

  # TODO: Don't hardcode this.
  local -r lml_package_ver=$lml_ver-1

  # Read Linux specific changes.

  # shellcheck source=tools/linux-changelog
  source linux-changelog
  local version_var=${lml_package_ver//./_}
  version_var=${version_var//-/_}
  version_var=ver_${version_var}
  linux_changelog=${!version_var}

  # TODO: Don't harcode "UNRELEASED".
  echo "lucas-simpsons-hit-and-run-launcher ($lml_package_ver) UNRELEASED; urgency=low"
  echo ""
  if [[ -n "$linux_changelog" ]]; then
    echo "$linux_changelog"
  fi
  ./read-dt-doc.py -nd lucasmodlauncher/versions/version_"$lml_ver" | ./format.py
  echo ""
  echo " -- $(git config user.name) <$(git config user.email)> $(date -Ru)"
  echo ""
}

echo "lml-dch: lucas' mod launcher debian changelog tool"
changelog_path=../debian/changelog
tmp_path=tmp
lml_dch "$@" | tee >(cat - $changelog_path >$tmp_path && mv $tmp_path $changelog_path)
