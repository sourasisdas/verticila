#!/bin/bash

############### Developer modifiable Configurations #######################
#-------- This script's output settings
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

#--------- Default values of script input parameters
PROFILE_NAME_DEFAULT=$AWS_PROFILE
USER_ACTION_DEFAULT="INVALID_ACTION"
SECURITY_GROUP_DEFAULT=Invalid_Security_Group
REGION_DEFAULT=ap-south-1
PORT_DEFAULT=22
PROTOCOL_DEFAULT=tcp
WHITELISTED_CIDR_DEFAULT="$(curl icanhazip.com 2> /dev/null)""/32"   # Gets this machine's public IP

#--------- Script input parameters
PROFILE_NAME=$PROFILE_NAME_DEFAULT
USER_ACTION=$USER_ACTION_DEFAULT
SECURITY_GROUP=$SECURITY_GROUP_DEFAULT
REGION=$REGION_DEFAULT
PORT=$PORT_DEFAULT
PROTOCOL=$PROTOCOL_DEFAULT
WHITELISTED_CIDR=$WHITELISTED_CIDR_DEFAULT

HELP_MODE=0
SHADOW_MODE=0


############### Command-line parsing and validation ####################

userActionGiven=0
secGrpGiven=0

#-------- Parse variables
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -profile)
            PROFILE_NAME="$2"
            shift
            ;;
        -action)
            USER_ACTION=$2
            shift
            userActionGiven=1
            ;;
        -secgrp)
            SECURITY_GROUP=$2
            secGrpGiven=1
            shift
            ;;
        -region)
            REGION=$2
            shift
            ;;
        -protocol)
            PROTOCOL=$2
            shift
            ;;
        -port)
            PORT=$2
            shift
            ;;
        -cidr)
            WHITELISTED_CIDR=$2
            shift
            ;;
        -h|-help)
            HELP_MODE=1
            ;;
        -s|-shadow)
            SHADOW_MODE=1
            ;;
        *)
            echo -e "${RED}ABORTING: Unknown parameter passed: ${NC}$1${RED}. Script will exit.${NC}"
            HELP_MODE=1
            ;;
    esac
    shift
done

#-------- Validate -h|-help (Print usage)
if [ $HELP_MODE -eq 1 ];
then
    echo -e "---------------------------------------------------------------"
    echo -e "Usage: ${GREEN}$0 [Options]${NC}"
    echo -e
    echo -e "Options:"
    echo -e "${GREEN}[ -h | -help ]"${NC}
    echo -e "       Shows help message and exits."
    echo -e
    echo -e "${GREEN}[ -s | -shadow ]"${NC}
    echo -e "       Runs this script in shadow mode - does not execute any AWS command, just prints"
    echo -e "       it on screen."
    echo -e
    echo -e "${GREEN}[ -action <grant | revoke> ]${NC}"
    echo -e "       Performs the given action."
    echo -e "       Switch Type  : ${YELLOW}Mandatory${NC}"
    echo -e
    echo -e "${GREEN}[ -secgrp <Security group's name> ]${NC}"
    echo -e "       Performs the given action on this security group."
    echo -e "       Switch Type  : ${YELLOW}Mandatory${NC}"
    echo -e
    echo -e "${GREEN}[ -profile <CLI profile's name> ]${NC}"
    echo -e "       Uses the given profile for the action as applicable."
    echo -e "       Default      : $PROFILE_NAME_DEFAULT"
    echo -e
    echo -e "${GREEN}[ -region <User's default region> ]${NC}"
    echo -e "       Performs action on the given AWS region."
    echo -e "       Default      : $REGION_DEFAULT"
    echo -e
    echo -e "${GREEN}[ -protocol <Network protocol name: ssh, http, ...> ]${NC}"
    echo -e "       Performs action for the given network protocol."
    echo -e "       Default      : $PROTOCOL_DEFAULT"
    echo -e
    echo -e "${GREEN}[ -port <Port number for the protocol> ]${NC}"
    echo -e "       Performs action on the given port of the given network protocol."
    echo -e "       Default      : $PORT_DEFAULT"
    echo -e
    echo -e "${GREEN}[ -cidr <CIDR address: uuu.vvv.www.xxx/yy> ]${NC}"
    echo -e "       Performs action on the given CIDR."
    echo -e "       Default      : $WHITELISTED_CIDR_DEFAULT ${BLUE}(IP of this machine in CIDR form)${NC}"
    echo -e
    echo -e "---------------------------------------------------------------"
    exit 0
