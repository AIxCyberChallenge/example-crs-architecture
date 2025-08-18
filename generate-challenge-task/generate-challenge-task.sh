#!/bin/bash
#
# Generate a crs/task command by tarring up required repos and issuing crs/task spec curl

# default configs

set -e -o pipefail

SCRIPT_HOME="$PWD"
ROOT_WORK_DIR="$(mktemp -d)"
TARS_DIR="$ROOT_WORK_DIR/repo-tars"
REPO_WORK_DIR="$ROOT_WORK_DIR/work"
OSS_FUZZ_REPO="https://github.com/google/oss-fuzz.git"
VERBOSE=0
LOCAL_TARS=0
HARNESSES_INCLUDED="true"
BASE_REF="main"

usage() {
    echo "Usage: $0 [options]"
    echo "    -v    Enable verbose output mode"
    echo "    -c    URL to the CRS to send challenge task."
    echo "    -x    Execute the crs task challenge against the CRS URL in -c on script finish. If argument is not supplied, the curl will be written to a local file."
    echo "    -t    Target github repo to scan. Format: path to the remote that will work for git clone"
    echo "    -r    Git ref to generate diff for delta mode."
    echo "    -b    Git ref to act as base for the diff. Default value is main. Often useful on a repo where the central branch is called master"
    echo "    -o    OSS-Fuzz repo to generate OSS-Fuzz tooling package. Default https://github.com/google/oss-fuzz.git"
    echo "    -p    Project folder name inside OSS-Fuzz corresponding to this repo (for example, for https://github.com/apache/commons-compress, this is apache-commons-compress)"
    echo "    -l    Instead of uploading to Azure storage, leave tars on local filesystem. Placeholders for sas_urls will be inserted into curl"
    echo "    -H    Set harnesses_included in task JSON to false. If not set, harnesses_included defaults to true"
    exit 1
}

parseargs() {
    while getopts ":hvxlHc:t:r:b:o:p:" opt; do
        case $opt in
            v) VERBOSE=1 ;;
            h) usage ;;
            x) EXECUTE_CURL=1 ;;
            l) LOCAL_TARS=1 ;;
            H) HARNESSES_INCLUDED="false" ;;
            c) CRS_URL=$OPTARG ;;
            t) TARGET_REPO=$OPTARG
                REPO_FOLDER="$(echo "$TARGET_REPO" | sed 's|[^/]*/||g' | sed 's|.git||g')"
                ;;
            r) REF=$OPTARG ;;
            b) BASE_REF=$OPTARG ;;
            o) OSS_FUZZ_REPO=$OPTARG ;;
            p) OSS_FUZZ_PROJECT_NAME=$OPTARG ;;
            \?) echo "Invalid option: -$OPTARG"; usage ;;
            :) echo "Option -$OPTARG requires an argument"; usage ;;
        esac
    done
    if [ -z "$CRS_URL" ]; then
        echo "Ensure -c (CRS URL) is set"
        usage
    fi
    if [ -z "$TARGET_REPO" ]; then
        echo "Ensure -t (target repo) is set"
        usage
    fi
    if [ -z "$OSS_FUZZ_PROJECT_NAME" ]; then
        echo "Ensure -p (OSS-Fuzz project name for this repo) is set"
        usage
    fi
}

getenvvars() {
    if [ -f ./.env ]; then
        source ./.env
    fi
    if [ $VERBOSE == 1 ]; then echo "Check for required environment variables"; fi
    if [ "${LOCAL_TARS:-0}" != 1 ]; then
        for envvar in CONTAINER_NAME STORAGE_ACCOUNT STORAGE_KEY CONNECTION_STRING; do
            if [ -z "${!envvar}" ]; then
                echo "Ensure $envvar variable is set."
                exit 2
            fi
        done
    fi
    for envvar in CRS_API_KEY_ID CRS_API_TOKEN; do
        if [ -z "${!envvar}" ]; then
            echo "Ensure $envvar variable is set."
            exit 2
        fi
    done
}

checkdeps() {
    local required_version="2.58.0"
    if [ $VERBOSE == 1 ]; then echo "Checking dependencies..."; fi
    if ! (which az >/dev/null 2>&1); then
        echo "azure-cli not found and is a required dependency. Install azcli >= $required_version"
        exit 3
    fi
    local installed_version=$(az version -o yaml | grep "azure-cli:" | sed 's/azure-cli: //')
    if [ "$(printf '%s\n' "$required_version" "$installed_version" | sort -V | head -n 1)" != $required_version ]; then
       echo "azcli version found: $installed_version is less than required: $required_version. Please ugrade."
       exit 3
    fi
    if ! (which git >/dev/null 2>&1); then
        echo "git required, please install git."
        exit 3
    fi
    if ! (which jq >/dev/null 2>&1); then
        echo "jq required, please install jq."
        exit 3
    fi
    if ! (which tar >/dev/null 2>&1); then
        echo "tar required, please install tar."
        exit 3
    fi
    if ! (which curl >/dev/null 2>&1); then
        echo "curl required, please install curl."
        exit 3
    fi
}

