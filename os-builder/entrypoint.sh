#!/bin/bash
set -e

[ "${VERBOSE}" = "verbose" ] && set -x

workdir="/work"
chmod +st "${workdir}"
if [ ! -f "${workdir}/repo.yml" ]; then
	git config --global --add safe.directory ${workdir}
	pushd "${workdir}"
	git init && git remote add origin "${REPOSITORY_URL}" && git fetch && git checkout "${VERSION}" && git submodule update --init --recursive;
	popd
elif ! grep -q 'yocto-based OS image' "${workdir}/repo.yml"; then
	echo "Working directory in use does not contain a Balena device repository" && exit 1;
fi

contracts_path="${workdir}/contracts/contracts/sw.os-image/"
if [ -d "${contracts_path}" ]; then
	cp /contract.json ${contracts_path}
else
	echo "No contracts sw.os-image directory found in working directory" && exit 1
fi
if [ -z "${PACKAGES}" ]; then
	# shellcheck disable=SC1091
	. ${workdir}/balena-yocto-scripts/automation/include/balena-lib.inc
	echo "Looking for contract for ${MACHINE}: ${BLOCK}"
	PACKAGES=$(balena_lib_contract_fetch_composedOf_list "${BLOCK}" "${MACHINE}")
	if [ -z "${PACKAGES}" ]; then
		echo "No packages found for ${BLOCK}"
		exit 1
	fi
fi
echo "Installing: ${PACKAGES}" >&2
BITBAKE_TARGETS="--bitbake-target ${PACKAGES} os-release package-index"
chown -R "${BUILDER_GID}":"${BUILDER_UID}" "${workdir}"
pushd "${workdir}"
/prepare-and-start.sh \
	--log \
	--machine "${MACHINE}" \
	--shared-downloads "${workdir}/shared-downloads" \
	--shared-sstate "${workdir}/shared-sstate" \
	--skip-discontinued \
	--rm-work \
	${BITBAKE_TARGETS}

if [ -n "${CLENAUP}" ]; then
	rm -rf "${workdir:?}/*"
fi
