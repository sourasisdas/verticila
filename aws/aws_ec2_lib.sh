#!/bin/bash
# Given instance, check its state. Return one of: "noexist, running, stopped, terminated, pending"
    
# Given instance, expand its EBS volume (create and use code from aws_ebs.sh) , and reboot to use the expanded volume

# Given instance, enquire its EBS volume (create and use code from aws_ebs.sh) size/type etc.


# Get instanceId by filter on specific attributes
#aws ec2 describe-instances --filters "Name=instance-type,Values=t2.micro" --query "Reservations[].Instances[].InstanceId"


RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Create tags
#aws ec2 create-tags --resources i-5203422c --tags Key=Name,Value=MyInstance


addName_toEc2_wInstId_wName()
{
    local shadowMode=$1
    local wInstId=$2
    local wName=$3

    local commandString="aws ec2 create-tags \
                         --resources $wInstId \
                         --tags Key=Name,Value=$wName"
    local passMsg="added"
    local failMsg="could_not_add"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}


checkExistence_ofEc2_wInstId()
{
    local shadowMode=$1
    local wInstId=$2

    local commandString="aws ec2 describe-instances \
                         --instance-ids $wInstId \
                         --query 'Reservations[].Instances[].State.Name' \
                         --output text"
    local passMsg="exists"
    local failMsg="does_not_exist"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}

createAndGetId_ofEc2_wAmiId_wInstType_wKeyName_wSecGrpName()
{
    local scriptMode=$1
    local shadowMode=$2
    local wAmiId=$3
    local wInstType=$4
    local wKeyName=$5
    local wSecGrpName=$6

    local commandString="aws ec2 run-instances \
                         --image-id $wAmiId \
                         --count 1 \
                         --instance-type $wInstType \
                         --key-name $wKeyName \
                         --security-groups $wSecGrpName \
                         --query 'Instances[].InstanceId' \
                         --output text"

    source $VERTICILA_HOME/aws/aws_utils.sh
    local instance_id=$(executeAwsCommandAndEchoReturnValue "\${shadowMode}" "\${commandString}")
    local status=$?
    if [ $scriptMode -eq 0 ]
    then
        if [ $status -eq 0 ]
        then
            echo -e "${GREEN}created $instance_id${NC}"
        else
            echo -e "${RED}could_not_create${NC}"
        fi
    fi
    echo $instance_id
    return $status
}


create_anEc2_wAmiId_wInstType_wKeyName_wSecGrpName()
{
    local shadowMode=$1
    local wAmiId=$2
    local wInstType=$3
    local wKeyName=$4
    local wSecGrpName=$5

    local commandString="aws ec2 run-instances \
                         --image-id $wAmiId \
                         --count 1 \
                         --instance-type $wInstType \
                         --key-name $wKeyName \
                         --security-groups $wSecGrpName"
    local passMsg="created"
    local failMsg="could_not_create"
    local logFileName="log_ec2_create"

    source $VERTICILA_HOME/aws/aws_utils.sh
    local status=executeAwsCommandAndLogOutput "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}" "\${logFileName}"

    if [ $status -eq 0 ]
    then
        local instanceId=`cat ~/.verticila/$logFileName | jq -r '.Reservations[].Instances[].InstanceId'`
        echo -e ${GREEN}instance_id $instanceId${NC}

        local privateIp=`cat ~/.verticila/$logFileName | jq -r '.Reservations[].Instances[].PrivateIpAddress'`
        echo -e ${GREEN}private_ip $privateIp${NC}

        local publicIp=`cat ~/.verticila/$logFileName | jq -r '.Reservations[].Instances[].PublicIpAddress'`
        echo -e ${GREEN}public_ip $publicIp${NC}
    fi

    return $status
}

getInstProfileArn_ofEc2_wInstId()
{
    local scriptMode=$1
    local shadowMode=$2
    local wInstId=$3

    local commandString="aws ec2 describe-instances \
                         --instance-ids $wInstId \
                         --query 'Reservations[].Instances[].IamInstanceProfile[].Arn' \
                         --output text"

    source $VERTICILA_HOME/aws/aws_utils.sh
    local profile_inst_arn=$(executeAwsCommandAndEchoReturnValue "\${shadowMode}" "\${commandString}")
    local status=$?
    echo $profile_inst_arn
    return $?
}

associateInstProfile_toEc2_wInstId_wInstProfileName()
{
    local shadowMode=$1
    local wInstId=$2
    local wInstProfileName=$3

    local commandString="aws ec2 associate-iam-instance-profile \
                         --instance-id $wInstId \
                         --iam-instance-profile Name=$wInstProfileName"
    local passMsg="associated"
    local failMsg="could_not_associate"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}

getPrivateIpv4_ofEc2_wInstId()
{
    local shadowMode=$1
    local wInstId=$2

    local commandString="aws ec2 describe-instances \
                         --instance-ids $wInstId \
                         --query 'Reservations[].Instances[].PrivateIpAddress' \
                         --output text"

    source $VERTICILA_HOME/aws/aws_utils.sh
    local retVal=$(executeAwsCommandAndEchoReturnValue "\${shadowMode}" "\${commandString}")
    local status=$?
    echo $retVal
    return $?
}

getPublicIpv4_ofEc2_wInstId()
{
    local shadowMode=$1
    local wInstId=$2

    local commandString="aws ec2 describe-instances \
                         --instance-ids $wInstId \
                         --query 'Reservations[].Instances[].PublicIpAddress' \
                         --output text"

    source $VERTICILA_HOME/aws/aws_utils.sh
    local retVal=$(executeAwsCommandAndEchoReturnValue "\${shadowMode}" "\${commandString}")
    local status=$?
    echo $retVal
    return $?
}
