#!/bin/bash

###############################################################################
# ABOUT: This script can be used for distributed setup of Ensemble ZooKeeper  #
#        in AWS EC2 from scratch, completely remotely using AWS CLI and AWS   #
#        SSM.                                                                 #
#        It sets up EC2, including its role, policy, security group, and then #
#        remotely installs and starts the Zookeeper nodes in the EC2.         # 
###############################################################################

### Input : 
#            -action          start_first_node
#            -ec2             <create|id=xxxx>
#            -key_file        /path/to/<key_name>.pem
#            -resource_prefix <string>
#            -profile         <aws profile>
#            -region          <region>

############### Developer modifiable Configurations #######################
configureGlobals()
{
    MY_ABS_PATH=`echo "$(cd "$(dirname "$0")"; pwd)/$(basename "$0")"`
    VERTICILA_HOME=`dirname $MY_ABS_PATH | xargs dirname`
    source $VERTICILA_HOME/sys/sys_utils.sh
    sys_setFramework
    VERTICILA_AWS_SECGRP_SH="$VERTICILA_HOME/aws/aws_secgrp.sh"

    source $VERTICILA_HOME/aws/aws_ec2_lib.sh
    source $VERTICILA_HOME/aws/aws_keypair_lib.sh
    source $VERTICILA_HOME/aws/aws_secgrp_lib.sh
    source $VERTICILA_HOME/aws/aws_role_lib.sh

    VERTICILA_REPO_HTTP_URL="https://github.com/sourasisdas/verticila.git"
    VERTICILA_EC2_ZK_SETUP_AWS_LOCAL_SH="/home/ec2-user/installed_softwares/verticila/zk/zk_setup_aws_local.sh"

    AWS_RESOURCE_NAME_PREFIX_DEFAULT="ZK"
    SECURITY_GROUP_DEFAULT="ZK-Security-Group"
    SECURITY_GROUP_DESC_DEFAULT="Zookeeper-Ensemble-Security-Group"
    PROFILE_NAME_DEFAULT=$AWS_PROFILE
    REGION_DEFAULT=ap-south-1

    ACTION="Invalid_Action"
    HELP_MODE=0
    SHADOW_MODE=0
    EC2_OPTION=""
    EC2_ID=""
    KEY_FILE=""

    SECURITY_GROUP=$SECURITY_GROUP_DEFAULT
    AWS_RESOURCE_NAME_PREFIX=$AWS_RESOURCE_NAME_PREFIX_DEFAULT
    PROFILE_NAME=$PROFILE_NAME_DEFAULT
    REGION=$REGION_DEFAULT
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
    echo -e "${GREEN}[ -s | -shadow ]"${NC}
    echo -e "       Runs this script in shadow mode - upto parsing and input validation     ."
    echo -e
    echo -e "${GREEN}[ -action <start_first_node> ]${NC}"
    echo -e "       Performs the action."
    echo -e "       start_first_node : Sets up AWS resources and remotely invokes script that sets up and starts"
    echo -e "                     the first Zookeeper node in a multiserver settings."
    echo -e "       Switch Type : ${YELLOW}Mandatory${NC}"
    echo -e 
    echo -e "${GREEN}[ -ec2 <create|id=xxxxxxxx> ]${NC}"
    echo -e "       create      : Does Zookeeper setup on a newly created EC2 instance."
    echo -e "       id=xxxxxxxx : Does Zookeeper setup on existing EC2 instance with given ID."
    echo -e "       Switch Type : ${YELLOW}Mandatory${NC} if action is start_first_node."
    echo -e
    echo -e "${GREEN}[ -key_file /path/to/file/<key_name>.pem ]${NC}"
    echo -e "       The <key_name> part is used to create new EC2 instances."
    echo -e "       If the given private key file exists, creates a key-pair named <key_name> in EC2 if"
    echo -e "       it does not exist already."
    echo -e "       Else creates the key-pair named <key_name> in AWS and stores the private key in the"
    echo -e "       given file."
    echo -e "       Switch Type : ${YELLOW}Mandatory${NC} if -ec2 is given."
    echo -e
    echo -e "Use Cases:"
    echo -e "${BLUE}[ start_first_node ]${NC}"
    echo -e "$SCRIPT_BASE_NAME -action start_first_node -ec2 create"
    echo -e "$SCRIPT_BASE_NAME -action start_first_node -ec2 id=xxxxxxxx"
    echo -e "---------------------------------------------------------------"
}



