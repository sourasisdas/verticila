#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

attachPolicy_toRole_wRoleName_wPolicyArn()
{
    local shadowMode=$1
    local wRoleName=$2
    local wPolicyArn=$3
    local commandString="aws iam attach-role-policy \
                         --role-name $wRoleName\
                         --policy-arn $wPolicyArn"
    local passMsg="attached"
    local failMsg="could_not_attach"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}

checkExistence_ofRole_wRoleName()
{
    local shadowMode=$1
    local wRoleName=$2
    local commandString="aws iam get-role \
                         --role-name $wRoleName"
    local passMsg="exists"
    local failMsg="does_not_exist"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}

create_aRole_wRoleName_wAssumeRolePolicyJsonAbsPath()
{
    local shadowMode=$1
    local wRoleName=$2
    local wAssumeRolePolicyJsonAbsPath=$3
    local commandString="aws iam create-role \
                         --role-name $wRoleName \
                         --assume-role-policy-document file://$wAssumeRolePolicyJsonAbsPath"
    local passMsg="created"
    local failMsg="could_not_create"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}
