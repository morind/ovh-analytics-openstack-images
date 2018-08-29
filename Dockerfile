FROM python:3.5-jessie
LABEL Name=ovh-analytics-openstack-image Version=0.0.1
LABEL Descriptin="Provides a public Openstack image for Analytics Data Platform"
LABEL Author="OVH"

RUN apt-get -y update \
    && apt-get install -y \
    jq \
    curl \
    unzip \
    openssl \
    && curl https://releases.hashicorp.com/packer/1.2.5/packer_1.2.5_linux_amd64.zip > /tmp/packer.zip \
    && unzip /tmp/packer.zip -d /usr/bin/ \
    && pip install python-openstackclient python-swiftclient ansible

CMD ["/bin/bash"]