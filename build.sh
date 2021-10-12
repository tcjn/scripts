#!/bin/bash
set -e

DOCKER_REGISTRY="${DOCKER_REGISTRY:-mlqr.docker.itcm.oneadr.net/mlqr}"
CNTLM_PROXY="${CNTLM_PROXH:-http://127.0.0.1:3128}"
CNTLM_NOPROXY="pki2.oneadr.net,pki2.qaoneadr.local,artifactory.itcm.oneadr.net,localhost,127.0.0.0/8,::1"
GIT_URL="https://bitbucket.itgit.oneadr.net/scm/mlqr/mlqr-docker-base.git"
TRUNK_BRANCH="${TRUNK_BRANCH:-develop}"

SUCCESS_EXIT_CODE="0"
FAILURE_EXIT_CODE="1"

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  PROJECT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$PROJECT_DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
PROJECT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

function parse_args()
{
    PARAMS=""
    while (( "$#" )); do
      case "$1" in
        -p|--push)
          push_enabled=yes
          shift 1
          ;;
        -d|--dry)
          dry_run=yes
          shift 1
          ;;
        --) # end argument parsing
          shift
          break
          ;;
        -*|--*=) # unsupported flags
          echo "Error: Unsupported flag $1" >&2
          exit 1
          ;;
        *) # preserve positional arguments
          if [ -n "${PARAMS}" ]
          then
              PARAMS="${PARAMS} $1"
          else
            PARAMS="$1"
          fi
          shift
          ;;
      esac
    done
    # set positional arguments in their proper place
    eval set -- "$PARAMS"
}

function should_build() {
    local image_name="$1"
    local exit_code="${SUCCESS_EXIT_CODE}"
    if [ -f "${PROJECT_DIR}/.buildignore" ]
    then
        occurrences=$(echo "${image_name}" | grep -c -x -f "${PROJECT_DIR}/.buildignore")
        if [ "${occurrences}" -gt "0" ]
        then
            exit_code="${FAILURE_EXIT_CODE}"
        fi
    fi
    return "${exit_code}"
}

function build_tag()
{
    local image_name="$1"
    local upstream_tag="$2"
    if should_build "${image_name}/${upstream_tag}"
    then
        local release_tag="${DOCKER_REGISTRY}/${image_name}:${upstream_tag}_${RELEASE_ID}"
        local git_sha1_tag="${DOCKER_REGISTRY}/${image_name}:${CURRENT_COMMIT}"
        echo -e "\e[32mBuilding:\e[0m \e[34m${release_tag}\e[0m"

        echo "Build Context:  $PROJECT_DIR/${image_name}/${upstream_tag}"
        if [ "${dry_run}" != "yes" ]
        then
            docker build \
            --build-arg http_proxy="${CNTLM_PROXY}" \
            --build-arg https_proxy="${CNTLM_PROXY}" \
            --build-arg no_proxy="${CNTLM_NOPROXY}" \
            --network=host \
            --label "org.label-schema.schema-version"="1.0" \
            --label "org.label-schema.name"="${image_name}" \
            --label "org.label-schema.version"="${upstream_tag}_${RELEASE_ID}" \
            --label "org.label-schema.build-date"="${build_date}" \
            --label "org.label-schema.vcs-url"="${GIT_URL}" \
            --label "org.label-schema.vcs-ref"="${CURRENT_COMMIT}" \
            --tag "${release_tag}" \
            --tag "${git_sha1_tag}" \
            "$PROJECT_DIR/${image_name}/${upstream_tag}"
        fi

        if [ "${push_enabled}" == "yes" ]
        then
            echo -e "\e[32mPushing:\e[0m \e[34m${release_tag}\e[0m"
            if [ "${dry_run}" != "yes" ]
            then
                docker push "${release_tag}"
                docker push "${git_sha1_tag}"
            fi
        fi
    fi
}

function build_image()
{
    local image_name="$1"
    if should_build "${image_name}"
    then
        if [ -d "$PROJECT_DIR/${image_name}" ]
        then
            find "$PROJECT_DIR/${image_name}" -maxdepth 1 -mindepth 1   -not -path '*/\.*' -type d | while read tag_dir
            do
                local upstream_tag="$(echo "${tag_dir}" | xargs basename)"

                build_tag "${image_name}" "${upstream_tag}"
            done
        else
            echo -e "\e[31mImage base dir not found:\e[0m \e[34m${image_name}\e[0m"
        fi
    fi
}


function build_all()
{
    find "$PROJECT_DIR" -maxdepth 1 -mindepth 1   -not -path '*/\.*' -type d | while read image_dir
    do
        local image_name="$(echo "${image_dir}" | xargs basename)"
        build_image "${image_name}"
    done
}

function calculate_build_coordinates()
{
    CURRENT_BRANCH="${bamboo_planRepository_branch:-$(git rev-parse --abbrev-ref HEAD)}"
    CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null || true)
    BUILD_NUMBER="${BUILD_NUMBER:-${bamboo_buildNumber:-$(date +%s)}}"
    BUIILD_DATE=$(date --rfc-3339=seconds)

    if echo "${CURRENT_BRANCH}" | grep --color -qE '^release/[0-9]+\.[0-9]+.([0-9]+|x)$'
    then
        local semantic_version=$(jq -r  .version package.json 2>/dev/null || true)
        if echo "${semantic_version}" | grep --color -qE '^[0-9]+\.[0-9]+.([0-9]+)$'
        then
            local release_id="rev${semantic_version}-build.${BUILD_NUMBER}"
        else
            local release_id="branch-${CURRENT_BRANCH}-build.${BUILD_NUMBER}"
        fi
    elif [ "${CURRENT_BRANCH}" == "${TRUNK_BRANCH}" ]
    then
        local release_id="trunk.$(date +%Y.%m.%d)-build.${BUILD_NUMBER}"
    else
        local release_id="branch-${CURRENT_BRANCH}-build.${BUILD_NUMBER}"
    fi
    RELEASE_ID=$(echo -n ${release_id} | tr '[:upper:]'  '[:lower:]' | tr -c a-zA-Z0-9-._ _ | cut -c 1-110)
}

function main()
{
    parse_args "$@"
    calculate_build_coordinates

    if [ -n "${PARAMS}" ]
    then
        for param in ${PARAMS}
        do
            param="$(echo "${param}" | sed -E 's#/$##g')"
            if [ "$(echo "${param}" | grep -o --color -e '/' | wc -l)" -eq "0" ]
            then
                local image="${param}"
                build_image "$image"
            elif [ "$(echo "${param}" | grep -o --color -e '/' | wc -l)" -eq "1" ]
            then
                local image="$(echo "${param}" |  awk -F '/' '{print $1}')"
                local upstream_tag="$(echo "${param}" |  awk -F '/' '{print $2}')"
                build_tag "${image}" "${upstream_tag}"
            else
                echo -e "\e[31mToo much nesting:\e[0m \e[34m${param}\e[0m"
            fi

        done
    else
        build_all
    fi
}

main $@
