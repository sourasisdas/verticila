#!/bin/bash
# Given instance, check its state. Return one of: "noexist, running, stopped, terminated, pending"
    
# Given instance, expand its EBS volume (create and use code from aws_ebs.sh) , and reboot to use the expanded volume

# Given instance, enquire its EBS volume (create and use code from aws_ebs.sh) size/type etc.

# Create tags
#aws ec2 create-tags --resources i-5203422c --tags Key=Name,Value=MyInstance

# Get instanceId by filter on specific attributes
#aws ec2 describe-instances --filters "Name=instance-type,Values=t2.micro" --query "Reservations[].Instances[].InstanceId"

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
                         --security-groups $wSecGrpName \
                         --query 'Instances[].InstanceId' \
                         --output text"

    source $VERTICILA_HOME/aws/aws_utils.sh
    #local isNumber="$(sys_checkIfNonNegativeInteger $1)"
    local instance_id=$(executeAwsCommandAndEchoReturnValue "\${shadowMode}" "\${commandString}")
    local status=$?
    echo $instance_id
    return $?
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
        echo instance_id $instanceId

        local privateIp=`cat ~/.verticila/$logFileName | jq -r '.Reservations[].Instances[].PrivateIpAddress'`
        echo private_ip $privateIp

        local publicIp=`cat ~/.verticila/$logFileName | jq -r '.Reservations[].Instances[].PublicIpAddress'`
        echo public_ip $publicIp
    fi

    return $status
}

getInstProfileArn_ofEc2_wInstId()
{
    local shadowMode=$1
    local wInstId=$2

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