parseAndValidateCommandLine()
{
    hasUserProvided_action=0
    hasUserProvided_ec2=0
    hasUserProvided_key_file=0

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -action)
                ACTION="$2"
                hasUserProvided_action=1
                shift
                ;;
            -ec2)
                EC2_OPTION="$2"
                hasUserProvided_ec2=1
                shift
                ;;
            -key_file)
                KEY_FILE="$2"
                hasUserProvided_key_file=1
                shift
                ;;
            -s|-shadow)
                SHADOW_MODE=1
                ;;
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
        echo -e "${RED}ABORTING: Missing mandatory switch ${NC}-action${RED}. Script will exit.${NC}"
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

    #-------- Validate -ec2
    if [[ $hasUserProvided_action == 1 && $hasUserProvided_ec2 == 0 ]]
    then
        echo -e "${RED}ABORTING: Missing mandatory switch ${NC}-ec2${RED}. Script will exit.${NC}"
        local shouldAbort=1
    else
        if [ $EC2_OPTION == "create" ]
        then
            :
        elif [[ $EC2_OPTION == id=* ]]
        then
            EC2_ID=`echo $EC2_OPTION | cut -d= -f2`
            EC2_OPTION="id"
        else
            echo -e "${RED}ABORTING: Unknown value ${NC}$EC2_OPTION${RED} passed to switch ${NC}-ec2${RED}. Script will exit.${NC}"
            local shouldAbort=1
        fi
    fi

    #-------- Validate -key_file
    if [[ $hasUserProvided_ec2 == 1 && $hasUserProvided_key_file == 0 ]]
    then
        echo -e "${RED}ABORTING: Missing mandatory switch ${NC}-key_file${RED}. Script will exit.${NC}"
        local shouldAbort=1
    fi

    #-------- Validate -h|-help (Print usage)
    if [ $HELP_MODE -eq 1 ];
    then
        printHelpMessage
        local shouldAbort=1
    fi

    #-------- Validate -s|-shadow (Runs in shadow mode - upto parsing and input validation)
    if [ $SHADOW_MODE -eq 1 ];
    then
        local shouldAbort=1
    fi

    #-------- Abort in case of any issue
    if [ $shouldAbort -eq 1 ];
    then
        exit 1;
    fi
}


# Call only if "-ec2 create" is passed
createEc2()
{
    # TBD
    #### this -> aws_ec2.sh
    #- Create instance t3.medium (-ec2 create|ID -> either creates new ec2, or uses given ID)
    #   - Use given key_pair
    #   - (?) Attach EBS ${AWS_RESOURCE_NAME_PREFIX}-ZK-EBS-1 (if -ec2 ID given, and it does not have attached EBS already)
    #   - Attach ${AWS_RESOURCE_NAME_PREFIX}-ZK-Security-Group (if -ec2 ID given, and it does not have attached SECGRP already)
    #   - Attach role ${AWS_RESOURCE_NAME_PREFIX}-Role-SSM-For-EC2 (if -ec2 ID given, and it does not have same role already)
    #   - Set user data (if anything needed)
    #   - Return its ID, public IP & private IP
    return
}


addPermissionsToSecurityGroup()
{
    # TBD
    #### this -> aws_secgrp.sh
    #- Add security group permissions to ${AWS_RESOURCE_NAME_PREFIX}-ZK-Security-Group (if not already permitted)
    #   - TCP 22, myip/32
    #   - TCP 8080, privateIP/32 of EC2 instance just started
    return
}

startFirstZookeeperNodeOnEc2()
{
    local execution_timeout=180
    local timeout_seconds=120
    local ec2_instance_id=$1
    local output_s3_bucket_name=nairp-s3-bucket-auto-hosting
    local region=ap-south-1

    local remote_command_to_run="\
    mkdir -p /home/ec2-user/installed_softwares/ ; \
    cd /home/ec2-user/installed_softwares/ ; \
    sudo yum -y install git ; \
    git clone https://github.com/sourasisdas/verticila.git ; \
    $VERTICILA_EC2_ZK_SETUP_AWS_LOCAL_SH -action start_first_node\
    "

    local ssm_command="aws ssm send-command --document-name "\""AWS-RunShellScript"\"" --document-version "\""1"\"" --targets '[{"\""Key"\"":"\""InstanceIds"\"","\""Values"\"":["\""$ec2_instance_id"\""]}]' --parameters '{"\""commands"\"":["\""$remote_command_to_run"\""],"\""workingDirectory"\"":["\"""\""],"\""executionTimeout"\"":["\""$execution_timeout"\""]}' --timeout-seconds $timeout_seconds --max-concurrency "\""50"\"" --max-errors "\""0"\"" --output-s3-bucket-name "\""$output_s3_bucket_name"\"" --region $region"
    echo $ssm_command

#    aws ssm send-command --document-name "AWS-RunShellScript" --document-version "1" --targets '[{"Key":"InstanceIds","Values":["i-05ed6cada2f61563c"]}]' --parameters '{"commands":["/home/ec2-user/x.sh sou_ssm_dir \"1.2.3.4|5.6.7.8=9\""],"workingDirectory":[""],"executionTimeout":["3600"]}' --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --output-s3-bucket-name "nairp-s3-bucket-auto-hosting" --region ap-south-1
}


