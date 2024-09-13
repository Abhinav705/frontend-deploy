#!/bin/bash
# we are passing the param1 and param2 from the main.tf file itself
component=$1
environment=$2
app_version=$3
dnf install ansible -y
pip3.9 install botocore boto3
ansible-pull -i localhost, -U https://github.com/Abhinav705/expense-ansible-roles-tf main.yaml -e component=$component -e env=$environment -e appVersion=$app_version
#we are running the script in the localhost itself, so we are mentioning -i (inventory) as localhost and telling to execute main.yaml file
#we are taking the ansible code from git and by using ansible-pull we are running the config.