repotar() {
    local repo=$1
    if [ -n "$2" ]; then
        local diff_ref=$2
    fi
    local dirname=$(echo "$repo" | xargs -I {} basename {} .git )
    if [ $VERBOSE == 1 ]; then echo "Check out $repo"; fi
    mkdir -p "${REPO_WORK_DIR}"
    cd "${REPO_WORK_DIR}" || exit 5
    if ! (git clone "$repo") | tail -n +1 >/dev/null 2>&1  ; then
        echo "git clone of $repo failed. Verify you have access/permissions set up to clone this repo"
        exit 4
    fi
    cd "$dirname" || exit 5
    # get the pr diff
    if [ -n "$diff_ref" ]; then
        if [ $VERBOSE == 1 ]; then echo "Diff detected: Tarring diff: $BASE_REF vs $diff_ref alongside repo"; fi
        local base_dir="$ROOT_WORK_DIR/base-checkout"
        local diff_dir="$ROOT_WORK_DIR/diff-checkout"
        mkdir -p "$base_dir"
        mkdir -p "$diff_dir"
        cp -R "${REPO_WORK_DIR}/$dirname" "$base_dir"
        cp -R "${REPO_WORK_DIR}/$dirname" "$diff_dir"
        cd "$base_dir/$dirname"
        git checkout "$BASE_REF"
        rm -rf .git
        rm -rf .github
        rm -rf .aixcc
        cd "$diff_dir/$dirname"
        git checkout "$diff_ref"
        rm -rf .git
        rm -rf .github
        rm -rf .aixcc
        cd "${ROOT_WORK_DIR}"
        set +e #Need to unset this for the diff since diff returns 1 if a difference exists and breaks script
        git diff --no-index "$base_dir" "$diff_dir" |
            sed 's|a'"$base_dir/$dirname"'|a|g' | # remove base_dir and diff_dir from any a/b refs
            sed 's|b'"$diff_dir/$dirname"'|b|g' |
            sed 's|b'"$base_dir/$dirname"'|b|g' |
            sed 's|a'"$diff_dir/$dirname"'|a|g' |
            sed 's| '"$base_dir/$dirname"'/| |g' | # remove any remaining instances, without a or b, and remove the leading slash
            sed 's| '"$diff_dir/$dirname"'/| |g' >ref.diff
        set -e
        mkdir diff && mv -- ref.diff diff
        tar czf "$TARS_DIR/diff-$(echo $diff_ref | sed 's|/|-|g').tar.gz" diff
    fi
    if [[ "$dirname" != *"oss-fuzz"* ]]; then
        cd "${REPO_WORK_DIR}/$dirname"
        git checkout "$BASE_REF"
    fi
    if [ $VERBOSE == 1 ]; then echo "Remove .git for $repo"; fi
    rm -rf .git
    if [ $VERBOSE == 1 ]; then echo "Remove .github for $repo"; fi
    rm -rf .github
    if [ $VERBOSE == 1 ]; then echo "Remove .aixcc for $repo"; fi
    rm -rf .aixcc
    if [ $VERBOSE == 1 ]; then echo "Tarring $repo"; fi
    if [[ "$dirname" == *"oss-fuzz"* ]]; then
        cd ..
        mv "$dirname" fuzz-tooling
        mkdir fuzz-tooling-wrapper
        mv fuzz-tooling fuzz-tooling-wrapper
        cd fuzz-tooling-wrapper
        tar czf "$TARS_DIR/$dirname.tar.gz" fuzz-tooling
    else
        cd ..
        mkdir "$dirname-wrapper"
        mv "$dirname" "$dirname-wrapper"
        cd "$dirname-wrapper"
        tar czf "$TARS_DIR/$dirname.tar.gz" "$dirname"
    fi
}

