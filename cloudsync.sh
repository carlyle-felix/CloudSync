#!/bin/bash

# SETUP
CLOUD_DIR="/datadirectory/user/files"
SRC_DIR="/path/to/source/"
NC_DIR="/var/www/nextcloud/htdocs"
# SETUP END

if [ "$#" -eq 0 ]; then
    echo "usage: cloudsync <dir>."
    echo "info: ${CLOUD_DIR}/<dir>"
    exit 1
elif [ "$#" -gt 1 ]; then
    echo "error: too many arguments."
    exit 1
fi

USER=$(stat -c "%U" "${NC_DIR}")
GROUP=$(stat -c "%G" "${NC_DIR}")

function main() {

    local arg dest user group
    local -a items

    arg="$1"
    dest="${CLOUD_DIR}/${arg}"

    shopt -s dotglob
    items=( "${SRC_DIR}"/"${arg}"/* )
    shopt -u nullglob

    change_owner "${arg}" "${items[@]}"

    if [ ! -d "${dest}" ]; then
        echo "info: creating ${dest} direcory..."
        install -d -o ${USER} -g ${GROUP} -m 750 "${dest}"
        if [ $? -ne 0 ]; then
            echo "error: unable to create ${dest} directory."
            exit 1
        fi
    fi
    cloud_sync "${arg}" "${items[@]}"

    echo "done."
    return 0
}

function change_owner() {

    local src items

    src="$1"
    items="$2"

    echo "info: change ownership to ${USER}:${GROUP}..."
    for i in "${items[@]}"; do
        chown -R ${USER}:${GROUP} "${i}"
        if [ $? -ne 0 ]; then
            echo "error: failed to change ownership of \"${i}\""
            exit 1
        fi
    done
}

function cloud_sync() {

    local dest items
    
    dest="$1"
    items="$2"

    echo "info: moving items to ${CLOUD_DIR}/${dest}/..."
    for i in "${items[@]}"; do
        mv -n "${i}" "${CLOUD_DIR}"/"${dest}"/"${i##*/}"
        if [ $? -ne 0 ]; then
            echo "error: failed to move src to ${i}"
            exit 1
        fi
    done

    echo "info: updating nextcloud server..."
    sudo -u ${USER} php "${NC_DIR}"/occ files:scan --all
    if [ $? -ne 0 ]; then
        echo "error: failed scan nextcloud server"
        exit 1
    fi
}

main "$@"