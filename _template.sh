#!/bin/bash

###########################################################################
# ABOUT: sou_lorem_epsom                                                  #
#        sou_more_lorem_epsom.                                            #
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
    #SOU_A_DEFAULT="sou_a_default"
    #SOU_B_DEFAULT="sou_b_default"

    #SOU_A=$SOU_A_DEFAULT
    #SOU_B=$SOU_B_DEFAULT
    #SOU_C=""

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
    #echo -e
    #echo -e "${GREEN}[ -sou_switch_1 <sou_val_1 | sou_val_2> ]${NC}"
    #echo -e "       Performs the action."
    #echo -e "       sou_val_1       : sou_lorem_epsom"
    #echo -e "       Switch Type : ${YELLOW}Mandatory${NC} if sou_switch_2 is given."
    #echo -e
    #echo -e "${GREEN}[ -sou_switch_2 <A sou_val_as_string> ]${NC}"
    #echo -e "       sou_lorem_epsom."
    #echo -e "       Default     : sou_val_default"
    echo -e
    echo -e
    echo -e "Use Cases:"
    #echo -e "${BLUE}[ sou_val_1 | sou_val_2 ]${NC}"
    #echo -e "$SCRIPT_BASE_NAME -sou_switch_1 sou_val_1 [-sou_switch_2 sou_val_As_string]"
    echo -e "---------------------------------------------------------------"
}


############### Command-line parsing and validation ####################################
parseAndValidateCommandLine()
{
    #sou_mandatorySwitchGiven=0

    #--------------------------------- Parse commandline arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|-help)
                HELP_MODE=1
                ;;
            -s|-shadow)
                SHADOW_MODE=1
                ;;
    #        -sou_switch_1)
    #            SOU_A=$2
    #            sou_mandatorySwitchGiven=1
    #            shift ;;
            *)
                echo -e "${RED}ABORTING: Unknown parameter passed: ${NC}$1${RED}. Script will exit.${NC}"
                HELP_MODE=1
                ;;
        esac
        shift
    done

    shouldAbort=0

    #--------------------------------- Validate -sou_switch_1
    # '-sou_switch_1' is Mandatory
    #if [ $sou_mandatorySwitchGiven -eq 0 ]
    #then
    #    echo -e "${RED}ABORTING: Mandatory switch ${NC}-sou_switch_1${RED} is missing. Script will exit.${NC}"
    #    shouldAbort=1
    #fi

    ## '-sou_switch_1' has legal values
    #case $SOU_A in
    #    sou_val_1)
    #        SOU_B="sou_lorem"
    #        ;;
    #    *)
    #        SOU_B=invalid_command
    #        echo -e "${RED}ABORTING: Unknown argument: ${NC}$SOU_A${RED} associated to switch ${NC}-sou_switch_1${RED}. Script will exit.${NC}"
    #        shouldAbort=1
    #        ;;
    #esac

    #--------------------------------- Print help message
    if [ $HELP_MODE -eq 1 ];
    then
        printHelpMessage
        shouldAbort=1
    fi

    #--------------------------------- Exit at shadow mode
    if [ $SHADOW_MODE -eq 1 ];
    then
        shouldAbort=1
    fi

    #--------------------------------- Abort in case of any issue
    if [ $shouldAbort -eq 1 ];
    then
        exit 1;
    fi
}


############### sou_a_new section ##########################################################
#sou_a_function()
#{
#    echo $1
#    echo -e -n "    -> Script trying to run sou_command ... : "
#    sou_do_something >& /dev/null
#    if [ $? -eq 0 ]
#    then
#        echo -e "${GREEN}OK${NC}"
#    else
#        echo -e "${RED}FAILED${NC}"
#        echo -e "${RED}ABORTING: This script could not run command 'sou_do_something'. Script will exit.${NC}"
#        exit 1;
#    fi
#
#    return
#}

############### Main ##################################################################
main()
{
    configureGlobals
    parseAndValidateCommandLine $@

#    if [ $SOU_A == "sou_val_1" ]
#    then
#        sou_a_function "sou_arg_1"
#    elif [ $SOU_A == "sou_val_2" ]
#    then
#        sou_a_function "sou_arg_2"
#    fi

    exit 0
}

main $@
####### END OF LAST FUNCTION #######
