#!/bin/bash

##############################################################################
# ABOUT: This script can be used for distributed setup of Ensemble ZooKeeper #
#        in AWS EC2 from scratch, completely remotely using AWS CLI and AWS  #
#        SSM.                                                                #
##############################################################################

### Input : 
#            -aws_key_pair <nairp-keypair-hosted-admin>
#            -aws_resource_name_prefix NAIRP

############### Developer modifiable Configurations #######################
configureGlobals()
{
    MY_ABS_PATH=`echo "$(cd "$(dirname "$0")"; pwd)/$(basename "$0")"`
    VERTICILA_HOME=`dirname $MY_ABS_PATH | xargs dirname`
    source $VERTICILA_HOME/sys/sys_utils.sh
    sys_setFramework

    VERTICILA_REPO_TOP_DIR="verticila"
    VERTICILA_REPO_HTTP_URL="https://github.com/sourasisdas/${VERTICILA_REPO_TOP_DIR}.git"
    ZK_SETUP_SH="$VERTICILA_REPO_TOP_DIR/zk/zk_setup.sh"
}



#### this -> aws_secgrp.sh
#- Create security group ${AWS_RESOURCE_NAME_PREFIX}-ZK-Security-Group (if does not exist)
#
#### this -> aws_ebs.sh
#- (?) Create EBS volume ${AWS_RESOURCE_NAME_PREFIX}-ZK-EBS-1 for EC2 ? (if does not exist)
#
#### this -> aws_role.sh
#AWS_BUILTIN_POLICY_ARN_FOR_EC2_TO_ALLOW_SSM=arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM
#- Create role ${AWS_RESOURCE_NAME_PREFIX}-Role-SSM-For-EC2 (if does not exist)
#   - Attach policy $AWS_BUILTIN_POLICY_ARN_FOR_EC2_TO_ALLOW_SSM
#
#### this -> aws_ec2.sh
#- Create instance t3.medium (-ec2 create|ID -> either creates new ec2, or uses given ID)
#   - Use given key_pair
#   - (?) Attach EBS ${AWS_RESOURCE_NAME_PREFIX}-ZK-EBS-1 (if -ec2 ID given, and it does not have attached EBS already)
#   - Attach ${AWS_RESOURCE_NAME_PREFIX}-ZK-Security-Group (if -ec2 ID given, and it does not have attached SECGRP already)
#   - Attach role ${AWS_RESOURCE_NAME_PREFIX}-Role-SSM-For-EC2 (if -ec2 ID given, and it does not have same role already)
#   - Set user data
#        "
#        GIT_PRIVATE_DIR=/home/ec2-user/installed_softwares/hosting_scripts/.git_private
#        mkdir -p $GIT_PRIVATE_DIR
#        touch $GIT_PRIVATE_DIR/VERTICILA_REPO_HTTP_URL
#        echo $VERTICILA_REPO_HTTP_URL >&! $GIT_PRIVATE_DIR/VERTICILA_REPO_HTTP_URL
#        "
#   - Return its public IP & private IP
#
#### this -> aws_secgrp.sh
#- Add security group permissions to ${AWS_RESOURCE_NAME_PREFIX}-ZK-Security-Group (if not already permitted)
#   - TCP 22, myip/32
#   - TCP 8080, privateIP/32 of EC2 instance just started
#
#### this -> aws_ssm
#mkdir -p /home/ec2-user/installed_softwares/
#cd /home/ec2-user/installed_softwares/
#
#sudo yum -y install git
#
#VERTICILA_REPO_HTTP_URL=`cat .git_private/VERTICILA_REPO_HTTP_URL`
#git clone $VERTICILA_REPO_HTTP_URL
#
#MY_PRIVATE_IP=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4`
#$ZK_SETUP_SH -action zk_install -zk_install_mode multi_server -zk_node_count 1 -zk_node_id 1 -zk_node_ip $MY_PRIVATE_IP
#
#$ZK_SETUP_SH -zk_install_mode multi_server -zk_node_count 1 -action zk_start
#$ZK_SETUP_SH -zk_install_mode multi_server -zk_node_count 1 -action zk_status | grep leader >& /dev/null
#if [ $? -eq 0 ]
#then
#    exit 0
#else
#    exit 1
#fi


main()
{
    configureGlobals
    sys_getOS
    sys_installAwsCliIfNotPresent
}



main $@
####### END OF LAST FUNCTION #######
