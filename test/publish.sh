#!/usr/bin/env bash
BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."
COMMIT=$(git rev-parse --verify --short HEAD 2>/dev/null)
TAG=$(git describe --tags 2>/dev/null)
VERSION=${TAG:-latest}
IMAGE=$1
IMAGE_NAME="$(jq -r .variables.image_name ${IMAGE})"
MD5SUM="$(command -v md5sum)"
if ! [ -x "${MD5SUM}" ]; then
    MD5SUM="$(command -v md5) -q"
fi

if [ -z "${IMAGE_NAME}" ]; then
    echo "Usage: publish.sh [IMAGE_NAME]";
    exit 1
fi

# PGP Signing ID
PGP_SIGN_ID=70AD8BDB78DEBD72
PGP_VERI_ID=44A31488B9BA649C3876C6F070AD8BDB78DEBD72

# Pgp key passphrase file
echo ${GPG_PASS} > "${BASEDIR}/.gpg.passphrase"
PGP_KEY_PASSPHRASE_FILE=${BASEDIR}/.gpg.passphrase

# The openstack region where to create the swift container
CONTAINER_REGION=${CONTAINER_REGION:-$OS_REGION_NAME}

# The name of the swift container
CONTAINER_NAME=${CONTAINER_NAME:-"ovhcommunity"}

# Folder where to generate the image
IMAGES_PREFIX=${IMAGES_PREFIX:-"images"}

# Image where the region has been built
IMAGE_REGION=${2:-$OS_REGION_NAME}

# Swift container segment size (1024*1024*128 = 128M)
SEGMENT_SIZE=134217728

function already_published_image(){
    image_name=$1
    src_checksum=$2
    tmp_dir=$(mktemp -d)

    # download md5sum & sig
    if ! (swift --os-region-name "$CONTAINER_REGION" download -o "$tmp_dir/md5sum.txt.sig" "$CONTAINER_NAME" "$IMAGES_PREFIX/$image_name.md5sum.txt.sig" &&
            swift --os-region-name "$CONTAINER_REGION" download -o "$tmp_dir/md5sum.txt" "$CONTAINER_NAME" "$IMAGES_PREFIX/$image_name.md5sum.txt"); then
        echo "No md5sum files have been previously uploaded" >&2
        return 1
    fi

    # checking sig
    if ! (out=$(cd ${tmp_dir} && gpg --status-fd 1 --verify md5sum.txt.sig 2>/dev/null) &&
            echo "$out" | grep -qs "^\[GNUPG:\] VALIDSIG $PGP_VERI_ID " &&
            echo "$out" | grep -qs "^\[GNUPG:\] TRUST_ULTIMATE"); then
        echo "Bad md5sum signature " >&2
        return 1
    fi

    # checking md5 checksums
    if ! (md5=$(swift --os-region-name "$CONTAINER_REGION" stat "$CONTAINER_NAME" "$IMAGES_PREFIX/$image_name" | awk 'gsub(/"/, "", $2);/ETag/ {print $2}') &&
            [ "$src_checksum" == "$md5" ] &&
            [ "$src_checksum" == "$(awk '{print $1}' ${tmp_dir}/md5sum.txt)" ]); then
        return 1
    fi
}


# computing image file name
image_file_name="$(echo "${IMAGE_NAME}_${COMMIT}.raw" | tr ' ' '_' | tr '[:upper:]'  '[:lower:]')"
image_version_file_name="$(echo "${IMAGE_NAME}.latest.txt" | tr ' ' '_' | tr '[:upper:]'  '[:lower:]')"

# Retrieving most recent image id
echo "Getting id for image with name '$IMAGE_NAME' and commit '$COMMIT' in region '$IMAGE_REGION'" >&2
image_id=$(openstack --os-region-name "$IMAGE_REGION" image list \
                     --name "$IMAGE_NAME" \
                     --property "commit=$COMMIT" \
                     --sort "created_at:desc" \
                     --status active \
                     -f value \
                     -c ID | head -1)
if [ -z "${image_id}" ]; then
    echo "Unable to find image" >&2
    exit 1
fi

# Retrieving image checksum
echo "Getting checksum for image with id '$image_id'" >&2
image_checksum=$(openstack --os-region-name "$IMAGE_REGION" image show \
                           -f value \
                           -c checksum \
                           "$image_id")
if already_published_image ${image_file_name} ${image_checksum}; then
    echo "image with id '$image_id' has already been published" >&2
    exit 0
fi

# creating tmp dir
tmp_dir=$(mktemp -d)
echo "Downloading image in '$tmp_dir'" >&2
# download raw image
if ! openstack --os-region-name "$IMAGE_REGION" image save --file "${tmp_dir}/${image_file_name}" "${image_id}"; then
    echo "Unable to download image '${image_id}' in '${tmp_dir}'" >&2
    exit 1
fi

# compute downloaded file checksum
echo "Computing downloaded image checksum" >&2
(cd ${tmp_dir} && ${MD5SUM} ${image_file_name} > ${image_file_name}.md5sum.txt)
# check checksum
file_checksum="$(awk '{print $1}' ${tmp_dir}/${image_file_name}.md5sum.txt)"
if [ "${file_checksum}" != "${image_checksum}" ]; then
    echo "Image checksum '$image_checksum' is not equal to downloaded file checksum '${file_checksum}'" >&2
    exit 1
fi

# sign files
echo "Signing image file in '$tmp_dir'" >&2
gpg --batch --passphrase-file "$PGP_KEY_PASSPHRASE_FILE" -u "$PGP_SIGN_ID" --detach-sig ${tmp_dir}/${image_file_name}
echo "Signing image checksum file in '$tmp_dir'" >&2
gpg --batch --passphrase-file "$PGP_KEY_PASSPHRASE_FILE" -u "$PGP_SIGN_ID" --detach-sig ${tmp_dir}/${image_file_name}.md5sum.txt
# creating version file
echo ${COMMIT} > "${tmp_dir}/${image_version_file_name}"

# create swift container
echo "Creating swift container '$CONTAINER_NAME' in region '${CONTAINER_REGION}'" >&2
openstack --os-region-name "$CONTAINER_REGION" container create "${CONTAINER_NAME}" >/dev/null

# upload files on container
echo "uploading files from '$tmp_dir' in swift container '$CONTAINER_NAME'" >&2
swift --os-region-name "$CONTAINER_REGION" upload -S "$SEGMENT_SIZE" \
      --object-name "$IMAGES_PREFIX" "$CONTAINER_NAME" \
      "${tmp_dir}"

# make container publicly readable
swift --os-region-name "$CONTAINER_REGION" post --read-acl ".r:*,.rlistings" "${CONTAINER_NAME}" >/dev/null

# images are divided into segments, make them publicly readable
swift --os-region-name "$CONTAINER_REGION" post --read-acl ".r:*,.rlistings" "${CONTAINER_NAME}_segments" >/dev/null