#!/bin/bash

############### Developer modifiable Configurations ####################################
configureGlobals()
{
    #--------- Include script framework
    MY_ABS_PATH=`echo "$(cd "$(dirname "$0")"; pwd)/$(basename "$0")"`
    VERTICILA_HOME=`dirname $MY_ABS_PATH | xargs dirname`
    source $VERTICILA_HOME/sys/sys_utils.sh
    sys_setFramework

    #--------- Default values of script input parameters
    PROFILE_NAME_DEFAULT=$AWS_PROFILE
    USER_ACTION_DEFAULT="INVALID_ACTION"
    SECURITY_GROUP_DEFAULT=Invalid_Security_Group
    REGION_DEFAULT=ap-south-1
    PORT_DEFAULT=22
    PROTOCOL_DEFAULT=tcp
    WHITELISTED_CIDR_DEFAULT="$(curl icanhazip.com 2> /dev/null)""/32"   # Gets this machine's public IP
    DESCRIPTION_DEFAULT='"Default-description-of-security-group"'
    
    #--------- Script input parameters
    PROFILE_NAME=$PROFILE_NAME_DEFAULT
    USER_ACTION=$USER_ACTION_DEFAULT
    SECURITY_GROUP=$SECURITY_GROUP_DEFAULT
    REGION=$REGION_DEFAULT
    PORT=$PORT_DEFAULT
    PROTOCOL=$PROTOCOL_DEFAULT
    WHITELISTED_CIDR=$WHITELISTED_CIDR_DEFAULT
    DESCRIPTION=$DESCRIPTION_DEFAULT
    
    HELP_MODE=0
    SHADOW_MODE=0
}


############### Print help message #####################################################
printHelpMessage()
{
    SCRIPT_BASE_NAME=`basename $0`
    echo -e "---------------------------------------------------------------"
    echo -e "Usage: ${GREEN}$SCRIPT_BASE_NAME [Options]${NC}"
    echo -e
    echo -e "Options:"
    echo -e "${GREEN}[ -h | -help ]"${NC}
    echo -e "       Shows help message and exits."
    echo -e
    echo -e "${GREEN}[ -s | -shadow ]"${NC}
    echo -e "       Runs this script in shadow mode - does not execute any AWS command, just prints"
    echo -e "       it on screen."
    echo -e
    echo -e "${GREEN}[ -action <grant | revoke | check_exists | create> ]${NC}"
    echo -e "       Performs the action."
    echo -e "       grant        : Grants permission to given security group."
    echo -e "       revoke       : Revokes permission from given security group."
    echo -e "       check_exists : Prints 'exists' on-screen and returns status 0 if given"
    echo -e "                      security group exists. Else prints 'none' on screen, and"
    echo -e "                      returns status 1."
    echo -e "       create       : Creates security group with given name."
    echo -e "       Switch Type  : ${YELLOW}Mandatory${NC}"
    echo -e
    echo -e "${GREEN}[ -name <Security group's name> ]${NC}"
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
    echo -e "${GREEN}[ -description <Description-of-the-to-be-created-security-group> ]${NC}"
    echo -e "       Sets the given description for the to-be-created security group. Description must be without spaces."
    echo -e "       Default      : $DESCRIPTION_DEFAULT"
    echo -e
    echo -e
    echo -e "Use Cases:"
    echo -e "${BLUE}[ grant | revoke ]${NC}"
    echo -e "$SCRIPT_BASE_NAME -action grant        -name S [-profile P] [-region R] [-protocol T] [-port I] [-cidr C]"
    echo -e "$SCRIPT_BASE_NAME -action revoke       -name S [-profile P] [-region R] [-protocol T] [-port I] [-cidr C]"
    echo -e "${BLUE}[ check_exists ]${NC}"
    echo -e "$SCRIPT_BASE_NAME -action check_exists -name S [-profile P] [-region R]"
    echo -e "${BLUE}[ create ]${NC}"
    echo -e "$SCRIPT_BASE_NAME -action create       -name S [-profile P] [-region R] [-description D]"
    echo -e "---------------------------------------------------------------"
}