uploadtar() {
    local tar=$1
    if [ $VERBOSE == 1 ]; then echo "Upload tar $tar"; fi

    #check tar type for pathing in Az storage
    if [[ "$tar" == *"oss-fuzz"* ]]; then
        OSS_FUZZ_SHA256="$(sha256sum $tar | cut -d' ' -f1)"
        OSS_FUZZ_TAR_NAME="$OSS_FUZZ_SHA256.tar.gz"
        if [ $VERBOSE == 1 ]; then echo "Uploading oss-fuzz tooling tar as $OSS_FUZZ_TAR_NAME"; fi
        az storage blob upload \
            --container-name "$CONTAINER_NAME" \
            --account-name "$STORAGE_ACCOUNT" \
            --file "$tar" \
            --name "$OSS_FUZZ_TAR_NAME" \
            --sas-token "$STORAGE_KEY" \
            --overwrite
        if [ $VERBOSE == 1 ]; then echo "Get SAS URL for uploaded oss-fuzz tar $OSS_FUZZ_TAR_NAME"; fi
        OSS_FUZZ_SAS_URL=$(az storage blob generate-sas \
            --account-name "$STORAGE_ACCOUNT" \
            --container-name "$CONTAINER_NAME" \
            --name "$OSS_FUZZ_TAR_NAME" \
            --permissions r \
            --expiry $(date -u -d "4 hours" +"%Y-%m-%dT%H:%M:%SZ") \
            --output tsv \
            --connection-string "$CONNECTION_STRING" \
            --full-uri \
            )
    elif [[ "$tar" == *"diff"*"tar.gz"* ]]; then
        DIFF_SHA256="$(sha256sum $tar | cut -d' ' -f1)"
        DIFF_TAR_NAME="$DIFF_SHA256.tar.gz"
        if [ $VERBOSE == 1 ]; then echo "Uploading diff tar as $DIFF_TAR_NAME"; fi
        az storage blob upload \
            --container-name "$CONTAINER_NAME" \
            --account-name "$STORAGE_ACCOUNT" \
            --file "$tar" \
            --name "$DIFF_TAR_NAME" \
            --sas-token "$STORAGE_KEY" \
            --overwrite
        if [ $VERBOSE == 1 ]; then echo "Get SAS URL for uploaded diff tar $DIFF_TAR_NAME"; fi
        DIFF_SAS_URL=$(az storage blob generate-sas \
            --account-name "$STORAGE_ACCOUNT" \
            --container-name "$CONTAINER_NAME" \
            --name "$DIFF_TAR_NAME" \
            --permissions r \
            --expiry $(date -u -d "4 hours" +"%Y-%m-%dT%H:%M:%SZ") \
            --output tsv \
            --connection-string "$CONNECTION_STRING" \
            --full-uri
            )
    else
        REPO_SHA256="$(sha256sum $tar | cut -d' ' -f1)"
        REPO_TAR_NAME="$REPO_SHA256.tar.gz"
        if [ $VERBOSE == 1 ]; then echo "Uploading target repo tar as $REPO_TAR_NAME"; fi
        az storage blob upload \
            --container-name "$CONTAINER_NAME" \
            --account-name "$STORAGE_ACCOUNT" \
            --file "$tar" \
            --name "$REPO_TAR_NAME" \
            --sas-token "$STORAGE_KEY" \
            --overwrite
        if [ $VERBOSE == 1 ]; then echo "Get SAS URL for uploaded target repo tar $REPO_TAR_NAME"; fi
        REPO_SAS_URL=$(az storage blob generate-sas \
            --account-name "$STORAGE_ACCOUNT" \
            --container-name "$CONTAINER_NAME" \
            --name "$REPO_TAR_NAME" \
            --permissions r \
            --expiry $(date -u -d "4 hours" +"%Y-%m-%dT%H:%M:%SZ") \
            --output tsv \
            --connection-string "$CONNECTION_STRING" \
            --full-uri \
            )
    fi
}

