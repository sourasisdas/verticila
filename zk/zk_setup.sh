#!/bin/bash

###########################################################################
# ABOUT: This script can be used for distributed setup of Ensembled       #
#        Zookeeper.                                                       #
###########################################################################

############### Developer modifiable Configurations #######################
configureGlobals()
{
    #-------- This script's output settings
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[0;33m'
    NC='\033[0m'


    #-------- Global installation settings
    INSTALL_HOME=$HOME/installed_softwares


    #-------- Zookeeper download settings
    ZK_VERSION="zookeeper-3.6.1"
    ZK_BIN_NAME=apache-$ZK_VERSION-bin
    ZK_BIN_NAME_TAR=$ZK_BIN_NAME.tar.gz
    ZK_BIN_NAME_SHA=$ZK_BIN_NAME_TAR.sha512
    ZK_BIN_NAME_ASC=$ZK_BIN_NAME_TAR.asc
    ZK_DOWNLOAD_LINK=https://downloads.apache.org/zookeeper/$ZK_VERSION
    ZK_TAR_DOWNLOAD_LINK=$ZK_DOWNLOAD_LINK/$ZK_BIN_NAME_TAR
    ZK_SHA_DOWNLOAD_LINK=$ZK_DOWNLOAD_LINK/$ZK_BIN_NAME_SHA
    ZK_ASC_DOWNLOAD_LINK=$ZK_DOWNLOAD_LINK/$ZK_BIN_NAME_ASC


    #-------- Zookeeper install settings
    ZK_INSTALL_PATH=$INSTALL_HOME/zookeeper
    ZK_INSTALL_BIN_PATH=$ZK_INSTALL_PATH/$ZK_BIN_NAME
    ZK_CONFIG_PATH=$ZK_INSTALL_BIN_PATH/conf


    #-------- Zookeeper configuration settings
    ZK_CONFIG_FILE_NAME_PREFIX="zoo_nairp"
    ZK_DATADIR_BASE=$ZK_INSTALL_PATH/nairp_zookeeper_datadir
    ZK_LOGFILES_DIR=$ZK_INSTALL_PATH/nairp_zookeeper_logfiles
    ZK_TICKTIME=2000
    ZK_INITLIMIT=5
    ZK_SYNCLIMIT=2
    ZK_AUTOPURGE_SNAPRETAINCOUNT=3
    ZK_AUTOPURGE_PURGEINTERVAL=1
    ZK_RECONFIGENABLED=true
    ZK_STANDALONEENABLED=false
    ZK_JUTE_MAXBUFFER=0x9fffff
    ZK_SKIPACL=yes
    ZK_CLIENTPORT_STARTING=2181
    ZK_SERVERPORT_STARTING=2888
    ZK_SERVERPORT_2ND_OFFSET=1000
    ZK_MINIMUM_NODE_COUNT=1
    ZK_MAXIMUM_NODE_COUNT=11
    ZK_NODE_COUNT_DEFAULT=3
    ZK_INSTALL_MODE_DEFAULT=single_server
    ZK_NODE_IP_DEFAULT=localhost
    ZK_ALL_NODE_IP_ARRAY=()


    #-------- Solr download settings
    SL_VERSION="7.7.3"
    SL_BIN_NAME=solr-$SL_VERSION
    SL_BIN_NAME_TAR=$SL_BIN_NAME.tgz
    SL_BIN_NAME_SHA=$SL_BIN_NAME_TAR.sha512
    SL_BIN_NAME_ASC=$SL_BIN_NAME_TAR.asc
    SL_DOWNLOAD_LINK=https://downloads.apache.org/lucene/solr/$SL_VERSION
    SL_TAR_DOWNLOAD_LINK=$SL_DOWNLOAD_LINK/$SL_BIN_NAME_TAR
    SL_SHA_DOWNLOAD_LINK=$SL_DOWNLOAD_LINK/$SL_BIN_NAME_SHA
    SL_ASC_DOWNLOAD_LINK=$SL_DOWNLOAD_LINK/$SL_BIN_NAME_ASC


    #-------- Solr install settings
    SL_INSTALL_PATH=$INSTALL_HOME/solr
    SL_INSTALL_BIN_PATH=$SL_INSTALL_PATH/$ZK_BIN_NAME


    #-------- Pre-parsing initializations
    ACTION="invalid"
    HELP_MODE=0
    SHADOW_MODE=0

    ZK_INSTALL_MODE=$ZK_INSTALL_MODE_DEFAULT
    ZK_NODE_COUNT=$ZK_NODE_COUNT_DEFAULT
    ZK_NODE_ID=1
    ZK_NODE_IP=$ZK_NODE_IP_DEFAULT
    ZK_ALL_NODE_IP_STR=$ZK_NODE_IP
}
###########################################################################

checkIfNonNegativeInteger()
{
    #local regexForInt='^[0-9]+$'
    local regexForInt='^[1-9]+[0-9]*$|^0$'
    if ! [[ $1 =~ $regexForInt ]] ; then
       echo 0
    else
       echo 1
    fi
}

checkIfNumberBetween0And255()
{
    local isValid=0
    local isNumber="$(checkIfNonNegativeInteger $1)"
    if [ $isNumber -eq 0 ]
    then
        echo "0"
    elif [[ $1 -ge 0 && $1 -le 255 ]]
    then
        echo "1"
    else
        echo "0"
    fi
}

checkIfValidIpv4()
{
    local isValid=0
    local ip=$1
    if [ $ip == "localhost" ]
    then
        isValid=1
    else
        local numberOfFields=`echo $ip | awk -F. '{ print NF }'`
        if [ $numberOfFields -eq 4 ]
        then
            read f1 f2 f3 f4 <<< $( echo ${ip} | awk -F. '{print $1" "$2" "$3" "$4}' )
            local isNumber1="$(checkIfNumberBetween0And255 $f1)"
            local isNumber2="$(checkIfNumberBetween0And255 $f2)"
            local isNumber3="$(checkIfNumberBetween0And255 $f3)"
            local isNumber4="$(checkIfNumberBetween0And255 $f4)"
            if [[ $isNumber1 -eq 1 && ( $isNumber2 -eq 1 && ( $isNumber3 -eq 1 && $isNumber4 -eq 1 ) ) ]]
            then
                isValid=1
            fi
        fi
    fi
    echo "$isValid"
}

getIpsIfValidIpv4String()
{
    # Checks if input is pipe '|' separated valid ip addresses (possibly single IP 'localhost')
    #         Populates ZK_ALL_NODE_IP_ARRAY if all good. 
    #         Else makes ZK_ALL_NODE_IP_ARRAY empty.

    local isValid=0
    local ipStr=$1
    local regexForLocalhost='.*localhost.*'
    if [[ $ipStr =~ $regexForLocalhost ]]
    then
        if [ $ipStr != "localhost" ]
        then
            isValid=0
        else
            isValid=1
            ZK_ALL_NODE_IP_ARRAY+=( $ipStr )
        fi
    else
        isValid=1
        local numberOfFields=`echo $ipStr | awk -F'|' '{ print NF }'`
        for i in $(seq 1 $numberOfFields);
        do
            local ip=`echo $ipStr | awk -v k=$i -F'|' '{print $k}'`
            local isValidIp="$(checkIfValidIpv4 $ip)"
            if [ $isValidIp -eq 0 ]
            then
                isValid=0
                break
            else
                ZK_ALL_NODE_IP_ARRAY+=( "$ip" )
            fi
        done
    fi
    if [ $isValid -eq 0 ]
    then
        ZK_ALL_NODE_IP_ARRAY=()
    fi
}


############### Command line parsing and validation ########################
parseAndValidateCommandLine()
{
    #-------- Parse
    local hasUserProvided_action=0
    local hasUserProvided_zk_node_id=0
    local hasUserProvided_zk_node_ip=0
    local hasUserProvided_zk_all_node_ip=0
    local regexForInt='^[0-9]+$'
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -action)
                ACTION="$2"
                hasUserProvided_action=1
                shift
                ;;
            -zk_install_mode)
                ZK_INSTALL_MODE="$2"
                shift
                ;;
            -zk_node_count)
                ZK_NODE_COUNT=$2
                shift
                ;;
            -zk_node_id)
                ZK_NODE_ID=$2
                hasUserProvided_zk_node_id=1
                shift
                ;;
            -zk_node_ip)
                ZK_NODE_IP=$2
                hasUserProvided_zk_node_ip=1
                shift
                ;;
            -zk_all_node_ip)
                ZK_ALL_NODE_IP_STR=$2
                hasUserProvided_zk_all_node_ip=1
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

    local shouldAbort=0

    #-------- Validate -action
    if [ $hasUserProvided_action == 0 ]
    then
        echo -e "${RED}ABORTING: Missing mandatory switch ${NC}-action <Action name>${RED}. Script will exit.${NC}"
        local shouldAbort=1
    else
        case $ACTION in
            zk_install)
                ;;
            zk_start)
                ;;
            zk_stop)
                ;;
            zk_status)
                ;;
            sl_install)
                ;;
            *)
                echo -e "${RED}ABORTING: Unknown value ${NC}$ACTION${RED} passed to switch ${NC}-action${RED}. Script will exit.${NC}"
                local shouldAbort=1
                ;;
        esac
    fi


    #-------- Validate -zk_install_mode
    if [[ $ZK_INSTALL_MODE != "single_server" && $ZK_INSTALL_MODE != "multi_server" ]];
    then
        echo -e "${RED}ABORTING: Invalid value ${NC}$ZK_INSTALL_MODE${RED} passed to switch ${NC}-zk_install_mode${RED}. Script will exit.${NC}"
        local shouldAbort=1
    fi


    #-------- Validate -zk_node_count
    if ! [[ $ZK_NODE_COUNT -ge $ZK_MINIMUM_NODE_COUNT && ( $ZK_NODE_COUNT =~ $regexForInt && $ZK_NODE_COUNT -le $ZK_MAXIMUM_NODE_COUNT ) ]];
    then
        echo -e "${RED}ABORTING: Invalid value ${NC}$ZK_NODE_COUNT${RED} passed to switch ${NC}-zk_node_count${RED}. Script will exit.${NC}"
        local shouldAbort=1
    fi
    #if [[ $ZK_NODE_COUNT -le 1 && $ZK_INSTALL_MODE == "multi_server" ]];
    #then
    #    echo -e "${RED}ABORTING: ${NC}-zk_node_count${RED} must be greater than 1, if -zk_install_mode is multi_server. Script will exit.${NC}"
    #    local shouldAbort=1
    #fi
    
    
    #-------- Validate -zk_node_id
    if ! [[ $ZK_NODE_ID -ge 1 && ( $ZK_NODE_ID =~ $regexForInt && $ZK_NODE_ID -le $ZK_NODE_COUNT ) ]];
    then
        echo -e "${RED}ABORTING: Invalid value ${NC}$ZK_NODE_ID${RED} passed to switch ${NC}-zk_node_id${RED}. Value must be between 1 and $ZK_NODE_COUNT (since -zk_node_count has value $ZK_NODE_COUNT). Script will exit.${NC}"
        local shouldAbort=1
    fi
    if [[ $ACTION == "zk_install" && ($ZK_INSTALL_MODE == "multi_server" && ( $ZK_NODE_COUNT -gt 1 && $hasUserProvided_zk_node_id -eq 0 ) ) ]];
    then
        echo -e "${RED}ABORTING: Switch ${NC}-zk_node_id <id>${RED} is mandatory if zk_install_mode is multi_server and zk_node_count is greater than 1.${NC}"
        local shouldAbort=1
    fi
    
    
    #-------- Validate -zk_node_ip
    if [[ $ACTION == "zk_install" && ($ZK_INSTALL_MODE == "multi_server" && $hasUserProvided_zk_node_ip -eq 0 ) ]];
    then
        echo -e "${RED}ABORTING: Switch ${NC}-zk_node_ip <ip address>${RED} is mandatory if zk_install_mode is multi_server.${NC}"
        local shouldAbort=1
    fi
    isValidZkNodeIp="$(checkIfValidIpv4 $ZK_NODE_IP)"
    if [ $isValidZkNodeIp -ne 1 ]
    then
        echo -e "${RED}ABORTING: Argument ${NC}$ZK_NODE_IP${RED} passed to ${NC}-zk_node_ip${RED} is not a valid IP address.${NC}"
        local shouldAbort=1
    fi
    
    
    #-------- Validate -zk_all_node_ip
    if [ $hasUserProvided_zk_all_node_ip -eq 0 ];
    then
        if [[ $ACTION == "zk_install" && ($ZK_INSTALL_MODE == "multi_server" && $ZK_NODE_COUNT -gt 1 ) ]];
        then
            echo -e "${RED}ABORTING: Switch ${NC}-zk_all_node_ip <pipe '|' separated ip addresses>${RED} is mandatory if zk_install_mode is multi_server and zk_node_count is greater than 1.${NC}"
            local shouldAbort=1
        else
            ZK_ALL_NODE_IP_STR=$ZK_NODE_IP
        fi
    elif [[ $hasUserProvided_zk_all_node_ip -eq 1 && ( $ZK_INSTALL_MODE == "single_server" || $ZK_NODE_COUNT -eq 1 ) ]];
    then
        echo -e "${RED}ABORTING: Switch ${NC}-zk_all_node_ip${RED} must be skipped if zk_install_mode is single_server, or, if zk_node_count is 1.${NC}"
        local shouldAbort=1
    fi
    
    #---- Validate that input to -zk_all_node_ip is valid string of ip addresses
    isValidAllNodeIpStr=1
    getIpsIfValidIpv4String $ZK_ALL_NODE_IP_STR  # Populates ZK_ALL_NODE_IP_ARRAY if valid
    if [[ $hasUserProvided_zk_all_node_ip -eq 1 && ${#ZK_ALL_NODE_IP_ARRAY[@]} -eq 0 ]]
    then
        echo -e "${RED}ABORTING: Argument ${NC}$ZK_ALL_NODE_IP_STR${RED} passed to ${NC}-zk_all_node_ip${RED} is not a valid string of IP addresses.${NC}"
        isValidAllNodeIpStr=0
        local shouldAbort=1
    fi
    
    #---- Validate that input to -zk_all_node_ip contains the IP associated with -zk_node_ip
    isZkNodeIpInZkAllNodeIp=0
    for ip in ${ZK_ALL_NODE_IP_ARRAY[*]}
    do
        if [ $ip == $ZK_NODE_IP ]
        then
            isZkNodeIpInZkAllNodeIp=1
            break
        fi
    done
    if [[ $isZkNodeIpInZkAllNodeIp -eq 0 && ( $isValidAllNodeIpStr -eq 1 && $isValidZkNodeIp -eq 1 ) ]]
    then
        echo -e "${RED}ABORTING: Argument ${NC}$ZK_ALL_NODE_IP_STR${RED} associated with ${NC}-zk_all_node_ip${RED} does not contain IP address ${NC}$ZK_NODE_IP${RED} associated with ${NC}-zk_node_ip${RED}.${NC}"
        local shouldAbort=1
    fi
    
    #---- Validate that input to -zk_all_node_ip has as many IPs as value of -zk_node_count
    numberOfIpsInZkAllNodeIp=${#ZK_ALL_NODE_IP_ARRAY[*]}
    correctNumberOfIpsInZkAllNodeIp=1
    if [[ $isValidAllNodeIpStr -eq 1 && ( $ZK_INSTALL_MODE == multi_server && $numberOfIpsInZkAllNodeIp -ne $ZK_NODE_COUNT ) ]]
    then
        if [ $ACTION == "zk_install" ]
        then
            echo -e "${RED}ABORTING: Argument ${NC}$ZK_ALL_NODE_IP_STR${RED} passed to ${NC}-zk_all_node_ip${RED} must have ${NC}$ZK_NODE_COUNT${RED} IPs specified. ${NC}$numberOfIpsInZkAllNodeIp${RED} IPs have been given instead.${NC}"
            local shouldAbort=1
        fi
        correctNumberOfIpsInZkAllNodeIp=0
    fi
    
    #---- Validate that input to -zk_all_node_ip does not have duplicate IP specified multiple times
    duplicateIpFoundInZkAllNodeIp=0
    #for ipa in ${ZK_ALL_NODE_IP_ARRAY[*]} ;
    for ipa_index in ${!ZK_ALL_NODE_IP_ARRAY[@]}
    do
        #for ipb in ${ZK_ALL_NODE_IP_ARRAY[*]} ;
        for ipb_index in ${!ZK_ALL_NODE_IP_ARRAY[@]}
        do
            #if [ $ipa -eq $ipb ]
            if [[ $ipa_index -ne $ipb_index && ${ZK_ALL_NODE_IP_ARRAY[$ipa_index]} == ${ZK_ALL_NODE_IP_ARRAY[$ipb_index]} ]]
            then
                duplicateIpFoundInZkAllNodeIp=1
                break 2
            fi
        done
    done
    if [ $duplicateIpFoundInZkAllNodeIp -eq 1 ]
    then
        echo -e "${RED}ABORTING: Argument ${NC}$ZK_ALL_NODE_IP_STR${RED} passed to ${NC}-zk_all_node_ip${RED} contains at least one duplicate IP. All IPs provided must be unique.${NC}"
        local shouldAbort=1
    fi
    
    #---- Validate that order of IPs provided with -zk_all_node_ip corresponds to ID of this node
    if [[ $ZK_INSTALL_MODE == multi_server && ( $isValidAllNodeIpStr -eq 1 && ( $correctNumberOfIpsInZkAllNodeIp -eq 1 && ( $duplicateIpFoundInZkAllNodeIp -eq 0 && $isZkNodeIpInZkAllNodeIp -eq 1 ) ) ) ]]
    then
        zkNodeIdMinusOne=$(($ZK_NODE_ID - 1))
        if [ ${ZK_ALL_NODE_IP_ARRAY[$zkNodeIdMinusOne]} != $ZK_NODE_IP ]
        then
            echo -e "${RED}ABORTING: IP ${NC}$ZK_NODE_IP${RED}, associated with ${NC}-zk_node_ip${RED}, should be in position ${NC}$ZK_NODE_ID${RED} in the argument ${NC}$ZK_ALL_NODE_IP_STR${RED} passed to ${NC}-zk_all_node_ip${RED}. This is because ${NC}-zk_node_id${RED} has value ${NC}2${RED}.${NC}" 
            local shouldAbort=1
        fi
    fi
    
    
    #-------- Validate -s|-shadow (Runs in shadow mode - upto parsing and input validation)
    if [ $SHADOW_MODE -eq 1 ];
    then
        local shouldAbort=1
    fi
    
    
    #-------- Validate -h|-help (Print usage)
    if [ $HELP_MODE -eq 1 ];
    then
        echo -e "---------------------------------------------------------------"
        echo -e "Usage: ${GREEN}$0 [Options]${NC}"
        echo -e
        echo -e
        echo -e "Options:"
        echo -e "${GREEN}[ -h | -help ]"${NC}
        echo -e "       Shows help message and exits."
        echo -e
        echo -e "${GREEN}[ -s | -shadow ]"${NC}
        echo -e "       Runs this script in shadow mode - upto parsing and input validation."
        echo -e
        echo -e "${GREEN}[ -action <zk_install | zk_start | zk_stop | zk_status | sl_install | TBD > ]${NC}"
        echo -e "       zk_install   : Downloads, installs and configures Zookeeper."
        echo -e "       zk_start     : Starts running Zookeeper server."
        echo -e "       zk_stop      : Stops running Zookeeper server."
        echo -e "       zk_status    : Shows running status of a Zookeeper server."
        echo -e "       sl_install   : Downloads, installs and configures Solr."
        echo -e "       Switch Type  : ${YELLOW}Mandatory${NC}"
        echo -e
        echo -e "${GREEN}[ -zk_install_mode <single_server | multi_server> ]${NC}"
        echo -e "       single_server: Sets up multi-node Zookeeper installation in single server."
        echo -e "                      For development environment."
        echo -e "       multi_server : Performs multi-node Zookeeper installation in multiple servers."
        echo -e "                      For production environment."
        echo -e "       Default      : $ZK_INSTALL_MODE_DEFAULT"
        echo -e
        echo -e "${GREEN}[ -zk_node_count <Integer between ${ZK_MINIMUM_NODE_COUNT} and ${ZK_MAXIMUM_NODE_COUNT} both inclusive> ]${NC}"
        echo -e "       Number of Zookeeper nodes to start. In single_server zk_install_mode,"
        echo -e "       all nodes will be started on same server. In multi_server zk_install_mode,"
        echo -e "       each node will be started on a separate server."
        echo -e "       Default      : $ZK_NODE_COUNT_DEFAULT"
        echo -e
        echo -e "${GREEN}[ -zk_node_id <Integer between 1 and <-zk_node_count's value> both inclusive> ]${NC}"
        echo -e "       Externally assigned ID of the Zookeeper node which is going to start"
        echo -e "       on this machine."
        echo -e "       Switch Type  : ${YELLOW}Mandatory${NC} if zk_install_mode is multi_server and zk_node_count is"
        echo -e "                      greater than 1. Will be ignored otherwise and default value"
        echo -e "                      will be considered when applicable."
        echo -e "       Default      : 1"
        echo -e
        echo -e "${GREEN}[ -zk_node_ip <ip address, or 'localhost'> ]${NC}"
        echo -e "       IP address of this node in 'xxx.xxx.xxx.xxx' format, or 'localhost'."
        echo -e "       Switch Type  : ${YELLOW}Mandatory${NC} if zk_install_mode is multi_server."
        echo -e "       Default      : localhost"
        echo -e
        echo -e "${GREEN}[ -zk_all_node_ip <pipe '|' separated ip addresses> ]${NC}"
        echo -e "       Pipe '|' separated IP addresses of all server nodes corresponding to the order"
        echo -e "       of their ID, in 'xxx.xxx.xxx.xxx|yyy.yyy.yyy.yyy|...' format, including the IP"
        echo -e "       of this node."
        echo -e "       For example, in a 2-node multi_server setup, if this server has ID 1, and IP"
        echo -e "       203.182.111.109, and another server has ID 2, and IP 111.333.222.200, then the"
        echo -e "       switch should be passed as '-zk_all_node_ip 203.182.111.109|111.333.222.200'."
        echo -e "       Switch Type  : ${YELLOW}Mandatory${NC} if zk_install_mode is multi_server and zk_node_count is"
        echo -e "                      is greater than 1."
        echo -e "                    : ${YELLOW}Must be skipped${NC} otherwise, in which case the value of -zk_node_ip"
        echo -e "                      will be used by script."
        echo -e
        echo -e
        echo -e "Use Cases:"
        echo -e "${BLUE}[ zk_install : multi_server ]${NC}"
        echo -e "$0 -action zk_install -zk_install_mode multi_server -zk_node_count 5 -zk_node_id 4 -zk_node_ip 13.14.15.16 -zk_all_node_ip "\""1.2.3.4|5.6.7.8|9.10.11.12|13.14.15.16|17.18.19.20"\"""
        echo -e "${BLUE}[ zk_install : single_server ]${NC}"
        echo -e "$0 -action zk_install [ -zk_node_count 5 ] [ -zk_node_ip 1.2.3.4 ]"
        echo -e "${BLUE}[ zk_start | zk_stop | zk_status : multi_server ]${NC}"
        echo -e "$0 -action zk_start  -zk_install_mode multi_server"
        echo -e "$0 -action zk_stop   -zk_install_mode multi_server"
        echo -e "$0 -action zk_status -zk_install_mode multi_server"
        echo -e "${BLUE}[ zk_start | zk_stop | zk_status : single_server ]${NC}"
        echo -e "$0 -action zk_start  [ -zk_node_count 5 ]"
        echo -e "$0 -action zk_stop   [ -zk_node_count 5 ]"
        echo -e "$0 -action zk_status [ -zk_node_count 5 ]"
        echo -e "---------------------------------------------------------------"
        local shouldAbort=1
    fi
    
    #-------- Abort in case of any issue
    if [ $shouldAbort -eq 1 ];
    then
        exit 1;
    fi
}
###########################################################################


############### Determine OS (Supported: MAC, RHEL, UBUNTU) ###############
determineOS()
{
    OS=RHEL
    
    sw_vers -productName 2> /dev/null | grep -i "Mac OS" > /dev/null
    if [ $? -eq 0 ]
    then
        OS=MAC
    else
        lsb_release -a 2> /dev/null | grep -i ubuntu > /dev/null
        if [ $? -eq 0 ]
        then
            OS=UBUNTU
        fi
    fi
    echo -e "-> Script has detected OS: ${BLUE}$OS${NC}"
}
############################################################################


############### Set installer based on $OS #################################
setInstallerBasedOnOS()
{
    INSTALLER="yum"
    if [ $OS == "MAC" ]
    then
        INSTALLER="brew"
    elif [ $OS == "UBUNTU" ]
    then
        INSTALLER="apt"
    fi
    echo -e "-> Script has set installer: ${BLUE}$INSTALLER${NC}"
}
############################################################################


############### Check if installers are installed  #########################
validateInstallationOfInstallers()
{
    which $INSTALLER | grep $INSTALLER >& /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "-> Checking installation of $INSTALLER: ${GREEN}OK${NC}"
    else
        echo -e "-> Checking installation of $INSTALLER: ${RED}FAILED${NC}"
        echo -e "${RED}ABORTING: This script depends on the package installer '$INSTALLER'. Please install it in the system manually and rerun this script.${NC}"
        exit 1;
    fi
}
############################################################################


############### Check for packages required ################################
checkForRequiredPackages()
{
    requiredPackagesArr=()
    requiredPackagesArr+=('wget')
    requiredPackagesArr+=('sed')
    
    if [ $OS == "MAC" ]
    then
        requiredPackagesArr+=('shasum')
        requiredPackagesArr+=('java')
    elif [ $OS == "UBUNTU" ]
    then
        requiredPackagesArr+=('sha512sum')
        requiredPackagesArr+=('java=openjdk-8-jdk')    # package_binary_name = package_release_name
    else # $OS == RHEL
        requiredPackagesArr+=('sha512sum')
        requiredPackagesArr+=('java-1.8.0-openjdk-devel')
    fi
    
    missingPackagesArr=()
    missingPackagesIndex=0
    
    for package in ${requiredPackagesArr[*]}
    do
        # If "package_binary_name = package_release_name" is present in $package, then strip out the binary name and the package name
        packageBinaryName=`echo $package | awk -F= '{ print $1 }'`
        packageReleaseName=`echo $package | awk -F= '{ print $2 }'`
    
        which $packageBinaryName | grep $packageBinaryName >& /dev/null
        if [ $? -eq 0 ]
        then
            echo -e "-> Checking installation of $package: ${GREEN}OK${NC}"
        else
            echo -e "-> Checking installation of $package: ${YELLOW}NOT INSTALLED${NC}"
            missingPackagesArr[$missingPackagesIndex]="$package"
            let "missingPackagesIndex+=1"
        fi
    done
    
    if [ $missingPackagesIndex -ne 0 ]
    then
        echo -e -n "-> Script will attempt to install The following missing packages:"
        for package in ${missingPackagesArr[*]}
        do
            echo -e -n " $package"
        done
        echo
    fi
}
############################################################################


############### Try to install missing packages#############################
installMissingPackages()
{
    #-------- Update/Refresh the installer first
    if [ $OS == "UBUNTU" ]
    then
        echo -e -n "    -> Script trying to update $INSTALLER ... : "
        sudo $INSTALLER -y update >& /dev/null
        if [ $? -eq 0 ]
        then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED${NC}"
            echo -e "${RED}ABORTING: This script depends on update of the installer '$INSTALLER'. Please update it in the system manually and rerun this script.${NC}"
            exit 1;
        fi
    fi
    
    #-------- Modify installer to add special terms to it
    TEMP_INSTALLER=$INSTALLER
    if [ $OS == "UBUNTU" ]
    then
        TEMP_INSTALLER="sudo $TEMP_INSTALLER -y"
    fi
    
    #-------- Install missing packages
    for package in ${missingPackagesArr[*]}
    do
        echo -e -n "    -> Script trying to install $package ... : "
    
        # If "package_binary_name = package_release_name" is present in $package, then strip out the binary name and the package name
        packageBinaryName=`echo $package | awk -F= '{ print $1 }'`
        packageReleaseName=`echo $package | awk -F= '{ print $2 }'`
    
        $TEMP_INSTALLER install $packageReleaseName >& /dev/null
    
        if [ $? -eq 0 ]
        then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED${NC}"
            echo -e "${RED}ABORTING: This script depends on the package '$package'. Please install it in the system manually and rerun this script.${NC}"
            exit 1;
        fi
    done
}
############################################################################



############### Download, verify & install Zookeeper #######################
downloadAndValidateZookeeper()
{
    #-------- Prepare Zookeeper installation directory
    mkdir -p $INSTALL_HOME
    
    rm -rf $ZK_INSTALL_PATH
    mkdir -p $ZK_INSTALL_PATH
    
    cd $ZK_INSTALL_PATH
    
    #-------- Download release tar from origin
    echo -e -n "-> Downloading zookeeper release tar ... : "
    wget $ZK_TAR_DOWNLOAD_LINK >& /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        echo -e "${RED}ABORTING: Please install manually.${NC}"
        exit 1;
    fi
    
    #-------- Download SHA from download origin
    echo -e -n "-> Downloading zookeeper SHA ... : "
    wget $ZK_SHA_DOWNLOAD_LINK >& /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        echo -e "${RED}ABORTING: Please install manually.${NC}"
        exit 1;
    fi
    
    #-------- Prepare SHA from download origin
    rm -rf sha.origin
    cut -d' ' -f1 $ZK_BIN_NAME_SHA >& sha.origin
    
    #-------- Compute SHA of downloaded tar
    rm -rf sha.local
    if [ $OS == "MAC" ]
    then
        shasum -a 512 $ZK_BIN_NAME_TAR | cut -d' ' -f1 >& sha.local
    else
        sha512sum $ZK_BIN_NAME_TAR | cut -d' ' -f1 >& sha.local
    fi
    
    #-------- Compare SHAs
    diff sha.local sha.origin >& /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "-> Zookeeper SHA verification: ${GREEN}OK${NC}"
    else
        echo -e "-> Zookeeper SHA verification: ${RED}FAILED${NC}"
        echo -e "${RED}ABORTING: Please install manually.${NC}"
        exit 1;
    fi
    
    #-------- Download ASC key file
    echo -e -n "-> Downloading zookeeper .asc key file ... : "
    wget $ZK_ASC_DOWNLOAD_LINK >& /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        echo -e "${RED}ABORTING: Please install manually.${NC}"
        exit 1;
    fi
    
    #-------- Validation using GPG
    echo -e -n "-> Verifying zookeeper authenticity : "
    #Refer:
    #         https://www.apache.org/dyn/closer.lua/zookeeper/zookeeper-3.6.1/apache-zookeeper-3.6.1-bin.tar.gz
    #         https://www.apache.org/info/verification.html
    echo -e "${RED}TBD${NC}"
    
    
    #-------- Untar
    tar -xvzf $ZK_BIN_NAME_TAR >& /dev/null
    
    #-------- Cleanup
    rm -rf sha.* $ZK_BIN_NAME_TAR $ZK_BIN_NAME_SHA $ZK_BIN_NAME_ASC >& /dev/null
    cd $INSTALL_HOME
}
############################################################################


############### Prepare Zookeeper configuration file(s) ####################
prepareZookeeperConfigFile()
{
    echo -e -n "-> Preparing zookeeper config file: "
    local LOOP_ITER_COUNT=$ZK_NODE_COUNT
    if [ $ZK_INSTALL_MODE == "multi_server" ]
    then
        local LOOP_ITER_COUNT=1
    fi
    
    for i in $(seq 1 $LOOP_ITER_COUNT);
    do
        #-------- Create the config file
        if [ $ZK_INSTALL_MODE == "multi_server" ]
        then
            local ZK_CONFIG_FILE_PATH=$ZK_CONFIG_PATH/${ZK_CONFIG_FILE_NAME_PREFIX}.cfg
        else
            local ZK_CONFIG_FILE_PATH=$ZK_CONFIG_PATH/${ZK_CONFIG_FILE_NAME_PREFIX}_${i}.cfg
        fi
        rm -rf $ZK_CONFIG_FILE_PATH >& /dev/null
        touch $ZK_CONFIG_FILE_PATH >& /dev/null
        if [ $? -ne 0 ]
        then
            echo -e "${RED}FAILED${NC}"
            echo -e "${RED}ABORTING: Failed creating new file $ZK_CONFIG_FILE_PATH. Please fix the problem manually, or, install manually.${NC}"
            exit 1;
        fi
    
        #-------- Create and Write the dataDir path
        if [ $ZK_INSTALL_MODE == "multi_server" ]
        then
            local ZK_DATADIR=$ZK_DATADIR_BASE
        else
            local ZK_DATADIR=$ZK_DATADIR_BASE/$i
        fi
        mkdir -p $ZK_DATADIR >& /dev/null
        echo "dataDir=$ZK_DATADIR" >> $ZK_CONFIG_FILE_PATH
        #ZK_DATADIR_ESCAPED=$(echo $ZK_DATADIR | sed 's_/_\\/_g')
        #sed -i -e "s/^dataDir=.*/dataDir=$ZK_DATADIR_ESCAPED/g" $ZK_CONFIG_FILE_PATH
        if [ $? -ne 0 ]
        then
            echo -e "${RED}FAILED${NC}"
            echo -e "${RED}ABORTING: Failed writing to file $ZK_CONFIG_FILE_PATH. Please fix the problem manually, or, install manually.${NC}"
            exit 1;
        fi
    
        #-------- Write other configs
        echo "tickTime=$ZK_TICKTIME" >> $ZK_CONFIG_FILE_PATH
        echo "initLimit=$ZK_INITLIMIT" >> $ZK_CONFIG_FILE_PATH
        echo "syncLimit=$ZK_SYNCLIMIT" >> $ZK_CONFIG_FILE_PATH
        echo "autopurge.snapRetainCount=$ZK_AUTOPURGE_SNAPRETAINCOUNT" >> $ZK_CONFIG_FILE_PATH
        echo "autopurge.purgeInterval=$ZK_AUTOPURGE_PURGEINTERVAL" >> $ZK_CONFIG_FILE_PATH
        echo "jute.maxbuffer=$ZK_JUTE_MAXBUFFER" >> $ZK_CONFIG_FILE_PATH
        echo "skipACL=$ZK_SKIPACL" >> $ZK_CONFIG_FILE_PATH
        echo "reconfigEnabled=$ZK_RECONFIGENABLED" >> $ZK_CONFIG_FILE_PATH
        echo "standaloneEnabled=$ZK_STANDALONEENABLED" >> $ZK_CONFIG_FILE_PATH
        local ZK_DYNAMIC_CONFIG_FILE_PATH=${ZK_CONFIG_FILE_PATH}.dynamic
        echo "dynamicConfigFile=$ZK_DYNAMIC_CONFIG_FILE_PATH" >> $ZK_CONFIG_FILE_PATH

        ##-------- Write the clientPort value
        #if [ $ZK_INSTALL_MODE == "single_server" ]
        #then
        #    local ZK_CLIENTPORT=$(($ZK_CLIENTPORT_STARTING + $i - 1)) 
        #else
        #    local ZK_CLIENTPORT=$ZK_CLIENTPORT_STARTING
        #fi
        #echo "clientPort=$ZK_CLIENTPORT" >> $ZK_CONFIG_FILE_PATH
    
        #-------- Write the server id, port assignments to dynamic configuration file
        rm -rf $ZK_DYNAMIC_CONFIG_FILE_PATH >& /dev/null
        touch $ZK_DYNAMIC_CONFIG_FILE_PATH /dev/null
        if [ $? -ne 0 ]
        then
            echo -e "${RED}FAILED${NC}"
            echo -e "${RED}ABORTING: Failed creating new file $ZK_DYNAMIC_CONFIG_FILE_PATH. Please install manually.${NC}"
            exit 1;
        fi
        for j in $(seq 1 $ZK_NODE_COUNT);
        do
            if [ $ZK_INSTALL_MODE == "single_server" ]
            then
                local ZK_SERVERPORT_1ST=$(($ZK_SERVERPORT_STARTING + $j - 1))
                local ZK_SERVERPORT_2ND=$(($ZK_SERVERPORT_1ST + $ZK_SERVERPORT_2ND_OFFSET))
                local ZK_CLIENTPORT=$(($ZK_CLIENTPORT_STARTING + $j - 1)) 
                echo "server.$j=$ZK_NODE_IP:$ZK_SERVERPORT_1ST:$ZK_SERVERPORT_2ND:participant;$ZK_CLIENTPORT" >> $ZK_DYNAMIC_CONFIG_FILE_PATH
            else
                local ZK_SERVERPORT_1ST=$ZK_SERVERPORT_STARTING
                local ZK_SERVERPORT_2ND=$(($ZK_SERVERPORT_1ST + $ZK_SERVERPORT_2ND_OFFSET))
                local ZK_CLIENTPORT=$ZK_CLIENTPORT_STARTING
                echo "server.$j=${ZK_ALL_NODE_IP_ARRAY[$j - 1]}:$ZK_SERVERPORT_1ST:$ZK_SERVERPORT_2ND:participant;$ZK_CLIENTPORT" >> $ZK_DYNAMIC_CONFIG_FILE_PATH
            fi
        done
    
        #-------- Write the server id to 'myid' file
        local MYID_FILE=$ZK_DATADIR/myid
        rm -rf $MYID_FILE >& /dev/null
        touch $MYID_FILE >& /dev/null
        if [ $? -ne 0 ]
        then
            echo -e "${RED}FAILED${NC}"
            echo -e "${RED}ABORTING: Failed creating new file $MYID_FILE. Please install manually.${NC}"
            exit 1;
        fi
        echo $i >> $MYID_FILE
        if [ $? -ne 0 ]
        then
            echo -e "${RED}FAILED${NC}"
            echo -e "${RED}ABORTING: Failed writing to file $MYID_FILE. Please install manually.${NC}"
            exit 1;
        fi
    
    done

    #-------- Create file zookeeper-env.sh
    local ZK_ENV_FILE_NAME=zookeeper-env.sh
    local ZK_ENV_FILE_PATH=$ZK_CONFIG_PATH/$ZK_ENV_FILE_NAME
    rm -rf $ZK_ENV_FILE_PATH >& /dev/null
    touch $ZK_ENV_FILE_PATH >& /dev/null
    if [ $? -ne 0 ]
    then
        echo -e "${RED}FAILED${NC}"
        echo -e "${RED}ABORTING: Failed creating new file $ZK_ENV_FILE_NAME. Please install manually.${NC}"
        exit 1;
    fi
    echo "ZOO_LOG_DIR="\""$ZK_LOGFILES_DIR"\""" >> $ZK_ENV_FILE_PATH
    if [ $? -ne 0 ]
    then
        echo -e "${RED}FAILED${NC}"
        echo -e "${RED}ABORTING: Failed writing to file $ZK_ENV_FILE_PATH. Please install manually.${NC}"
        exit 1;
    fi
    echo "ZOO_LOG4J_PROP="\""INFO,ROLLINGFILE"\""" >> $ZK_ENV_FILE_PATH
    echo 'SERVER_JVMFLAGS="-Xms2048m -Xmx2048m -verbose:gc -XX:+PrintHeapAtGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps -XX:+PrintTenuringDistribution -XX:+PrintGCApplicationStoppedTime -Xloggc:$ZOO_LOG_DIR/zookeeper_gc.log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=9 -XX:GCLogFileSize=20M"' >> $ZK_ENV_FILE_PATH


    echo -e "${GREEN}OK${NC}"
}
############################################################################


############### Start | Stop | Status check of Zookeeper server(s) #########
validateZookeeperServer()
{
    echo -e -n "-> Checking existence of zookeeper server script: "
    local ZK_SERVER_BINARY=$ZK_INSTALL_BIN_PATH/bin/zkServer.sh
    if [ ! -f $ZK_SERVER_BINARY ]
    then
        echo -e "${RED}FAILED${NC}"
        echo -e "${RED}ABORTING: Zookeeper server binary ${NC}$ZK_SERVER_BINARY${RED} does not exist. Please install Zookeeper first using this script and then retry running.${NC}"
        exit 1;
    fi
    echo -e "${GREEN}OK${NC}"
}

takeActionOnZookeeperServer()
{
    local action=$1   # Possibly 'start','stop','status'
    cd $ZK_INSTALL_BIN_PATH

    ACTION_LOG_FILE=$ZK_INSTALL_BIN_PATH/zk_action.log

    rm -rf $ACTION_LOG_FILE >& /dev/null
    touch $ACTION_LOG_FILE >& /dev/null

    local LOOP_ITER_COUNT=$ZK_NODE_COUNT
    if [ $ZK_INSTALL_MODE == "multi_server" ]
    then
        local LOOP_ITER_COUNT=1
    fi
    
    local status=1
    for i in $(seq 1 $LOOP_ITER_COUNT);
    do
        if [ $ZK_INSTALL_MODE == "multi_server" ]
        then
            local ZK_CONFIG_FILE_NAME=${ZK_CONFIG_FILE_NAME_PREFIX}.cfg
        else
            local ZK_CONFIG_FILE_NAME=${ZK_CONFIG_FILE_NAME_PREFIX}_${i}.cfg
        fi


        local ZK_CONFIG_FILE_PATH=$ZK_CONFIG_PATH/${ZK_CONFIG_FILE_NAME}
        if [ ! -f $ZK_CONFIG_FILE_PATH ]
        then
            echo "Using config: $ZK_CONFIG_FILE_PATH" >> $ACTION_LOG_FILE
            echo "Config file does not exist" >> $ACTION_LOG_FILE
        else
            ./bin/zkServer.sh $action $ZK_CONFIG_FILE_NAME 2>> $ACTION_LOG_FILE >> $ACTION_LOG_FILE
        fi
    done
}

parseOutZookeerStartingLogFromActionLogFile()
{
    while read line; do
        local thisIsConfigLine=`echo $line | egrep "Using config" | wc -l`
        local thisIsStartedLine=`echo $line | egrep "STARTED" | wc -l`
        local thisIsAlreadyRunningLine=`echo $line | egrep "already running" | wc -l`
        local thisIsFailedLine=`echo $line | egrep "FAILED TO WRITE PID" | wc -l`
        local thisIsNonExistingConfigFileLine=`echo $line | egrep "Config file does not exist" | wc -l`

        if [ $thisIsConfigLine -eq 1 ]
        then
            local configFileName=`echo $line | rev | cut -d'/' -f1 | rev`
        elif [ $thisIsStartedLine -eq 1 ]
        then
            echo -e "    -> $configFileName:${GREEN}started_now${NC}"
        elif [ $thisIsAlreadyRunningLine -eq 1 ]
        then
            echo -e "    -> $configFileName:${GREEN}already_started${NC}"
        elif [ $thisIsNonExistingConfigFileLine -eq 1 ]
        then
            echo -e "    -> $configFileName:${RED}config_file_does_not_exist${NC}"
        elif [ $thisIsFailedLine -eq 1 ]
        then
            echo -e "    -> $configFileName:${RED}failed_to_start${NC}:(Refer to ${BLUE}$ACTION_LOG_FILE${NC} for details)"
        fi
        
    done < $ACTION_LOG_FILE
}

startZookeeperServer()
{
    echo -e "-> Starting zookeeper server(s)... "
    takeActionOnZookeeperServer start
    parseOutZookeerStartingLogFromActionLogFile
}

parseOutZookeerStoppingLogFromActionLogFile()
{
    while read line; do
        local thisIsConfigLine=`echo $line | egrep "Using config" | wc -l`
        local thisIsStoppedLine=`echo $line | egrep "STOPPED" | wc -l`
        local thisIsNothingToStopLine=`echo $line | egrep "no zookeeper to stop" | wc -l`
        local thisIsNonExistingConfigFileLine=`echo $line | egrep "Config file does not exist" | wc -l`

        if [ $thisIsConfigLine -eq 1 ]
        then
            local configFileName=`echo $line | rev | cut -d'/' -f1 | rev`
        elif [ $thisIsStoppedLine -eq 1 ]
        then
            echo -e "    -> $configFileName:${GREEN}stopped_now${NC}"
        elif [ $thisIsNothingToStopLine -eq 1 ]
        then
            echo -e "    -> $configFileName:${GREEN}already_stopped${NC}"
        elif [ $thisIsNonExistingConfigFileLine -eq 1 ]
        then
            echo -e "    -> $configFileName:${RED}config_file_does_not_exist${NC}"
        fi
        
    done < $ACTION_LOG_FILE
}

stopZookeeperServer()
{
    echo -e "-> Stopping zookeeper server(s)... "
    takeActionOnZookeeperServer stop
    parseOutZookeerStoppingLogFromActionLogFile
}

parseOutZookeeperStatusFromActionLogFile()
{
    while read line; do
        local thisIsConfigLine=`echo $line | egrep "Using config" | wc -l`
        local thisIsClientAddrLine=`echo $line | egrep "Client address" | wc -l`
        local thisIsClientPortNotFoundLine=`echo $line | egrep "Client port not found. Terminating." | wc -l`
        local thisIsNotRunningLine=`echo $line | egrep "not running" | wc -l`
        local thisIsModeLeaderLine=`echo $line | egrep "Mode: leader" | wc -l`
        local thisIsModeFollowerLine=`echo $line | egrep "Mode: follower" | wc -l`
        local thisIsModeStandaloneLine=`echo $line | egrep "Mode: standalone" | wc -l`
        local thisIsNonExistingConfigFileLine=`echo $line | egrep "Config file does not exist" | wc -l`

        if [ $thisIsConfigLine -eq 1 ]
        then
            local configFileName=`echo $line | rev | cut -d'/' -f1 | rev`
        elif [ $thisIsClientAddrLine -eq 1 ]
        then
            local clientAddress=`echo $line | rev | cut -d' ' -f1 | rev | cut -d'.' -f1`
            local clientPort=`echo $line | cut -d'.' -f1 | rev | cut -d' ' -f1 | rev`
        elif [ $thisIsNotRunningLine -eq 1 ]
        then
            echo -e "    -> $configFileName:$clientAddress:$clientPort:${RED}stopped${NC}"
        elif [ $thisIsModeLeaderLine -eq 1 ]
        then
            echo -e "    -> $configFileName:$clientAddress:$clientPort:${GREEN}leader${NC}"
        elif [ $thisIsModeFollowerLine -eq 1 ]
        then
            echo -e "    -> $configFileName:$clientAddress:$clientPort:${GREEN}follower${NC}"
        elif [ $thisIsModeStandaloneLine -eq 1 ]
        then
            echo -e "    -> $configFileName:$clientAddress:$clientPort:${GREEN}standalone${NC}"
        elif [ $thisIsClientPortNotFoundLine -eq 1 ]
        then
            echo -e "    -> $configFileName:${RED}dynamically_removed${NC}"
        elif [ $thisIsNonExistingConfigFileLine -eq 1 ]
        then
            echo -e "    -> $configFileName:${RED}config_file_does_not_exist${NC}"
        fi
        
    done < $ACTION_LOG_FILE
}

statusZookeeperServer()
{
    echo -e "-> Checking status of zookeeper server(s)... "
    takeActionOnZookeeperServer status
    parseOutZookeeperStatusFromActionLogFile
}
############################################################################


############### Download, verify & install Solr ############################
downloadAndValidateSolr()
{
    #-------- Prepare Solr installation directory
    mkdir -p $INSTALL_HOME
    
    rm -rf $SL_INSTALL_PATH
    mkdir -p $SL_INSTALL_PATH
    
    cd $SL_INSTALL_PATH
    
    #-------- Download release tar from origin
    echo -e -n "-> Downloading solr release tar ... : "
    wget $SL_TAR_DOWNLOAD_LINK >& /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        echo -e "${RED}ABORTING: Please install manually.${NC}"
        exit 1;
    fi
    
    #-------- Download SHA from download origin
    echo -e -n "-> Downloading solr SHA ... : "
    wget $SL_SHA_DOWNLOAD_LINK >& /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        echo -e "${RED}ABORTING: Please install manually.${NC}"
        exit 1;
    fi
    
    #-------- Prepare SHA from download origin
    rm -rf sha.origin
    cut -d' ' -f1 $SL_BIN_NAME_SHA >& sha.origin
    
    #-------- Compute SHA of downloaded tar
    rm -rf sha.local
    if [ $OS == "MAC" ]
    then
        shasum -a 512 $SL_BIN_NAME_TAR | cut -d' ' -f1 >& sha.local
    else
        sha512sum $SL_BIN_NAME_TAR | cut -d' ' -f1 >& sha.local
    fi
    
    #-------- Compare SHAs
    diff sha.local sha.origin >& /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "-> Solr SHA verification: ${GREEN}OK${NC}"
    else
        echo -e "-> Solr SHA verification: ${RED}FAILED${NC}"
        echo -e "${RED}ABORTING: Please install manually.${NC}"
        exit 1;
    fi
    
    #-------- Download ASC key file
    echo -e -n "-> Downloading solr .asc key file ... : "
    wget $SL_ASC_DOWNLOAD_LINK >& /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        echo -e "${RED}ABORTING: Please install manually.${NC}"
        exit 1;
    fi
    
    #-------- Validation using GPG
    echo -e -n "-> Verifying solr authenticity : "
    echo -e "${RED}TBD${NC}"
    
    
    #-------- Untar
    tar -xvzf $SL_BIN_NAME_TAR >& /dev/null
    
    #-------- Cleanup
    rm -rf sha.* $SL_BIN_NAME_TAR $SL_BIN_NAME_SHA $SL_BIN_NAME_ASC >& /dev/null
    cd $INSTALL_HOME
}
############################################################################


############### Main Function ##############################################
main()
{
    configureGlobals
    parseAndValidateCommandLine $@

    if [ $ACTION == "zk_install" ]
    then
        determineOS
        setInstallerBasedOnOS
        validateInstallationOfInstallers
        checkForRequiredPackages
        installMissingPackages
        downloadAndValidateZookeeper
        prepareZookeeperConfigFile
    elif [ $ACTION == "zk_start" ]
    then
        validateZookeeperServer
        startZookeeperServer
    elif [ $ACTION == "zk_stop" ]
    then
        validateZookeeperServer
        stopZookeeperServer
    elif [ $ACTION == "zk_status" ]
    then
        validateZookeeperServer
        statusZookeeperServer
    elif [ $ACTION == "sl_install" ]
    then
        determineOS
        setInstallerBasedOnOS
        validateInstallationOfInstallers
        checkForRequiredPackages
        installMissingPackages
        downloadAndValidateSolr
        #prepareZookeeperConfigFile
    fi
}

main $@
####### END OF LAST FUNCTION #######
