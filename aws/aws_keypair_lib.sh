#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

###########################################################################
# ABOUT: Library routines on AWS key-pair.                                #
###########################################################################

checkExistence_ofKeyPair_wKeyName()
{
    local shadowMode=$1
    local keyName=$2

    local commandString="aws ec2 describe-key-pairs \
                         --key-name $keyName"
    local passMsg="exists"
    local failMsg="does_not_exist"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    return $?
}

create_aKeyPair_wKeyName_wPemOutputDir()
{
    local shadowMode=$1
    local keyName=$2
    local pemOutDir=$3

    local commandString="aws ec2 create-key-pair \
                         --key-name $keyName \
                         --query 'KeyMaterial' \
                         --output text \
                         > $pemOutDir/$keyName.pem"
    local passMsg="created"
    local failMsg="could_not_create"

    source $VERTICILA_HOME/aws/aws_utils.sh
    executeAwsCommand "\${shadowMode}" "\${commandString}" "\${passMsg}" "\${failMsg}"
    local status=$?
    if [ $status -eq 0 ]
    then
        chmod 400 $pemOutDir/$keyName.pem
    fi
    return $status
}
