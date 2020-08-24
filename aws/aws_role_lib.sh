#!/bin/bash

attach_toRole_wRoleName_wPolicyArn()
{
    local shadowMode=$1
    local wRoleName=$2
    local wPolicyArn=$2
    local commandString="aws iam attach-role-policy \
                         --role-name $wRoleName\
                         --policy-arn $wPolicyArn"
    local passMsg="attached"
    local failMsg="could_not_attach"

    local myAbsolutePath=`echo "$(cd "$(dirname "$0")"; pwd)/$(basename "$0")"`
    local verticilaHome=`dirname $myAbsolutePath | xargs dirname`
    source $verticilaHome/aws/aws_utils.sh
    executeAwsCommandAndExit "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
}

checkExistence_ofRole_wRoleName()
{
    local shadowMode=$1
    local wRoleName=$2
    local commandString="aws iam get-role \
                         --role-name $wRoleName"
    local passMsg="exists"
    local failMsg="does_not_exist"

    local myAbsolutePath=`echo "$(cd "$(dirname "$0")"; pwd)/$(basename "$0")"`
    local verticilaHome=`dirname $myAbsolutePath | xargs dirname`
    source $verticilaHome/aws/aws_utils.sh
    executeAwsCommandAndExit "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
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

    local myAbsolutePath=`echo "$(cd "$(dirname "$0")"; pwd)/$(basename "$0")"`
    local verticilaHome=`dirname $myAbsolutePath | xargs dirname`
    source $verticilaHome/aws/aws_utils.sh
    executeAwsCommandAndExit "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
}
