#!/bin/bash

revokePermission_ofSecGrp_wSecGrpName_wAwsProfileName_wRegion_wProtocol_wPort_wCidr()
{
    local shadowMode=$1
    local wSecGrpName=$2
    local wAwsProfileName=$3
    local wRegion=$4
    local wProtocol=$5
    local wPort=$6
    local wCidr=$7
    local commandString="aws ec2 revoke-security-group-ingress \
                         --group-name $wSecGrpName \
                         --profile $wAwsProfileName \
                         --region $wRegion \
                         --protocol $wProtocol \
                         --port $wPort \
                         --cidr ${wCidr}"
    local passMsg="revoked"
    local failMsg="could_not_revoke"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}

grantPermission_ofSecGrp_wSecGrpName_wAwsProfileName_wRegion_wProtocol_wPort_wCidr()
{
    local shadowMode=$1
    local wSecGrpName=$2
    local wAwsProfileName=$3
    local wRegion=$4
    local wProtocol=$5
    local wPort=$6
    local wCidr=$7
    local commandString="aws ec2 authorize-security-group-ingress \
                         --group-name $wSecGrpName \
                         --profile $wAwsProfileName \
                         --region $wRegion \
                         --protocol $wProtocol \
                         --port $wPort \
                         --cidr ${wCidr}"
    local passMsg="granted"
    local failMsg="could_not_grant"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}

checkExistence_ofSecGrp_wSecGrpName_wAwsProfileName_wRegion()
{
    local shadowMode=$1
    local wSecGrpName=$2
    local wAwsProfileName=$3
    local wRegion=$4
    local commandString="aws ec2 describe-security-groups \
                         --group-name $wSecGrpName \
                         --profile $wAwsProfileName \
                         --region $wRegion"
    local passMsg="exists"
    local failMsg="does_not_exist"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}

create_aSecGrp_wSecGrpName_wDescription_wAwsProfileName_wRegion()
{
    local shadowMode=$1
    local wSecGrpName=$2
    local wDescription=$3
    local wAwsProfileName=$4
    local wRegion=$5
    local commandString="aws ec2 create-security-group \
                         --group-name $wSecGrpName \
                         --profile $wAwsProfileName \
                         --region $wRegion"
    local passMsg="created"
    local failMsg="could_not_create"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}