main()
{
    local status=0
    configureGlobals
    parseAndValidateCommandLine $@

    if [ $ACTION == "start_first_node" ]
    then

        ### Install AWS CLI if does not exist
        sys_installAwsCliIfNotPresent


        ### Create AWS key_pair if does not exist
        # TBD: Take user input into $KEY_NAME and $PEM_OUT_DIR
        echo -e -n "-> Script checking existence of aws ssh key pair '$KEY_NAME' ... : "
        checkExistence_ofKeyPair_wKeyName $SHADOW_MODE $KEY_NAME
        if [ $? -ne 0 ]
        then
            echo -e -n "-> Script creating aws ssh key pair '$KEY_NAME' ... : "
            create_aKeyPair_wKeyName_wPemOutputDir $SHADOW_MODE $KEY_NAME $PEM_OUT_DIR
            if [ $? -ne 0 ]
                echo -e "${RED}ABORTING: Failed creating new key pair ${NC}$KEY_NAME${RED} and/or to store its '.pem' file at $PEM_OUT_DIR. Script will exit.${NC}"
                exit 1
            fi
        fi


        ### Create security group if does not exist
        echo -e -n "-> Script checking existence of aws security group '$SECURITY_GROUP' ... : "
        checkExistence_ofSecGrp_wSecGrpName_wAwsProfileName_wRegion $SHADOW_MODE $SECURITY_GROUP $PROFILE_NAME $REGION
        if [ $? -ne 0 ]
        then
            echo -e -n "-> Script creating aws security group '$SECURITY_GROUP' ... : "
            create_aSecGrp_wSecGrpName_wDescription_wAwsProfileName_wRegion $SHADOW_MODE $SECURITY_GROUP $SECURITY_GROUP_DESC_DEFAULT $PROFILE_NAME $REGION
            if [ $? -ne 0 ]
            then
                echo -e "${RED}ABORTING: Failed creating new security group ${NC}$SECURITY_GROUP${RED}. Script will exit.${NC}"
                exit 1
            fi
        fi


        ### Create EBS volume ${AWS_RESOURCE_NAME_PREFIX}-ZK-EBS-1 for EC2 ? (if does not exist)
        # TBD Low priority


        ### Create iam role if does not exist
        # TBD: Pass absolute path of aws_policy_document__allow_ec2_to_assume_role.json into $ASSUME_ROLE_POLICY_JSON_ABS_PATH
        # TBD: Set arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore to variable $POLICY_ARN_SSM_FOR_EC2
        echo -e -n "-> Script checking existence of aws iam role '$ROLE_NAME' ... : "
        checkExistence_ofRole_wRoleName $SHADOW_MODE $ROLE_NAME
        if [ $? -ne 0 ]
        then
            echo -e -n "-> Script creating aws iam role '$ROLE_NAME' ... : "
            create_aRole_wRoleName_wAssumeRolePolicyJsonAbsPath $SHADOW_MODE $ROLE_NAME $ASSUME_ROLE_POLICY_JSON_ABS_PATH
            if [ $? -ne 0 ]
            then
                echo -e "${RED}ABORTING: Failed creating new iam role ${NC}$ROLE_NAME${RED}. Script will exit.${NC}"
                exit 1
            else
                echo -e -n "-> Script attaching policy $POLICY_ARN_SSM_FOR_EC2 to iam role '$ROLE_NAME' ... : "
                attach_toRole_wRoleName_wPolicyArn $SHADOW_MODE $ROLE_NAME $POLICY_ARN_SSM_FOR_EC2
                if [ $? -ne 0 ]
                then
                    echo -e "${RED}ABORTING: Failed attaching policy ${NC}$POLICY_ARN_SSM_FOR_EC2${RED} to iam role ${NC}$ROLE_NAME${RED}. Script will exit.${NC}"
                    exit 1
            fi
        fi

        ### TBD Henceforth

        # if "-ec2 create" is passed. Returns [ID, Public IP, Private IP]
            createEc2
        # else # -ec2 ID must have been passed
            #checkStatusOfEc2Intance $EC2_ID
            #attachRoleForSsmToEc2IfNotAttached
            #attachSecurityGroupToEc2IfNotAttached
        addPermissionsToSecurityGroup

        startFirstZookeeperNodeOnEc2 "12345678890"
        #busyWaitForCompletion (aws ssm list-command-invocations --command-id 302c76a3-2212-4b50-957e-b10a17974e76)
        # If successful
        #    echo "0 $Ec2ID $Ec2PublicIP $Ec2PrivateIP"
        #    exit 0
        # Else
        #    Terminate EC2 if created, or, stop EC2 if started.
        #    echo "1"
        #    exit 1
    fi
}



main $@
####### END OF LAST FUNCTION #######
