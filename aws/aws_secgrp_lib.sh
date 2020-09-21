#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

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


checkInboundPermission_ofSecGrp_wSecGrpName_wProtocol_wPort_wCidr()
{
    local scriptMode=$1
    local shadowMode=$2
    local wSecGrpName=$3
    local wProtocol=$4
    local wPort=$5
    local wCidr=$6
    local commandString="aws ec2 describe-security-groups \
                         --group-names $wSecGrpName \
                         --filters Name=ip-permission.from-port,Values=$wPort \
                                   Name=ip-permission.cidr,Values=$wCidr \
                                   Name=ip-permission.protocol,Values=$wProtocol \
                         --query 'SecurityGroups[0].GroupName'
                         --output text"

    source $VERTICILA_HOME/aws/aws_utils.sh
    local secGrpName=$(executeAwsCommandAndEchoReturnValue "\${shadowMode}" "\${commandString}")
    local status=$?
    if [ $status -ne 0 ]
    then
        echo -e "${RED}could_not_check${NC}"
        return 1
    fi
    if [ $scriptMode -eq 0 ]
    then
        if [[ $secGrpName != "None" ]]
        then
            echo -e "${GREEN}permitted${NC}"
        else
            echo -e "${RED}not_permitted${NC}"
        fi
    fi
    if [[ $secGrpName != "None" ]]
    then
        status=0
    else
        status=1
    fi
    return $status
}

checkOutboundPermission_ofSecGrp_wSecGrpName_wProtocol_wPort_wCidr()
{
    local scriptMode=$1
    local shadowMode=$2
    local wSecGrpName=$3
    local wProtocol=$4
    local wPort=$5
    local wCidr=$6
    local commandString="aws ec2 describe-security-groups \
                         --group-names $wSecGrpName \
                         --filters Name=egress.ip-permission.from-port,Values=$wPort \
                                   Name=egress.ip-permission.cidr,Values=$wCidr \
                                   Name=egress.ip-permission.protocol,Values=$wProtocol \
                         --query 'SecurityGroups[0].GroupName'
                         --output text"

    source $VERTICILA_HOME/aws/aws_utils.sh
    local secGrpName=$(executeAwsCommandAndEchoReturnValue "\${shadowMode}" "\${commandString}")
    local status=$?
    if [ $status -ne 0 ]
    then
        echo -e "${RED}could_not_check${NC}"
        return 1
    fi
    if [ $scriptMode -eq 0 ]
    then
        if [[ $secGrpName != "None" ]]
        then
            echo -e "${GREEN}permitted${NC}"
        else
            echo -e "${RED}not_permitted${NC}"
        fi
    fi
    if [[ $secGrpName != "None" ]]
    then
        status=0
    else
        status=1
    fi
    return $status
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
                         --description $wDescription \
                         --profile $wAwsProfileName \
                         --region $wRegion"
    local passMsg="created"
    local failMsg="could_not_create"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}