generatecurl(){
    local focus_repo=$1
    local project_name=$2
    local target_sas_url=$3
    local oss_fuzz_sas_url=$4
    local msgid="$(uuidgen)"
    local taskid="$(uuidgen)"
    local currtime="$(($(date +%s) * 1000))"
    local duetime="$(($currtime + 14400000))"
    local harnesses_included=$HARNESSES_INCLUDED
    if [ -n "${5+x}" ]; then
        local diff_sas_url=$5
        local payload="{ \
            \"message_id\": \"$msgid\",\
            \"message_time\": $currtime,\
            \"tasks\": [{\
              \"task_id\": \"$taskid\",\
              \"type\": \"delta\",\
              \"metadata\": {\
                \"round.id\": \"local-dev\",\
                \"task.id\": \"$taskid\"\
              },\
              \"deadline\": $duetime,\
              \"focus\": \"$focus_repo\",\
              \"harnesses_included\": $harnesses_included,\
              \"project_name\": \"$project_name\",\
              \"source\": [{\
                \"type\": \"repo\",\
                \"url\": \"$target_sas_url\",\
                \"sha256\": \"$REPO_SHA256\" \
                },\
                {\
                \"type\": \"fuzz-tooling\",\
                \"url\": \"$oss_fuzz_sas_url\",\
                \"sha256\": \"$OSS_FUZZ_SHA256\"\
                },
                {
                \"type\": \"diff\",
                \"url\": \"$diff_sas_url\",\
                \"sha256\": \"$DIFF_SHA256\"
                }\
                ]\
              }\
            ]\
          }"
    else
        local payload="{ \
            \"message_id\": \"$msgid\",\
            \"message_time\": $currtime,\
            \"tasks\": [{\
              \"task_id\": \"$taskid\",\
              \"type\": \"full\",\
              \"deadline\": $duetime,\
              \"focus\": \"$focus_repo\",\
              \"harnesses_included\": $harnesses_included,\
              \"metadata\": {\
                \"round.id\": \"local-dev\",\
                \"task.id\": \"$taskid\"\
              },\
              \"project_name\": \"$project_name\",\
              \"source\": [{\
                \"type\": \"repo\",\
                \"url\": \"$target_sas_url\",\
                \"sha256\": \"$REPO_SHA256\" \
                },\
                {\
                \"type\": \"fuzz-tooling\",\
                \"url\": \"$oss_fuzz_sas_url\",\
                \"sha256\": \"$OSS_FUZZ_SHA256\"\
                }]\
              }\
            ]\
          }"
    fi
    CURL_CMD="curl -s -X POST \"$CRS_URL/v1/task/\" -H \"Content-Type: application/json\" \
        --user \"$CRS_API_KEY_ID\":\"$CRS_API_TOKEN\" -d '$(echo "$payload" | jq -c)'"
}

sendcurl(){
    echo "Execute Curl Command at $CRS_URL"
    eval "$1"
}

cleanup() {
    if [ $VERBOSE == 1 ]; then echo "Remove temp dir $ROOT_WORK_DIR"; fi
    rm -rf "$ROOT_WORK_DIR"
}

main() {
    parseargs "$@"
    getenvvars
    checkdeps

    if [ "$VERBOSE" == 1 ]; then echo "Working dir: $ROOT_WORK_DIR"; fi
    # Start doing stuff
    mkdir -p "$TARS_DIR"
    for repo in "$TARGET_REPO" "$OSS_FUZZ_REPO"; do
        if [ -n "${REF+x}" ] && [ "$TARGET_REPO" == "$repo" ]; then
            repotar "$repo" "$REF"
        else
            repotar "$repo"
        fi
    done
    if [ "$LOCAL_TARS" != 1 ]; then
        for tar in "$TARS_DIR"/*; do
            if [ -f "$tar" ]; then
                uploadtar "$tar"
            fi
        done
    else
        cp -R "$TARS_DIR" "$SCRIPT_HOME"
    fi
    if [ -n "${REF+x}" ] && [ "$LOCAL_TARS" != 1 ]; then
        if [ $VERBOSE == 1 ]; then echo "Generating curl for a delta scan..."; fi
        generatecurl "$REPO_FOLDER" "$OSS_FUZZ_PROJECT_NAME" "$REPO_SAS_URL" "$OSS_FUZZ_SAS_URL" "$DIFF_SAS_URL"
    elif [ -n "${REF+x}" ] && [ "$LOCAL_TARS" == 1 ]; then
        if [ $VERBOSE == 1 ]; then echo "Generating curl for a delta scan with placeholders due to -l..."; fi
        generatecurl "$REPO_FOLDER" "$OSS_FUZZ_PROJECT_NAME" "repo-placeholder" "oss-fuzz-placeholder" "diff-placeholder"
    elif [ "$LOCAL_TARS" == 1 ]; then
        if [ $VERBOSE == 1 ]; then echo "Generating curl for a full scan with placeholders due to -l..."; fi
        generatecurl "$REPO_FOLDER" "$OSS_FUZZ_PROJECT_NAME" "repo-placeholder" "oss-fuzz-placeholder"
    else
        if [ $VERBOSE == 1 ]; then echo "Generating curl for full scan, no delta/PR..."; fi
        generatecurl "$REPO_FOLDER" "$OSS_FUZZ_PROJECT_NAME" "$REPO_SAS_URL" "$OSS_FUZZ_SAS_URL"
    fi
    if [ $VERBOSE == 1 ]; then echo "DEBUG: CURL_CMD: $CURL_CMD"; fi
    if [ "$EXECUTE_CURL" == 1 ]; then
        sendcurl "$CURL_CMD"
    else
        cd "$SCRIPT_HOME"
        if [ $VERBOSE == 1 ]; then echo "Output curl command to task_crs.sh in $SCRIPT_HOME"; fi
        echo "#!/bin/bash" > task_crs.sh
        echo "$CURL_CMD" >> task_crs.sh
        chmod +x task_crs.sh
    fi
    cleanup
}

main "$@"
