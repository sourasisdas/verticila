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
#            -resource_prefix <string>
#            -profile         <aws profile>
#            -region          <region>

############### Developer modifiable Configurations #######################
configureGlobals()
{
    ### setup verticila script system
    MY_ABS_PATH=`echo "$(cd "$(dirname "$0")"; pwd)/$(basename "$0")"`
    VERTICILA_HOME=`dirname $MY_ABS_PATH | xargs dirname`
    source $VERTICILA_HOME/sys/sys_utils.sh
    sys_setFramework
    VERTICILA_AWS_SECGRP_SH="$VERTICILA_HOME/aws/aws_secgrp.sh"

    ### source verticila aws libs
    source $VERTICILA_HOME/aws/aws_ec2_lib.sh
    source $VERTICILA_HOME/aws/aws_keypair_lib.sh
    source $VERTICILA_HOME/aws/aws_secgrp_lib.sh
    source $VERTICILA_HOME/aws/aws_role_lib.sh


    ### setup global variables that can be overwritten through command-line options as well
    #TBD HIGH: Support following options in command-line
    ACTION="Invalid_Action"
    EC2_OPTION=""
    EC2_ID="" # No support needed in command-line - will be populated from EC2_OPTION
    #TBD HIGH: Use AWS_RESOURCE_NAME_PREFIX before all resource name being created/checked for existence
    AWS_RESOURCE_NAME_PREFIX="NAIRP-trial-"
    PROFILE_NAME=$AWS_PROFILE
    HELP_MODE=0
    SHADOW_MODE=0
    #TBD LOW: Support following options in command-line
    REGION=ap-south-1
    PEM_OUT_DIR="~/.ssh"

    ### setup global constants etc. that should not be changed
    MY_PUBLIC_IP="$(curl -s icanhazip.com 2> /dev/null)"
    ROLE_NAME="zk-ssm-role-for-ec2"
    INSTANCE_PROFILE_NAME="zk-ssm-instprofile-for-ec2"
    POLICY_ARN_SSM_FOR_EC2="arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    KEY_NAME="zk-ssh-key"
    SECGRP_NAME="zk-sec-grp"
    SECGRP_DESC="zk-ensemble-security-group"
    ASSUME_ROLE_POLICY_JSON_ABS_PATH="$VERTICILA_HOME/aws/aws_policy_jsons/aws_policy_document__allow_ec2_to_assume_role.json"
    AMI_ID="ami-0ebc1ac48dfd14136" # Amazon Linux 2 AMI (HVM), SSD Volume Type, 64 bit x64
    INSTANCE_TYPE="t3.medium"
    EC2_LOCAL_INSTALLATION_DIR="/home/ec2-user/installed_softwares/"
    VERTICILA_REPO_HTTP_URL="https://github.com/sourasisdas/verticila.git"
    VERTICILA_EC2_ZK_SETUP_AWS_LOCAL_SH="$EC2_LOCAL_INSTALLATION_DIR/verticila/zk/zk_setup_aws_local.sh"    # TBD LOW: The user name "ec2-user" may vary
    SSM_COMMAND_OUTPUT_S3_BUCKET_NAME=nairp-s3-bucket-auto-hosting


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


startFirstZookeeperNodeOnEc2()
{
    local shadowMode=$1
    local ec2InstanceId=$2

    local startTimeout=120
    local executionTimeout=180
    local outputS3BucketName=$SSM_COMMAND_OUTPUT_S3_BUCKET_NAME
    local region=$REGION

    ### Prepare and invoke SSM command
    local remoteCommandToRun="mkdir -p $EC2_LOCAL_INSTALLATION_DIR ; \
                              cd $EC2_LOCAL_INSTALLATION_DIR ; \
                              sudo yum -y install git ; \
                              rm -rf $VERTICILA_REPO_HTTP_URL ; \
                              git clone $VERTICILA_REPO_HTTP_URL ; \
                              chown -R ec2-user:ec2-user verticila ; \
                              $VERTICILA_EC2_ZK_SETUP_AWS_LOCAL_SH -action start_first_node ; \
                             "
    local ssmCommandStatus=$(invokeAndGetStatus_ofSsmCmd_wRemoteCmdString_wEc2InstId_wStartTimeout_wExecTimeout_wOutS3BktName_wRegion "\${shadowMode}" "\${remoteCommandToRun}" "\${ec2InstanceId}" "\${startTimeout}" "\${executionTimeout}" "\${outputS3BucketName}" "\${region}")
    local status=$?

    if [ $status -ne 0 ]
    then
        echo "ssm_command_invocation_failed"
        return $status
    fi


    ### Let SSM command execution finish, and get back status of it
    local totalTimeout=$(( $startTimeout + $executionTimeout ))
    local ssmCommandStatus=$(waitAndGetStatus_ofSsmCmd_wSsmCmdId_wEc2InstId_wTimeToWait "\${shadowMode}" "\${ssmCommandId}" "\${ec2InstanceId}" "\${totalTimeout}")
    status=$?

    echo $ssmCommandStatus
    return $status
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
        echo -e -n "-> Script checking existence of aws ssh key pair '$KEY_NAME' ... : "
        checkExistence_ofKeyPair_wKeyName $SHADOW_MODE $KEY_NAME
        if [ $? -ne 0 ]
        then
            # Check existence and create $PEM_OUT_DIR, if does not exist
            if [ ! -d $PEM_OUT_DIR ]
            then
                mkdir $PEM_OUT_DIR
                if [ $? -ne 0 ]
                then
                    echo -e "${RED}ABORTING: Failed creating directory ${NC}$PEM_OUT_DIR${RED} to store '.pem' file. Script will exit.${NC}"
                    exit 1
                fi
            fi
            echo -e -n "-> Script creating aws ssh key pair '$KEY_NAME' ... : "
            create_aKeyPair_wKeyName_wPemOutputDir $SHADOW_MODE $KEY_NAME $PEM_OUT_DIR
            if [ $? -ne 0 ]
                echo -e "${RED}ABORTING: Failed creating new key pair ${NC}$KEY_NAME${RED} and/or to store its '.pem' file at $PEM_OUT_DIR. Script will exit.${NC}"
                exit 1
            fi
        fi


        ### Create security group if does not exist
        echo -e -n "-> Script checking existence of aws security group '$SECGRP_NAME' ... : "
        checkExistence_ofSecGrp_wSecGrpName_wAwsProfileName_wRegion $SHADOW_MODE $SECGRP_NAME $PROFILE_NAME $REGION
        if [ $? -ne 0 ]
        then
            echo -e -n "-> Script creating aws security group '$SECGRP_NAME' ... : "
            create_aSecGrp_wSecGrpName_wDescription_wAwsProfileName_wRegion $SHADOW_MODE $SECGRP_NAME $SECGRP_DESC $PROFILE_NAME $REGION
            if [ $? -ne 0 ]
            then
                echo -e "${RED}ABORTING: Failed creating new security group ${NC}$SECGRP_NAME${RED}. Script will exit.${NC}"
                exit 1
            fi
        fi


        ### Create EBS volume ${AWS_RESOURCE_NAME_PREFIX}-ZK-EBS-1 for EC2 ? (if does not exist)
        # TBD LOW
        ### Attach EBS volume ${AWS_RESOURCE_NAME_PREFIX}-ZK-EBS-1 (if -ec2 ID given, and it does not have attached EBS already)
        # TBD LOW


        ### Create iam role if does not exist, and attach policy
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
            fi

            echo -e -n "-> Script attaching policy $POLICY_ARN_SSM_FOR_EC2 to iam role '$ROLE_NAME' ... : "
            attachPolicy_toRole_wRoleName_wPolicyArn $SHADOW_MODE $ROLE_NAME $POLICY_ARN_SSM_FOR_EC2
            if [ $? -ne 0 ]
            then
               echo -e "${RED}ABORTING: Failed attaching policy ${NC}$POLICY_ARN_SSM_FOR_EC2${RED} to iam role ${NC}$ROLE_NAME${RED}. Script will exit.${NC}"
               exit 1
            fi
        fi


        ### Create instance profile if does not exist, and add role
        echo -e -n "-> Script checking existence of instance profile '$INSTANCE_PROFILE_NAME' ... : "
        checkExistence_ofInstProfile_wInstProfileName $SHADOW_MODE $INSTANCE_PROFILE_NAME
        if [ $? -ne 0 ]
        then
            echo -e -n "-> Script creating aws instance profile '$INSTANCE_PROFILE_NAME' ... : "
            create_anInstProfile_wInstProfileName $SHADOW_MODE $INSTANCE_PROFILE_NAME
            if [ $? -ne 0 ]
            then
                echo -e "${RED}ABORTING: Failed creating new instance profile ${NC}$INSTANCE_PROFILE_NAME${RED}. Script will exit.${NC}"
                exit 1
            fi

            echo -e -n "-> Script adding role $ROLE_NAME to instance profile '$INSTANCE_PROFILE_NAME' ... : "
            addRole_toInstProfile_wInstProfileName_wRoleName $SHADOW_MODE $INSTANCE_PROFILE_NAME $ROLE_NAME
            if [ $? -ne 0 ]
            then
               echo -e "${RED}ABORTING: Failed adding rolw ${NC}$ROLE_NAME${RED} to instance profile ${NC}$INSTANCE_PROFILE${RED}. Script will exit.${NC}"
               exit 1
            fi
        fi


        ### Create EC2, if "-ec2 create" is passed, else check existence of given EC2 id 
        if [ $EC2_OPTION == "create" ]
        then
            echo -e -n "-> Script creating EC2 instance ... : "
            EC2_ID=$(createAndGetId_ofEc2_wAmiId_wInstType_wKeyName_wSecGrpName $SHADOW_MODE $AMI_ID $INSTANCE_TYPE $KEY_NAME $SECGRP_NAME)
            if [ $? -ne 0 ]
            then
                echo -e "${RED}ABORTING: Failed creating new EC2 instance. Script will exit.${NC}"
                exit 1
            fi
        else # "-ec2 id=*" must have been passed
            echo -e -n "-> Script checking existence of EC2 instance with instance ID $EC2_ID ... : "
            checkExistence_ofEc2_wInstId $SHADOW_MODE $EC2_ID
            if [ $? -ne 0 ]
            then
                echo -e "${RED}ABORTING: EC2 instance with instance ID ${NC}$EC2_ID${RED} not found. Script will exit.${NC}"
                exit 1
            fi
        fi


        ### Set user data to EC2, if required
        # TBD LOW


        ### Get Arn of instance profile
        echo -e -n "-> Script getting ARN of instance profile $INSTANCE_PROFILE_NAME ... : "
        INSTANCE_PROFILE_ARN=$(getArn_ofInstProfile_wInstProfileName "\${SHADOW_MODE}" "\${INSTANCE_PROFILE_NAME}")
        if [ $? -ne 0 ]
        then
            echo -e "${RED}ABORTING: Failed getting ARN of instance profile ${NC}$INSTANCE_PROFILE_NAME${RED}. Script will exit.${NC}"
            exit 1
        fi


        ### Attach instance profile to EC2, if not already attached
        echo -e -n "-> Script getting ARN of EC2 instance with instance ID $EC2_ID ... : "
        EC2_INSTANCE_PROFILE_ARN=$(getInstProfileArn_ofEc2_wInstId "\${SHADOW_MODE}" "\${EC2_ID}")
        if [ $? -ne 0 ]
        then
            echo -e "${RED}ABORTING: Failed getting ARN of instance profile ${NC}$INSTANCE_PROFILE_NAME${RED}. Script will exit.${NC}"
            exit 1
        else
            if [ $EC2_INSTANCE_PROFILE_ARN == "failed" ] # No profile attached, so just attach $INSTANCE_PROFILE_ARN
            then
                echo -e -n "-> Script associating instance profile $INSTANCE_PROFILE_NAME to EC2 instance with instance ID $EC2_ID ... : "
                associateInstProfile_toEc2_wInstId_wInstProfileName $SHADOW_MODE $EC2_ID $INSTANCE_PROFILE_NAME
                if [ $? -ne 0 ]
                then
                    echo -e "${RED}ABORTING: Failed associating instance profile ${NC}$INSTANCE_PROFILE_NAME${RED} to EC2 instance with instance ID ${NC}$EC2_ID${RED}. Script will exit.${NC}"
                    exit 1
                fi
            elif [ $EC2_INSTANCE_PROFILE_ARN != $INSTANCE_PROFILE_ARN ] # Some other profile attached, hence abort to not mess with the existing roles of the EC2
                echo -e "${RED}ABORTING: EC2 instance ${NC}$EC2_ID${RED} is already associated with an instance profile ${NC}$EC2_INSTANCE_PROFILE_ARN${RED}. To avoid messing with the roles currently assumed by the EC2, the script did not change the ec2's association to the new instance profile ${NC}$INSTANCE_PROFILE_ARN${RED}, as required. Script will exit. To use the EC2 instance, please replace its instance profile manually from AWS console.${NC}"
                exit 1
            else # Required role already associated, so nothing to do
                :
            fi
        fi


        ### Grant the security group inbound permission for SSH (tcp/22) to my IP
        echo -e -n "-> Script granting inbound SSH permission of my public IP $MY_PUBLIC_IP to security group $SECGRP_NAME ... : "
        grantPermission_ofSecGrp_wSecGrpName_wAwsProfileName_wRegion_wProtocol_wPort_wCidr $SHADOW_MODE $SECGRP_NAME $PROFILE_NAME $REGION tcp 22 "$MY_PUBLIC_IP/32"
        if [ $? -ne 0 ]
        then
            echo -e "${RED}ABORTING: Failed granting inbound SSH permission of my public IP ${NC}$MY_PUBLIC_IP${RED} to security group ${NC}$SECGRP_NAME${RED}. Script will exit.${NC}"
            exit 1
        fi

        ### Get private IP address of EC2 instance $EC2_ID
        echo -e -n "-> Script getting private IPv4 address of EC2 instance with instance ID $EC2_ID ... : "
        EC2_PRIVATE_IP=$(getPublicIpv4_ofEc2_wInstId "\${SHADOW_MODE}" "\${EC2_ID}" )
        if [ $? -ne 0 ]
        then
            echo -e "${RED}ABORTING: Failed getting private IPv4 address of EC2 instance with instance ID ${NC}$EC2_ID${RED}. Script will exit.${NC}"
            exit 1
        fi

        ### Grant the security group inbound permission for HTTP (tcp/8080) to the private IP of instance $EC2_ID. This is needed for a single security group to be shared within a Zookeeper cluster of many EC2 instances
        echo -e -n "-> Script granting inbound HTTP permission of EC2 instance's private IP $EC2_PRIVATE_IP to security group $SECGRP_NAME ... : "
        grantPermission_ofSecGrp_wSecGrpName_wAwsProfileName_wRegion_wProtocol_wPort_wCidr $SHADOW_MODE $SECGRP_NAME $PROFILE_NAME $REGION tcp 8080 "$EC2_PRIVATE_IP/32"
        if [ $? -ne 0 ]
        then
            echo -e "${RED}ABORTING: Failed granting inbound HTTP permission of EC2 instance's private IP ${NC}$EC2_PRIVATE_IP${RED} to security group ${NC}$SECGRP_NAME${RED}. Script will exit.${NC}"
            exit 1
        fi


        echo -e -n "-> Script starting first Zookeeper node on EC2 with instance ID $EC2_ID ... : "
        local ssmCommandId=$(startFirstZookeeperNodeOnEc2 "\${SHADOW_MODE}" "\${EC2_ID}" )
        if [ $? -ne 0 ]
        then
            echo -e "${RED}ABORTING: Failed starting first Zookeeper node on EC2 instance ID ${NC}$EC2_ID${RED} due to failed/incomplete SSM command. To debug, look into SSM command history from AWS console. Script will exit.${NC}"
            echo "1"
            exit 1
        else
            # TBD HIGH: Terminate EC2 if created, or, stop EC2 if started.
            echo "$EC2_ID"
            exit 0
        fi
    fi
}



main $@
####### END OF LAST FUNCTION #######
