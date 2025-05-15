#!/bin/bash

warn() {
    echo "$*" >&2
}

die() {
    warn "$*"
    exit 1
}

VERSION="v2.2.0"
print_ver() {
    echo "$VERSION"
}

print_usage() {
    echo "usage: run_tests [OPTION] -p PROJECT_NAME -r LOCAL_PROJ_REPO

Options:
    -h                  show usage
    -v                  list current version
    -t TEST_SCRIPT      pass the test script to run (default .aixcc/test.sh)
    -i DOCKER_IMAGE     set docker image name (default aixcc-afc/<proj_name>)
    -x                  set -x when success is not expected, this affects exit code"
}

run_tests() {

    LOCAL_SRC_MNT="/local-source-mount"
    TEST_MNT="/test-mnt.sh"

    docker run --rm \
        -v "${LOCAL_PROJ_REPO_ABS}:${LOCAL_SRC_MNT}" \
        -v "${TEST_SCRIPT_ABS}:${TEST_MNT}"\
        "${DOCKER_IMAGE}" \
        /bin/bash -c "pushd \$SRC && rm -rf ${WORK_DIR} \
                        && cp -r ${LOCAL_SRC_MNT} ${WORK_DIR} \
                        && cp ${TEST_MNT} \${SRC}/test.sh \
                        && popd && \${SRC}/test.sh"
    EXITCODE=$?

    case $EXITCODE in
        125|126|127)
            warn "Docker failed to mount and run the test script."
            exit $EXITCODE
            ;;
    esac

    if [[ $EXITCODE -eq 0 ]]; then
        if [ -z ${SUCCESS_NOT_EXPECTED+x} ]; then
            echo "Tests passed as expected"
            exit 0
        else
            die "Tests passed unexpectedly"
        fi
    else
        if [ -z ${SUCCESS_NOT_EXPECTED+x} ]; then
            die "Tests failed, but were expected to pass"
        else
            echo "Tests failed as expected"
            exit 0
        fi
    fi

}

while getopts ":p:r:i:t:hvx" opt; do
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
        i)
            DOCKER_IMAGE="${OPTARG}"
            ;;
        t)
            TEST_SCRIPT="${OPTARG}"
            ;;
        x)
            SUCCESS_NOT_EXPECTED=1
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

: "${DOCKER_IMAGE:="aixcc-afc/${PROJECT_NAME}"}"
: "${TEST_SCRIPT:="${LOCAL_PROJ_REPO}/.aixcc/test.sh"}"

LOCAL_PROJ_REPO_ABS=$(realpath "${LOCAL_PROJ_REPO}")
TEST_SCRIPT_ABS=$(realpath "${TEST_SCRIPT}")

WORK_DIR=$(docker inspect --format '{{.Config.WorkingDir}}' "${DOCKER_IMAGE}")

if ! [[ -x "${TEST_SCRIPT_ABS}" ]]
then
    die "/.aixcc/test.sh is not executable or found"
fi

run_tests

## leave these here in case a case is improperly handled
# shellcheck disable=SC2317
print_usage
# shellcheck disable=SC2317
exit 1