############### Command-line parsing and validation ####################################
parseAndValidateCommandLine()
{
    userActionGiven=0
    nameGiven=0
    
    #--------------------------------- Parse commandline arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|-help)
                HELP_MODE=1
                ;;
            -s|-shadow)
                SHADOW_MODE=1
                ;;
            -action)
                USER_ACTION=$2
                userActionGiven=1
                shift ;;
            -name)
                SECURITY_GROUP=$2
                nameGiven=1
                shift ;;
            -profile)
                PROFILE_NAME="$2"
                shift ;;
            -region)
                REGION=$2
                shift ;;
            -protocol)
                PROTOCOL=$2
                shift ;;
            -port)
                PORT=$2
                shift ;;
            -cidr)
                WHITELISTED_CIDR=$2
                shift ;;
            -description)
                DESCRIPTION=$2
                shift ;;
            *)
                echo -e "${RED}ABORTING: Unknown parameter passed: ${NC}$1${RED}. Script will exit.${NC}"
                HELP_MODE=1
                ;;
        esac
        shift
    done
    
    shouldAbort=0
    
    #--------------------------------- Validate -action
    # '-action' is Mandatory
    if [ $userActionGiven -eq 0 ]
    then
        echo -e "${RED}ABORTING: Mandatory switch ${NC}-action${RED} is missing. Script will exit.${NC}"
        shouldAbort=1
    fi

    # '-action' has legal values
    case $USER_ACTION in
        revoke)
            SCRIPT_ACTION=revoke-security-group-ingress
            ;;
        grant)
            SCRIPT_ACTION=authorize-security-group-ingress
            ;;
        check_exists)
            SCRIPT_ACTION=describe-security-groups
            ;;
        create)
            SCRIPT_ACTION=create-security-group
            ;;
        *)
            SCRIPT_ACTION=invalid_command
            echo -e "${RED}ABORTING: Unknown argument: ${NC}$USER_ACTION${RED} associated to switch ${NC}-action${RED}. Script will exit.${NC}"
            shouldAbort=1
            ;;
    esac
    
    
    #--------------------------------- Validate -name
    if [ $nameGiven -ne 1 ]
    then
        echo -e "${RED}ABORTING: Missing mandatory switch: ${NC}-name${RED}. Script will exit.${NC}"
        shouldAbort=1
    fi

    #--------------------------------- Print help message
    if [ $HELP_MODE -eq 1 ];
    then
        printHelpMessage
        shouldAbort=1
    fi
    
    #--------------------------------- Abort in case of any issue
    if [ $shouldAbort -eq 1 ];
    then
        exit 1;
    fi
}



############### AWS Command Preparation and invocation #################################
revokeOrGrantPermission()
{
    commandString="aws ec2 $SCRIPT_ACTION \
                   --profile $PROFILE_NAME \
                   --group-name $SECURITY_GROUP \
                   --region $REGION \
                   --protocol $PROTOCOL \
                   --port $PORT \
                   --cidr ${WHITELISTED_CIDR}"

    if [ $SHADOW_MODE -eq 0 ]
    then
        echo "################ $commandString" >& /dev/null
        eval $commandString >& /dev/null
    else
        echo $commandString
    fi
    exit $?
}

checkIfSecurityGroupExists()
{
    commandString="aws ec2 $SCRIPT_ACTION \
                   --profile $PROFILE_NAME \
                   --group-name $SECURITY_GROUP \
                   --region $REGION"

    if [ $SHADOW_MODE -eq 0 ]
    then
        echo "################ $commandString" >& /dev/null
        eval $commandString >& /dev/null
        if [ $? -eq 0 ]
        then
            echo "exists"
            exit 0
        else
            echo "none"
            exit 1
        fi
    else
        echo $commandString
    fi
    exit $?
}

createSecurityGroup()
{
    commandString="aws ec2 $SCRIPT_ACTION \
                   --profile $PROFILE_NAME \
                   --group-name $SECURITY_GROUP \
                   --region $REGION \
                   --description $DESCRIPTION "

    if [ $SHADOW_MODE -eq 0 ]
    then
        echo "################ $commandString" >& /dev/null
        eval $commandString >& /dev/null
    else
        echo $commandString
    fi
    exit $?
}



############### Main ##################################################################
main()
{
    configureGlobals
    parseAndValidateCommandLine $@
    case $USER_ACTION in
        revoke|grant)
            revokeOrGrantPermission
            ;;
        check_exists)
            checkIfSecurityGroupExists
            ;;
        create)
            createSecurityGroup
            ;;
        *)
            :
            ;;
    esac
}

main $@
####### END OF LAST FUNCTION #######
