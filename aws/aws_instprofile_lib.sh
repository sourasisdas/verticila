#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

checkExistence_ofInstProfile_wInstProfileName()
{
    local shadowMode=$1
    local wInstProfileName=$2
    local commandString="aws iam get-instance-profile \
                         --instance-profile-name $wInstProfileName"
    local passMsg="exists"
    local failMsg="does_not_exist"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}

create_anInstProfile_wInstProfileName()
{
    local shadowMode=$1
    local wInstProfileName=$2
    local commandString="aws iam create-instance-profile \
                         --instance-profile-name $wInstProfileName"
    local passMsg="created"
    local failMsg="could_not_create"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}

addRole_toInstProfile_wInstProfileName_wRoleName()
{
    local shadowMode=$1
    local wInstProfileName=$2
    local wRoleName=$3
    local commandString="aws iam add-role-to-instance-profile \
                         --instance-profile-name $wInstProfileName \
                         --role-name $wRoleName"
    local passMsg="added"
    local failMsg="could_not_add"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}

getArn_ofInstProfile_wInstProfileName()
{
    local scriptMode=$1
    local shadowMode=$2
    local wInstProfileName=$3
    local commandString="aws iam get-instance-profile \
                         --instance-profile-name $wInstProfileName \
                         --query 'InstanceProfile.Arn' \
                         --output text"

    source $VERTICILA_HOME/aws/aws_utils.sh
    local arn=$(executeAwsCommandAndEchoReturnValue "\${shadowMode}" "\${commandString}")
    local status=$?
    echo $arn
    return $status
}
