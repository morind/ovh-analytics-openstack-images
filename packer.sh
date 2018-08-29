#!/bin/bash

usage(){
    echo "
    Build Packer images and upload them to OpenStack prior to cluster deployment

    The following environment variables must be set:
      \$OS_USERNAME         your openstack username
      \$OS_PROJECT_ID       your openstack project id
      \$OS_PASSWORD         your openstack password
      \$OS_REGION_NAME      your openstack region name
      \$OS_AUTH_URL         your openstack auth URL

    OR you can use the following parameters:
      --os-username   Openstack username
      --os-password   Openstack password
      --os-project-id Openstack project ID
      --os-region     Openstack region name
      --os-auth-url   Openstack auth URL

    Options:
    --debug         Activate debug mode
    "
}

build(){
    export PACKER_NETWORK_ID=$(openstack network list -f value -c ID -c Name | grep Ext-Net | cut -d ' ' -f 1)
    echo "Detected Ext-Net on $OS_REGION_NAME on ID $PACKER_NETWORK_ID"
    echo "Starting build..."
    if [ "$1" = 1 ] ; then
        packer build -debug packer-common.json && packer build -debug packer-guacamole.json && packer build -debug packer-mysql.json && packer build -debug packer-ipa.json && packer build -debug packer-ambari.json
    else
        packer build packer-common.json && packer build packer-guacamole.json && packer build packer-mysql.json && packer build packer-ipa.json && packer build packer-ambari.json
    fi
}


POSITIONAL=()
DEBUG=0

# check for openstack cli
if ! [ -x "$(command -v openstack)" ]; then
    echo -e "\033[0;31mError: Openstack CLI is not installed.\033[0m\nSee https://docs.openstack.org/mitaka/user-guide/common/cli_install_openstack_command_line_clients.html"
    exit 1
fi

# process cli arguments
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -h|--help)
    usage
    exit 0;
    shift
    shift
    ;;
    --debug)
    DEBUG=1
    shift
    shift
    ;;
    --os-username)
    OS_USERNAME="$2"
    shift
    shift
    ;;
    --os-password)
    OS_PASSWORD="$2"
    shift
    shift
    ;;
    --os-project-id)
    OS_PROJECT_ID="$2"
    shift
    shift
    ;;
    --os-region-name)
    OS_REGION_NAME="$2"
    shift
    shift
    ;;
    --os-auth-url)
    OS_AUTH_URL="$2"
    shift
    shift
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift
    ;;
esac
done
set -- "${POSITIONAL[@]}"

# check for required env vars
if [[ -n $1 ]] || [ -z $OS_USERNAME ] || [ -z $OS_PROJECT_ID ] || [ -z $OS_PASSWORD ] || [ -z $OS_REGION_NAME ] || [ -z $OS_AUTH_URL ]; then
  usage
  exit 1;
fi

# all set! start build script
echo -e "##############################################"
echo -e "#                                            #"
echo -e "#                OVH HDP PACKER              #"
echo -e "#                                            #"
echo -e "##############################################\n"

build $DEBUG