fi

shouldAbort=0

#-------- Validate -action
if [ $userActionGiven -eq 0 ]
then
    echo -e "${RED}ABORTING: Mandatory switch ${NC}-action${RED} is missing. Script will exit.${NC}"
    shouldAbort=1
fi

if [ $USER_ACTION == "revoke" ]
then
    SCRIPT_ACTION=revoke-security-group-ingress
elif [ $USER_ACTION == "grant" ]
then
    SCRIPT_ACTION=authorize-security-group-ingress
else
    SCRIPT_ACTION=invalid_command
    echo -e "${RED}ABORTING: Unknown argument: ${NC}$USER_ACTION${RED} associated to switch ${NC}-action${RED}. Script will exit.${NC}"
    shouldAbort=1
fi

#-------- Validate -secgrp
if [ $secGrpGiven -ne 1 ]
then
    echo -e "${RED}ABORTING: Missing mandatory switch: ${NC}-secgrp${RED}. Script will exit.${NC}"
    shouldAbort=1
fi

#-------- Abort in case of any issue
if [ $shouldAbort -eq 1 ];
then
    exit 1;
fi

############### AWS Command Preparation and invocation ##################

#-------- Prepare command-line history file
CLI_HISTORY_FILE=~/.aws_cli_history
CLI_HISTORY_FILE_TEMPORARY=~/.aws_cli_history.tmp

create_or_trim_cli_history_file()
{
    touch $CLI_HISTORY_FILE
    rm -rf $CLI_HISTORY_FILE_TEMPORARY
    touch $CLI_HISTORY_FILE_TEMPORARY
    tail -2000 $CLI_HISTORY_FILE >> $CLI_HISTORY_FILE_TEMPORARY
    rm -rf $CLI_HISTORY_FILE
    touch $CLI_HISTORY_FILE
    mv $CLI_HISTORY_FILE_TEMPORARY $CLI_HISTORY_FILE
}

if [ $SHADOW_MODE -eq 0 ]
then
    $(create_or_trim_cli_history_file)
fi


#-------- Execute command

commandExecutionStatus=1

commandString="aws ec2 $SCRIPT_ACTION \
               --profile $PROFILE_NAME \
               --group-name $SECURITY_GROUP \
               --region $REGION \
               --protocol $PROTOCOL \
               --port $PORT \
               --cidr ${WHITELISTED_CIDR}"

if [ $SHADOW_MODE -eq 0 ]
then
    $commandString
    commandExecutionStatus=$?
else
    echo $commandString
fi


#-------- Record command execution in cli history
get_timestamp()
{
    date "+%d:%m:%Y:%H:%M:%S"
}

if [ $commandExecutionStatus -eq 0 ]
then
    if [ $USER_ACTION == "grant" ]
    then
        echo $(get_timestamp)" # SECGRP:$SECURITY_GROUP # Action:GrantedInboundPermission @ CIDR:${WHITELISTED_CIDR} @ Protocol:$PROTOCOL @ Port:$PORT @ Profile:$PROFILE_NAME @ Region:$REGION" >> $CLI_HISTORY_FILE
    elif [ $USER_ACTION == "revoke" ]
    then
        echo $(get_timestamp)" # SECGRP:$SECURITY_GROUP # Action:RevokedInboundPermission @ CIDR:${WHITELISTED_CIDR} @ Protocol:$PROTOCOL @ Port:$PORT @ Profile:$PROFILE_NAME @ Region:$REGION" >> $CLI_HISTORY_FILE
    else
        echo "No action taken"
    fi
fi
