#!/bin/bash

################ Set global variables common to all Verticila scripts #################
sys_setFramework()
{
    #-------- This script's output settings
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[0;33m'
    NC='\033[0m'

    #-------- Global installation settings
    INSTALL_HOME=$HOME/installed_softwares
}


################ Get OS. Supported: RHEL, UBUNTU, MAC #################################
sys_getOS()
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


################ Set installer dependeing on OS #######################################
sys_setInstallerBasedOnOS()
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


################ Check if installers are installed ####################################
sys_validateInstallationOfInstallers()
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


################ Number utilities #####################################################
sys_checkIfNonNegativeInteger()
{
    #local regexForInt='^[0-9]+$'
    local regexForInt='^[1-9]+[0-9]*$|^0$'
    if ! [[ $1 =~ $regexForInt ]] ; then
       echo 0
    else
       echo 1
    fi
}

sys_checkIfNumberBetween0And255()
{
    local isValid=0
    local isNumber="$(sys_checkIfNonNegativeInteger $1)"
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

sys_checkIfValidIpv4()
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
            local isNumber1="$(sys_checkIfNumberBetween0And255 $f1)"
            local isNumber2="$(sys_checkIfNumberBetween0And255 $f2)"
            local isNumber3="$(sys_checkIfNumberBetween0And255 $f3)"
            local isNumber4="$(sys_checkIfNumberBetween0And255 $f4)"
            if [[ $isNumber1 -eq 1 && ( $isNumber2 -eq 1 && ( $isNumber3 -eq 1 && $isNumber4 -eq 1 ) ) ]]
            then
                isValid=1
            fi
        fi
    fi
    echo "$isValid"
}


################ Install AWS CLI if not present ######################################
sys_installAwsCliIfNotPresent()
{
    aws --version | grep aws-cli >& /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "-> Checking installation of aws CLI: ${GREEN}OK${NC}"
        return
    else
        echo -e "-> Checking installation of aws CLI: ${YELLOW}NOT INSTALLED${NC}"
    fi

    echo -e -n "-> Downloading and installing AWS CLI V2 ... : "
    case $OS in
        MAC)
            curl -s "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
            if [ $? -ne 0 ]
            then
                echo -e "${RED}FAILED${NC}"
                echo -e "${RED}ABORTING: Failed downloading of AWS CLI. Script will exit.${NC}"
                exit 1
            fi
            sudo installer -pkg AWSCLIV2.pkg -target / >& /dev/null
            if [ $? -ne 0 ]
            then
                echo -e "${RED}FAILED${NC}"
                echo -e "${RED}ABORTING: Failed installation of AWS CLI. Script will exit.${NC}"
                exit 1
            else
                rm -rf AWSCLIV2.pkg >& /dev/null
                echo -e "${GREEN}OK${NC}"
            fi
            ;;
        UBUNTU)
            echo -e "${RED}TBD${NC}"
            ;;
        RHEL)
            echo -e "${RED}TBD${NC}"
            ;;
        *)
            echo -e "${RED}FAILED${NC}"
            echo -e "${RED}ABORTING: Unsupported OS '$OS' detected. Script will exit.${NC}"
            exit 1
            ;;
    esac
}
