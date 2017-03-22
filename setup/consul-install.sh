#!/bin/bash

wget https://releases.hashicorp.com/consul-template/0.18.0/consul-template_0.18.0_linux_amd64.zip
unzip consul-template_0.18.0_linux_amd64.zip -d /usr/local/bin
chmod +x /usr/local/bin/consul-template
mkdir /templates


