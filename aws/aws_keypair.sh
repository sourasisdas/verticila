#!/bin/bash

###########################################################################
# ABOUT: Operations on AWS key-pair.                                      #
#        Run srcipt with '-help' for more information.                    #
#                                                                         #
###########################################################################


############### Developer modifiable Configurations ####################################
configureGlobals()
{
    #--------- Include script framework
    MY_ABS_PATH=`echo "$(cd "$(dirname "$0")"; pwd)/$(basename "$0")"`
    VERTICILA_HOME=`dirname $MY_ABS_PATH | xargs dirname`
    source $VERTICILA_HOME/sys/sys_utils.sh
    sys_setFramework

    #--------- Default values of script input parameters
    ACTION_DEFAULT="Invalid_Action"

    #--------- Script input parameters
    ACTION=$ACTION_DEFAULT
    KEYPAIR_NAME=""

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
    echo -e "${GREEN}[ -action <check_exists | create> ]${NC}"
    echo -e "       Performs the action."
    echo -e "       check_exists : Prints 'exists' on-screen and returns status 0 if given"
    echo -e "                      key-pair exists. Else prints 'none' on screen, and returns"
    echo -e "                      status 1."
    echo -e "       create       : Creates key-pair with given <key_name> with switch -key_file."
    echo -e "       Switch Type  : ${YELLOW}Mandatory${NC}."
    echo -e
    echo -e "${GREEN}[ -name <Name of key-pair> ]${NC}"
    echo -e "       Performs the action on the given key-pair."
    echo -e "       Switch Type  : ${YELLOW}Mandatory${NC} if action is check_exists."
    echo -e
    echo -e
    echo -e "Use Cases:"
    echo -e "${BLUE}[ check_exists ]${NC}"
    echo -e "$SCRIPT_BASE_NAME -action check_exists -name N"
    #echo -e "${BLUE}[ create ]${NC}"
    #echo -e "$SCRIPT_BASE_NAME -action create [-sou_switch_2 sou_val_As_string]"
    echo -e "---------------------------------------------------------------"
}


############### Command-line parsing and validation ####################################
parseAndValidateCommandLine()
{
    hasUserProvided_action=0
    hasUserProvided_name=0

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
                ACTION=$2
                hasUserProvided_action=1
                shift ;;
            -name)
                KEYPAIR_NAME=$2
                hasUserProvided_name=1
                shift ;;
           *)
                echo -e "${RED}ABORTING: Unknown parameter passed: ${NC}$1${RED}. Script will exit.${NC}"
                HELP_MODE=1
                ;;
        esac
        shift
    done

    shouldAbort=0

    #-------- Validate -action
    if [ $hasUserProvided_action == 0 ]
    then
        echo -e "${RED}ABORTING: Missing mandatory switch ${NC}-action${RED}. Script will exit.${NC}"
        local shouldAbort=1
    else
        case $ACTION in
            check_exists)
                ;;
            create)
                ;;
            *)
                echo -e "${RED}ABORTING: Unknown value ${NC}$ACTION${RED} passed to switch ${NC}-action${RED}. Script will exit.${NC}"
                local shouldAbort=1
                ;;
        esac
    fi

    #-------- Validate -name
    if [[ $ACTION == "check_exists" && $hasUserProvided_name == 0 ]]
    then
        echo -e "${RED}ABORTING: Missing switch ${NC}-name${RED}, mandatory with action check_exists. Script will exit.${NC}"
        local shouldAbort=1
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


############### AWS Command Preparation and invocation ####################################
checkExistenceOfKeyPairByName()
{
    local keypair=$1

    commandString="aws ec2 describe-key-pairs \
                   --key-name $keypair"

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

createKeyPairWithGivenFilePath()
{
    :
#  1) Create keypair with given file path
#  2) $ aws ec2 create-key-pair --key-name MyKeyPair --query 'KeyMaterial' --output text > MyKeyPa    ir.pem
}


############### Main ##################################################################
main()
{
    configureGlobals
    parseAndValidateCommandLine $@

    if [ $ACTION == "check_exists" ]
    then
        checkExistenceOfKeyPairByName $KEYPAIR_NAME
        # TBD: take a log file in all aws/* scripts, where print aws command logs instead of '/dev/null'
    elif [ $ACTION == "create" ]
    then
        :
        # TBD
    fi

    exit 0
}

main $@
####### END OF LAST FUNCTION #######
