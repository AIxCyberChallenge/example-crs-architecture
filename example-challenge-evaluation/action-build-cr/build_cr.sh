#!/bin/bash

#shellcheck disable=SC2086

warn() {
	echo "$*" >&2
}

die() {
	warn "$*"
	exit 1
}

VERSION="v1.6.0"
print_ver() {
	echo "$VERSION"
}

print_usage() {
	echo "usage: build_cr [OPTION] -p PROJECT_NAME -r LOCAL_PROJ_REPO -o LOCAL_OSS_FUZZ_REPO

Options:
    -h                  show usage
    -v                  list current version
    -l LOCALE           set the locale to use within the containers (deprecated)
    -s SANITIZER        set sanitizer for build 
                          {address,none,memory,undefined,thread,coverage,introspector,hwaddress}
                          the default is address
    -a ARCHITECTURE     set arch for build {i386,x86_64,aarch64}
    -d IMAGE_TAG        set the project docker image tag (default: latest)"
}

build_challenge_repository() {

	pushd "${LOCAL_OSS_FUZZ_REPO}" >/dev/null || die

	DOCKER_IMAGETAG_ARG=${IMAGE_TAG:+"--docker_image_tag ${IMAGE_TAG}"}

	## build_fuzzers calls build_image without --pull, so if we nix --pull we can nix this whole call
	${PYTHON} infra/helper.py build_image --pull \
		--architecture "${ARCHITECTURE}" \
		${DOCKER_IMAGETAG_ARG} \
		"${PROJECT_NAME}" || die "Failed to build the Docker image"

	${PYTHON} infra/helper.py build_fuzzers --clean \
		--architecture "${ARCHITECTURE}" \
		--sanitizer "${SANITIZER}" \
		${DOCKER_IMAGETAG_ARG} \
		"${PROJECT_NAME}" "${MY_LOCAL_PROJ_REPO}" || die "Failed to build the harness"

	${PYTHON} infra/helper.py check_build \
		--architecture "${ARCHITECTURE}" \
		--sanitizer "${SANITIZER}" \
		"${PROJECT_NAME}" || die "Failed to pass build check"

	popd >/dev/null || die

	exit 0
}

while getopts ":p:r:o:s:a:d:l:hv" opt; do
	case ${opt} in
	h)
		print_usage
		exit 0
		;;
	v)
		print_ver
		exit 0
		;;
	p)
		PROJECT_NAME="${OPTARG}"
		;;
	r)
		LOCAL_PROJ_REPO="${OPTARG}"
		;;
	o)
		LOCAL_OSS_FUZZ_REPO="${OPTARG}"
		;;
	s)
		SANITIZER="${OPTARG}"
		;;
	a)
		ARCHITECTURE="${OPTARG}"
		;;
	d)
		IMAGE_TAG="${OPTARG}"
		;;
	l)
		echo "locale flag is deprecated, doing nothing with its input."
		;;
	:)
		echo "Option -${OPTARG} requires an argument."
		exit 1
		;;
	?)
		echo "Invalid option: -${OPTARG}."
		exit 1
		;;
	esac
done

[ -z ${PROJECT_NAME+x} ] && print_usage && die "Must specify project name with -p"
[ -z ${LOCAL_PROJ_REPO+x} ] && print_usage && die "Must specify local project repo with -r"
[ -z ${LOCAL_OSS_FUZZ_REPO+x} ] && print_usage && die "Must specify local oss-fuzz repo with -o"

if [ ! -d "${LOCAL_PROJ_REPO}" ]; then
	die "LOCAL_PROJ_REPO does not exist: ${LOCAL_PROJ_REPO}"
fi

if [ ! -d "${LOCAL_OSS_FUZZ_REPO}" ]; then
	die "LOCAL_OSS_FUZZ_REPO does not exist: ${LOCAL_OSS_FUZZ_REPO}"
fi

# set default values if null is provided from github action
[ "${SANITIZER}" == "null" ] && SANITIZER="address"
[ "${ARCHITECTURE}" == "null" ] && ARCHITECTURE="x86_64"
[ "${IMAGE_TAG}" == "null" ] && IMAGE_TAG="latest"

# set defaults
# note, *not* setting IMAGE_TAG default
: "${PYTHON:="python3"}"
: "${SANITIZER:="address"}"
: "${ARCHITECTURE:="x86_64"}"

MY_LOCAL_PROJ_REPO=$(realpath "$LOCAL_PROJ_REPO")

build_challenge_repository

## leave these here in case a case is improperly handled
# shellcheck disable=SC2317
print_usage
# shellcheck disable=SC2317
exit 1
