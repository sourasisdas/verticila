#!/usr/bin/bash

###########################################
#### This script manages (starting/stopping etc.) of Zookeeper server node in a multiserver settings.
#### Assumptions:
####    - This script should be run in an AWS EC2 machine by user 'ec2-user'.
####    - The 'verticila' script framework should already be installed at path /home/ec2-user/installed_softwares/verticila
###########################################

configureGlobals()
{
    #-------- Script framework settings
    MY_ABS_PATH=`echo "$(cd "$(dirname "$0")"; pwd)/$(basename "$0")"`
    VERTICILA_HOME=`dirname $MY_ABS_PATH | xargs dirname`
    source $VERTICILA_HOME/sys/sys_utils.sh
    sys_setFramework


    EC2_LOCAL_INSTALLATION_DIR="/home/ec2-user/installed_softwares"
    VERTICILA_EC2_ZK_SETUP_SH="/home/ec2-user/installed_softwares/verticila/zk/zk_setup_core.sh"
    MY_PRIVATE_IP=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4`

    ACTION="Invalid_Action"
    HELP_MODE=0
}

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
    echo -e "${GREEN}[ -action <start_first_node> ]${NC}"
    echo -e "       Performs the action."
    echo -e "       start_first_node : Starts the first Zookeeper node in a multiserver settings."
    echo -e "       Switch Type : ${YELLOW}Mandatory${NC}"
    echo -e
    echo -e "Use Cases:"
    echo -e "${BLUE}[ start_first_node ]${NC}"
    echo -e "$SCRIPT_BASE_NAME -action start_first_node"
    echo -e "---------------------------------------------------------------"
}

parseAndValidateCommandLine()
{
    hasUserProvided_action=0

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -action)
                ACTION="$2"
                hasUserProvided_action=1
                shift ;;
            -h|-help)
                HELP_MODE=1
                ;;
            *)
                echo -e "${RED}ABORTING: Unknown parameter passed: ${NC}$1${RED}. Script will exit.${NC}"
                HELP_MODE=1
                ;;
        esac
        shift
    done

    local shouldAbort=0


    #-------- Validate -action
    if [ $hasUserProvided_action == 0 ]
    then
        echo -e "${RED}ABORTING: Missing mandatory switch ${NC}-action <Action name>${RED}. Script will exit.${NC}"
        local shouldAbort=1
    else
        case $ACTION in
            start_first_node)
                ;;
            *)
                echo -e "${RED}ABORTING: Unknown value ${NC}$ACTION${RED} passed to switch ${NC}-action${RED}. Script will exit.${NC}"
                local shouldAbort=1
                ;;
        esac
    fi


    #-------- Validate -h|-help (Print usage)
    if [ $HELP_MODE -eq 1 ];
    then
        printHelpMessage
        local shouldAbort=1
    fi


    #-------- Abort in case of any issue
    if [ $shouldAbort -eq 1 ];
    then
        exit 1;
    fi
}

startFirstZookeeperNode()
{
    bash $VERTICILA_EC2_ZK_SETUP_SH -install_home $EC2_LOCAL_INSTALLATION_DIR -action zk_install -zk_install_mode multi_server -zk_node_count 1 -zk_node_id 1 -zk_node_ip $MY_PRIVATE_IP
    bash $VERTICILA_EC2_ZK_SETUP_SH -install_home $EC2_LOCAL_INSTALLATION_DIR -zk_install_mode multi_server -zk_node_count 1 -action zk_start
    bash $VERTICILA_EC2_ZK_SETUP_SH -install_home $EC2_LOCAL_INSTALLATION_DIR -zk_install_mode multi_server -zk_node_count 1 -action zk_status | grep leader >& /dev/null
    exit $?
}

main()
{
    configureGlobals
    parseAndValidateCommandLine $@
    case $ACTION in
        start_first_node)
            startFirstZookeeperNode
            ;;
        *)
            ;;
    esac
}

main $@
