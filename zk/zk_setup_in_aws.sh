#!/bin/bash

##############################################################################
# ABOUT: This script can be used for distributed setup of Ensemble ZooKeeper #
#        in AWS EC2 from scratch, completely remotely using AWS CLI and AWS  #
#        SSM.                                                                #
##############################################################################

### Input : 
#            -aws_key_pair <nairp-keypair-hosted-admin>
#            -aws_resource_name_prefix NAIRP
#            -ec2 create|ID

############### Developer modifiable Configurations #######################
configureGlobals()
{
    MY_ABS_PATH=`echo "$(cd "$(dirname "$0")"; pwd)/$(basename "$0")"`
    VERTICILA_HOME=`dirname $MY_ABS_PATH | xargs dirname`
    source $VERTICILA_HOME/sys/sys_utils.sh
    sys_setFramework


    VERTICILA_REPO_HTTP_URL="https://github.com/sourasisdas/verticila.git"
    VERTICILA_EC2_ZK_SETUP_AWS_LOCAL_SH="/home/ec2-user/installed_softwares/verticila/zk/zk_setup_aws_local.sh"


    VERTICILA_AWS_SECGRP_SH="$VERTICILA_HOME/aws/aws_secgrp.sh"


    AWS_RESOURCE_NAME_PREFIX_DEFAULT="ZK"
    SECURITY_GROUP_DEFAULT="ZK-Security-Group"
    PROFILE_NAME_DEFAULT=$AWS_PROFILE
    REGION_DEFAULT=ap-south-1


    SECURITY_GROUP=$SECURITY_GROUP_DEFAULT
    AWS_RESOURCE_NAME_PREFIX=$AWS_RESOURCE_NAME_PREFIX_DEFAULT
    PROFILE_NAME=$PROFILE_NAME_DEFAULT
    REGION=$REGION_DEFAULT
}


createSecurityGroupIfDoesNotExist()
{
    echo -e -n "-> Script checking existence of AWS security group '$SECURITY_GROUP' ... : "
    $VERTICILA_AWS_SECGRP_SH -action check_exists -name $SECURITY_GROUP -profile $PROFILE_NAME -region $REGION >& /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "${GREEN}OK${NC}"
        return
    else
        echo -e "${YELLOW}Does Not Exist${NC}"
    fi

    echo -e -n "-> Script creating AWS security group '$SECURITY_GROUP' ... : "
    $VERTICILA_AWS_SECGRP_SH -action create -name $SECURITY_GROUP -profile $PROFILE_NAME -region $REGION -description "Security-group-for-Zookeeper-Ensemble" >& /dev/null
    if [ $? -ne 0 ]
    then
        echo -e "${RED}Failed${NC}"
        echo -e "${RED}ABORTING: Failed creating new security group ${NC}$SECURITY_GROUP${RED}. Script will exit.${NC}"
        exit 1
    else
        echo -e "${GREEN}OK${NC}"
    fi
}


createPolicyIfDoesNotExist()
{
    # TBD
    #### this -> aws_role.sh
    #AWS_BUILTIN_POLICY_ARN_FOR_EC2_TO_ALLOW_SSM=arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM
    #- Create role ${AWS_RESOURCE_NAME_PREFIX}-Role-SSM-For-EC2 (if does not exist)
    #   - Attach policy $AWS_BUILTIN_POLICY_ARN_FOR_EC2_TO_ALLOW_SSM
    return
}


# Call only if "-ec2 create" is passed
createEc2()
{
    # TBD
    #### this -> aws_ec2.sh
    #- Create instance t3.medium (-ec2 create|ID -> either creates new ec2, or uses given ID)
    #   - Use given key_pair
    #   - (?) Attach EBS ${AWS_RESOURCE_NAME_PREFIX}-ZK-EBS-1 (if -ec2 ID given, and it does not have attached EBS already)
    #   - Attach ${AWS_RESOURCE_NAME_PREFIX}-ZK-Security-Group (if -ec2 ID given, and it does not have attached SECGRP already)
    #   - Attach role ${AWS_RESOURCE_NAME_PREFIX}-Role-SSM-For-EC2 (if -ec2 ID given, and it does not have same role already)
    #   - Set user data (if anything needed)
    #   - Return its ID, public IP & private IP
    return
}


addPermissionsToSecurityGroup()
{
    # TBD
    #### this -> aws_secgrp.sh
    #- Add security group permissions to ${AWS_RESOURCE_NAME_PREFIX}-ZK-Security-Group (if not already permitted)
    #   - TCP 22, myip/32
    #   - TCP 8080, privateIP/32 of EC2 instance just started
    return
}

startFirstZookeeperNodeOnEc2()
{
    local execution_timeout=180
    local timeout_seconds=120
    local ec2_instance_id=$1
    local output_s3_bucket_name=nairp-s3-bucket-auto-hosting
    local region=ap-south-1

    local remote_command_to_run="\
    mkdir -p /home/ec2-user/installed_softwares/ ; \
    cd /home/ec2-user/installed_softwares/ ; \
    sudo yum -y install git ; \
    git clone https://github.com/sourasisdas/verticila.git ; \
    $VERTICILA_EC2_ZK_SETUP_AWS_LOCAL_SH -action start_first\
    "

    local ssm_command="aws ssm send-command --document-name "\""AWS-RunShellScript"\"" --document-version "\""1"\"" --targets '[{"\""Key"\"":"\""InstanceIds"\"","\""Values"\"":["\""$ec2_instance_id"\""]}]' --parameters '{"\""commands"\"":["\""$remote_command_to_run"\""],"\""workingDirectory"\"":["\"""\""],"\""executionTimeout"\"":["\""$execution_timeout"\""]}' --timeout-seconds $timeout_seconds --max-concurrency "\""50"\"" --max-errors "\""0"\"" --output-s3-bucket-name "\""$output_s3_bucket_name"\"" --region $region"
    echo $ssm_command

#    aws ssm send-command --document-name "AWS-RunShellScript" --document-version "1" --targets '[{"Key":"InstanceIds","Values":["i-05ed6cada2f61563c"]}]' --parameters '{"commands":["/home/ec2-user/x.sh sou_ssm_dir \"1.2.3.4|5.6.7.8=9\""],"workingDirectory":[""],"executionTimeout":["3600"]}' --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --output-s3-bucket-name "nairp-s3-bucket-auto-hosting" --region ap-south-1
}


main()
{
    configureGlobals

    sys_installAwsCliIfNotPresent

    createSecurityGroupIfDoesNotExist

    #### TBD: this -> aws_ebs.sh: Create EBS volume ${AWS_RESOURCE_NAME_PREFIX}-ZK-EBS-1 for EC2 ? (if does not exist)

    createPolicyIfDoesNotExist

    # if "-ec2 create" is passed. Returns [ID, Public IP, Private IP]
    createEc2
    # else
    # -ec2 ID must have been passed

    addPermissionsToSecurityGroup

    startFirstZookeeperNodeOnEc2 "12345678890"

}



main $@
####### END OF LAST FUNCTION #######
