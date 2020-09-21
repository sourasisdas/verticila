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
    source $VERTICILA_HOME/aws/aws_instprofile_lib.sh
    source $VERTICILA_HOME/aws/aws_ssm_lib.sh


    ### setup global variables that can be overwritten through command-line options as well
    ACTION="Invalid_Action"
    EC2_OPTION=""
    EC2_ID="" # No support needed in command-line - will be populated from EC2_OPTION
    AWS_RESOURCE_PREFIX=""
    PROFILE_NAME=$AWS_PROFILE
    HELP_MODE=0
    SHADOW_MODE=0
    SCRIPT_MODE=1  # FATAL: Do not change this value. Script will fail to work if changed.
    REGION=ap-south-1
    #TBD LOW: Support following options in command-line
    PEM_OUT_DIR="$HOME/.ssh"

    ### setup global constants etc. that should not be changed
    MY_PUBLIC_IP="$(curl -s icanhazip.com 2> /dev/null)"
    WAIT_SECONDS_BEFORE_NEW_EC2_INSTANCE_RUNS=30
    EC2_NAME_TAG="zk-ec2" # Its value will be populated based on "action"
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
    EC2_LOCAL_INSTALLATION_VERTICILA="$EC2_LOCAL_INSTALLATION_DIR/verticila"
    VERTICILA_REPO_HTTP_URL="https://github.com/sourasisdas/verticila.git"
    VERTICILA_EC2_ZK_SETUP_AWS_LOCAL_SH="$EC2_LOCAL_INSTALLATION_VERTICILA/zk/zk_setup_aws_local.sh"    # TBD LOW: The user name "ec2-user" may vary
    SSM_COMMAND_OUTPUT_S3_BUCKET_NAME=nairp-s3-bucket-auto-hosting
    EBS_VOLUME_NAME_FOR_FIRST_NODE="zk-ebs-vol-1"
}


reviseAwsResourceNameToAddPrefix()
{
    EC2_NAME_TAG=${AWS_RESOURCE_PREFIX}${EC2_NAME_TAG}
    ROLE_NAME=${AWS_RESOURCE_PREFIX}${ROLE_NAME}
    INSTANCE_PROFILE_NAME=${AWS_RESOURCE_PREFIX}${INSTANCE_PROFILE_NAME}
    KEY_NAME=${AWS_RESOURCE_PREFIX}${KEY_NAME}
    SECGRP_NAME=${AWS_RESOURCE_PREFIX}${SECGRP_NAME}
    SECGRP_DESC=${AWS_RESOURCE_PREFIX}${SECGRP_DESC}
    #TBD Low: Uncomment following when custom S3 bucket is created
    #SSM_COMMAND_OUTPUT_S3_BUCKET_NAME=${AWS_RESOURCE_PREFIX}${SSM_COMMAND_OUTPUT_S3_BUCKET_NAME}
    EBS_VOLUME_NAME_FOR_FIRST_NODE=${AWS_RESOURCE_PREFIX}${EBS_VOLUME_NAME_FOR_FIRST_NODE}
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
    echo -e "       Runs this script in shadow mode - upto parsing and input validation."
    echo -e
    echo -e "${GREEN}[ -action <start_first_node> ]${NC}"
    echo -e "       Performs the action."
    echo -e "       start_first_node : Sets up AWS resources and remotely invokes script that sets up and"
    echo -e "                          starts the first Zookeeper node in a multiserver settings."
    echo -e "       Switch Type : ${YELLOW}Mandatory${NC}"
    echo -e 
    echo -e "${GREEN}[ -ec2 <create|id=xxxxxxxx> ]${NC}"
    echo -e "       create      : Does Zookeeper setup on a newly created EC2 instance."
    echo -e "       id=xxxxxxxx : Does Zookeeper setup on existing EC2 instance with given ID."
    echo -e "       Switch Type : ${YELLOW}Mandatory${NC} if action is start_first_node."
    echo -e
    echo -e "${GREEN}[ -aws_resource_prefix <A string of alphabets, digits and hyphen, starting with alphabet> ]${NC}"
    echo -e "       Adds the given prefix to all new resources to be created in AWS, such as roles,"
    echo -e "       security groups, ebs volumes, s3 buckets etc."
    echo -e "       Switch Type : ${YELLOW}Mandatory${NC} if action is start_first_node."
    echo -e
    echo -e "${GREEN}[ -profile <CLI profile's name> ]${NC}"
    echo -e "       Uses the given profile for the action as applicable."
    echo -e "       Default     : $PROFILE_NAME [ value of \$AWS_PROFILE ]"
    echo -e "       Switch Type : ${YELLOW}Optional${NC}. If variable \$AWS_PROFILE is not defined, script will fail."
    echo -e
    echo -e "${GREEN}[ -region <User's default region> ]${NC}"
    echo -e "       Performs action, or creates resources on the given AWS region."
    echo -e "       Default     : $REGION"
    echo -e "       Switch Type : ${YELLOW}Optional${NC}."
    echo -e
    echo -e "${GREEN}[ -pem_out_dir <Path of directory where private key .pem file to be stored> ]${NC}"
    echo -e "       If new SSH key pair is to be created, then keep .pem file with private key in given"
    echo -e "       directory path."
    echo -e "       Default     : $PEM_OUT_DIR [ \$HOME/.ssh ]"
    echo -e "       Switch Type : ${YELLOW}Optional${NC}."
    echo -e
    echo -e "Use Cases:"
    echo -e "${BLUE}[ start_first_node ]${NC}"
    echo -e "$SCRIPT_BASE_NAME -action start_first_node -ec2 create     -aws_resource_prefix R [-profile P] [-region R] [-pem_out_dir D]"
    echo -e "$SCRIPT_BASE_NAME -action start_first_node -ec2 id=xxxxxxx -aws_resource_prefix R [-profile P] [-region R] [-pem_out_dir D]"
    echo -e "---------------------------------------------------------------"
}



parseAndValidateCommandLine()
{
    hasUserProvided_action=0
    hasUserProvided_ec2=0
    hasUserProvided_aws_resource_prefix=0

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
            -profile)
                PROFILE_NAME="$2"
                shift ;;
            -region)
                REGION="$2"
                shift ;;
            -aws_resource_prefix)
                AWS_RESOURCE_PREFIX="$2"
                hasUserProvided_aws_resource_prefix=1
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

    #-------- Validate -h|-help (Print usage)
    if [ $HELP_MODE -eq 1 ];
    then
        printHelpMessage
        exit 0
    fi

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
    if [[ $ACTION == "start_first_node" && $hasUserProvided_ec2 == 0 ]]
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

    #-------- Validate -aws_resource_prefix (last switch to be validated other than HELP and SHADOW)
    if [[ $ACTION == "start_first_node" && $hasUserProvided_aws_resource_prefix == 0 ]]
    then
        echo -e "${RED}ABORTING: Missing mandatory switch ${NC}-aws_resource_prefix${RED}. Script will exit.${NC}"
        local shouldAbort=1
    else
        #TBD LOW: Validate if $AWS_RESOURCE_PREFIX is a legal or illegal string to be used in AWS

        # Add prefix to all resourcs
        reviseAwsResourceNameToAddPrefix
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
    local scriptMode=$1
    local shadowMode=$2
    local ec2InstanceId=$3

    local startTimeout=120
    local executionTimeout=180
    local outputS3BucketName=$SSM_COMMAND_OUTPUT_S3_BUCKET_NAME
    local region=$REGION

    ### Prepare and invoke SSM command
    local remoteCommandToRun="mkdir -p $EC2_LOCAL_INSTALLATION_DIR ; \
                              cd $EC2_LOCAL_INSTALLATION_DIR ; \
                              sudo yum -y install git ; \
                              rm -rf $EC2_LOCAL_INSTALLATION_VERTICILA ; \
                              git clone $VERTICILA_REPO_HTTP_URL ; \
                              chown -R ec2-user:ec2-user verticila ; \
                              $VERTICILA_EC2_ZK_SETUP_AWS_LOCAL_SH -action start_first_node ; \
                             "
    local ssmCommandStatus=$(invokeAndGetStatus_ofSsmCmd_wRemoteCmdString_wEc2InstId_wStartTimeout_wExecTimeout_wOutS3BktName_wRegion "\${scriptMode}" "\${shadowMode}" "\${remoteCommandToRun}" "\${ec2InstanceId}" "\${startTimeout}" "\${executionTimeout}" "\${outputS3BucketName}" "\${region}")
    local status=$?

    if [ $status -ne 0 ]
    then
        echo "ssm_command_invocation_failed"
        return $status
    fi


    #### Let SSM command execution finish, and get back status of it
    #local totalTimeout=$(( $startTimeout + $executionTimeout ))
    #local ssmCommandStatus=$(waitAndGetStatus_ofSsmCmd_wSsmCmdId_wEc2InstId_wTimeToWait "\${scriptMode}" "\${shadowMode}" "\${ssmCommandId}" "\${ec2InstanceId}" "\${totalTimeout}")
    #status=$?

    #echo $ssmCommandStatus
    return $status
}


undoAwsAndLocalResourceChanges()
{
    # TBD HIGH: Mark during creation, and terminate all newly created AWS resources
        ### Delete AWS key_pair $KEY_NAME if created in this invocation
        ### Revoke inbound permission of $MY_PUBLIC_IP to security group $SECGRP_NAME, if was granted in this call
        ### Revoke inbound http permission of $EC2_PRIVATE_IP from security group $SECGRP_NAME, <do>
        ### Delete AWS sec grp $SECGRP_NAME, <do>
        ### Delete EBS volume $EBS_VOLUME_NAME_FOR_FIRST_NODE, <do>
        ### Detach Policy $POLICY_ARN_SSM_FOR_EC2, if was attached to $ROLE_NAME in this call
        ### Delete IAM Role Name $ROLE_NAME, if created in this invocation
        ### Remove Role $ROLE_NAME from instance profile $INSTANCE_PROFILE_NAME, if was added in this call
        ### Delete instance profile $INSTANCE_PROFILE_NAME, if was created in this call
        ### Delete $EC2_ID instance, <do>
        ### Dissociate $INSTANCE_PROFILE_NAME from instance $EC2_ID, if was associated in this call
        ### Delete S3 bucket named $SSM_COMMAND_OUTPUT_S3_BUCKET_NAME , if was created in this call

    # TBD LOW: Mark during changes, and undo changes of all modified AWS resources
        ### Stop first zookeeper node at $EC2_ID, if was started in this invocation

    # TBD LOW: Mark during changes, and undo changes of all modified local resources
        ### Delete $PEM_OUT_DIR, <do>
        ### Delete user profile, <do>
    return 0
}

safeExit()
{
    local status=$1
    if [ $status -ne 0 ]
    then
        undoAwsAndLocalResourceChanges
    fi
    exit $status
}



main()
{
    local status=0
    configureGlobals
    parseAndValidateCommandLine $@

    if [ $ACTION == "start_first_node" ]
    then
        EC2_NAME_TAG="${EC2_NAME_TAG}-1"

        ### Install AWS CLI if does not exist
        sys_installAwsCliIfNotPresent

        ### TBD MED: Setup user profile - create aws_profile_lib.sh

        ### Create AWS key_pair if does not exist
        echo -e -n "-> Checking existence of ssh key pair '$KEY_NAME' ... : "
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
                    safeExit 1
                fi
            fi
            echo -e -n "-> Creating ssh key pair '$KEY_NAME' ... : "
            create_aKeyPair_wKeyName_wPemOutputDir $SHADOW_MODE $KEY_NAME $PEM_OUT_DIR
            if [ $? -ne 0 ]
            then
                echo -e "${RED}ABORTING: Failed creating new key pair ${NC}$KEY_NAME${RED} and/or to store its '.pem' file at $PEM_OUT_DIR. Script will exit.${NC}"
                safeExit 1
            fi
        fi


        ### Create security group if does not exist
        echo -e -n "-> Checking existence of security group '$SECGRP_NAME' ... : "
        checkExistence_ofSecGrp_wSecGrpName_wAwsProfileName_wRegion $SHADOW_MODE $SECGRP_NAME $PROFILE_NAME $REGION
        if [ $? -ne 0 ]
        then
            echo -e -n "-> Creating security group '$SECGRP_NAME' ... : "
            create_aSecGrp_wSecGrpName_wDescription_wAwsProfileName_wRegion $SHADOW_MODE $SECGRP_NAME $SECGRP_DESC $PROFILE_NAME $REGION
            if [ $? -ne 0 ]
            then
                echo -e "${RED}ABORTING: Failed creating new security group ${NC}$SECGRP_NAME${RED}. Script will exit.${NC}"
                safeExit 1
            fi
        fi


        ### Create EBS volume named $EBS_VOLUME_NAME_FOR_FIRST_NODE for EC2 ? (if does not exist)
        # TBD LOW
        ### Attach EBS volume $EBS_VOLUME_NAME_FOR_FIRST_NODE (if -ec2 ID given, and it does not have attached EBS already)
        # TBD LOW



        ### Create iam role if does not exist, and attach policy
        echo -e -n "-> Checking existence of iam role '$ROLE_NAME' ... : "
        checkExistence_ofRole_wRoleName $SHADOW_MODE $ROLE_NAME
        if [ $? -ne 0 ]
        then
            echo -e -n "-> Creating iam role '$ROLE_NAME' ... : "
            create_aRole_wRoleName_wAssumeRolePolicyJsonAbsPath $SHADOW_MODE $ROLE_NAME $ASSUME_ROLE_POLICY_JSON_ABS_PATH
            if [ $? -ne 0 ]
            then
                echo -e "${RED}ABORTING: Failed creating new iam role ${NC}$ROLE_NAME${RED}. Script will exit.${NC}"
                safeExit 1
            fi

            echo -e -n "-> Attaching policy $POLICY_ARN_SSM_FOR_EC2 to iam role '$ROLE_NAME' ... : "
            attachPolicy_toRole_wRoleName_wPolicyArn $SHADOW_MODE $ROLE_NAME $POLICY_ARN_SSM_FOR_EC2
            if [ $? -ne 0 ]
            then
               echo -e "${RED}ABORTING: Failed attaching policy ${NC}$POLICY_ARN_SSM_FOR_EC2${RED} to iam role ${NC}$ROLE_NAME${RED}. Script will exit.${NC}"
               safeExit 1
            fi
        fi


        ### Create instance profile if does not exist, and add role
        echo -e -n "-> Checking existence of instance profile '$INSTANCE_PROFILE_NAME' ... : "
        checkExistence_ofInstProfile_wInstProfileName $SHADOW_MODE $INSTANCE_PROFILE_NAME
        if [ $? -ne 0 ]
        then
            echo -e -n "-> Creating instance profile '$INSTANCE_PROFILE_NAME' ... : "
            create_anInstProfile_wInstProfileName $SHADOW_MODE $INSTANCE_PROFILE_NAME
            if [ $? -ne 0 ]
            then
                echo -e "${RED}ABORTING: Failed creating new instance profile ${NC}$INSTANCE_PROFILE_NAME${RED}. Script will exit.${NC}"
                safeExit 1
            fi

            echo -e -n "-> Adding role $ROLE_NAME to instance profile '$INSTANCE_PROFILE_NAME' ... : "
            addRole_toInstProfile_wInstProfileName_wRoleName $SHADOW_MODE $INSTANCE_PROFILE_NAME $ROLE_NAME
            if [ $? -ne 0 ]
            then
               echo -e "${RED}ABORTING: Failed adding rolw ${NC}$ROLE_NAME${RED} to instance profile ${NC}$INSTANCE_PROFILE${RED}. Script will exit.${NC}"
               safeExit 1
            fi
        fi


        ### Create EC2, if "-ec2 create" is passed, else check existence of given EC2 id 
        if [ $EC2_OPTION == "create" ]
        then
            echo -e -n "-> Creating EC2 instance ... : "
            EC2_ID=$(createAndGetId_ofEc2_wAmiId_wInstType_wKeyName_wSecGrpName $SCRIPT_MODE $SHADOW_MODE $AMI_ID $INSTANCE_TYPE $KEY_NAME $SECGRP_NAME)
            if [ $? -ne 0 ]
            then
                echo -e "${RED}could_not_create${NC}"
                echo -e "${RED}ABORTING: Failed creating new EC2 instance. Script will exit.${NC}"
                safeExit 1
            else
                echo -e "${GREEN}created $EC2_ID${NC}"
            fi

            echo -e -n "-> Adding name $EC2_NAME_TAG to EC2 instance $EC2_ID ... : "
            addName_toEc2_wInstId_wName $SHADOW_MODE $EC2_ID $EC2_NAME_TAG
            if [ $? -ne 0 ]
            then
                echo -e "${RED}ABORTING: Failed adding name $EC2_NAME_TAG to EC2 instance $EC2_ID. Script will exit.${NC}"
                safeExit 1
            fi

        else # "-ec2 id=*" must have been passed
            echo -e -n "-> Checking existence of EC2 instance with instance ID $EC2_ID ... : "
            checkExistence_ofEc2_wInstId $SHADOW_MODE $EC2_ID
            if [ $? -ne 0 ]
            then
                echo -e "${RED}ABORTING: EC2 instance with instance ID ${NC}$EC2_ID${RED} not found. Script will exit.${NC}"
                safeExit 1
            fi
            WAIT_SECONDS_BEFORE_NEW_EC2_INSTANCE_RUNS=0
        fi


        ### Set user data to EC2, if required
        # TBD LOW


        ### Get Arn of instance profile
        echo -e -n "-> Getting ARN of instance profile $INSTANCE_PROFILE_NAME ... : "
        INSTANCE_PROFILE_ARN=$(getArn_ofInstProfile_wInstProfileName ${SCRIPT_MODE} ${SHADOW_MODE} ${INSTANCE_PROFILE_NAME})
        if [ $? -ne 0 ]
        then
            echo -e "${RED}could_not_get${NC}"
            echo -e "${RED}ABORTING: Failed getting ARN of instance profile ${NC}$INSTANCE_PROFILE_NAME${RED}. Script will exit.${NC}"
            safeExit 1
        else
            echo -e "${GREEN}got $INSTANCE_PROFILE_ARN${NC}"
        fi



        ### Attach instance profile to EC2, if not already attached
        echo -e -n "-> Getting ARN of EC2 instance profile for instance with ID $EC2_ID ... : "
        EC2_INSTANCE_PROFILE_ARN=$(getInstProfileArn_ofEc2_wInstId ${SCRIPT_MODE} ${SHADOW_MODE} ${EC2_ID})
        if [ $? -ne 0 ]
        then
            echo -e "${RED}could_not_get${NC}"
            echo -e "${RED}ABORTING: Failed getting ARN of instance profile ${NC}$INSTANCE_PROFILE_NAME${RED}. Script will exit.${NC}"
            safeExit 1
        else
            echo -e "${GREEN}got '$EC2_INSTANCE_PROFILE_ARN'${NC}"
            if [[ $EC2_INSTANCE_PROFILE_ARN == "failed" || $EC2_INSTANCE_PROFILE_ARN == "" ]]
            then
            # No profile attached, so just attach $INSTANCE_PROFILE_ARN
                echo -e -n "-> Associating instance profile $INSTANCE_PROFILE_NAME to EC2 instance with instance ID $EC2_ID ... (waiting $WAIT_SECONDS_BEFORE_NEW_EC2_INSTANCE_RUNS seconds) : "
                sleep $WAIT_SECONDS_BEFORE_NEW_EC2_INSTANCE_RUNS
                associateInstProfile_toEc2_wInstId_wInstProfileName $SHADOW_MODE $EC2_ID $INSTANCE_PROFILE_NAME
                if [ $? -ne 0 ]
                then
                    echo -e "${RED}ABORTING: Failed associating instance profile ${NC}$INSTANCE_PROFILE_NAME${RED} to EC2 instance with instance ID ${NC}$EC2_ID${RED}. Script will exit.${NC}"
                    safeExit 1
                fi
            elif [[ $EC2_INSTANCE_PROFILE_ARN != $INSTANCE_PROFILE_ARN ]]
            then
            # Some other profile attached, hence abort to not mess with the existing roles of the EC2
                echo -e "${RED}ABORTING: EC2 instance ${NC}$EC2_ID${RED} is already associated with an instance profile ${NC}'$EC2_INSTANCE_PROFILE_ARN'${RED}. To avoid messing with the roles currently assumed by the EC2, the script did not change the ec2's association to the new instance profile ${NC}$INSTANCE_PROFILE_ARN${RED}, as required. Script will exit. To use the EC2 instance, please replace its instance profile manually from AWS console.${NC}"
                safeExit 1
            else
            # Required role already associated, so nothing to do
                :
            fi
        fi


        ### Checking inbound permission for SSH (tcp/22) to my IP
        echo -e -n "-> Checking inbound SSH permission of my public IP $MY_PUBLIC_IP in security group $SECGRP_NAME ... : "
        checkInboundPermission_ofSecGrp_wSecGrpName_wProtocol_wPort_wCidr $SCRIPT_MODE $SHADOW_MODE $SECGRP_NAME "tcp" "22" "$MY_PUBLIC_IP/32"
        if [ $? -eq 0 ]
        then
            echo -e "${GREEN}already permitted${NC}"
        else
            echo -e "${RED}to be permitted${NC}"

            ### Grant the security group inbound permission for SSH (tcp/22) to my IP
            echo -e -n "-> Granting inbound SSH permission of my public IP $MY_PUBLIC_IP to security group $SECGRP_NAME ... : "
            grantPermission_ofSecGrp_wSecGrpName_wAwsProfileName_wRegion_wProtocol_wPort_wCidr $SHADOW_MODE $SECGRP_NAME $PROFILE_NAME $REGION tcp 22 "$MY_PUBLIC_IP/32"
            if [ $? -ne 0 ]
            then
                echo -e "${RED}ABORTING: Failed granting inbound SSH permission of my public IP ${NC}$MY_PUBLIC_IP${RED} to security group ${NC}$SECGRP_NAME${RED}. Script will exit.${NC}"
                safeExit 1
            fi
        fi


        ### Get private IP address of EC2 instance $EC2_ID
        echo -e -n "-> Getting private IPv4 address of EC2 instance with instance ID $EC2_ID ... : "
        EC2_PRIVATE_IP=$(getPrivateIpv4_ofEc2_wInstId ${SHADOW_MODE} ${EC2_ID} )
        if [ $? -ne 0 ]
        then
            echo -e "${RED}ABORTING: Failed getting private IPv4 address of EC2 instance with instance ID ${NC}$EC2_ID${RED}. Script will exit.${NC}"
            safeExit 1
        else
            echo -e "${GREEN}got $EC2_PRIVATE_IP${NC}"
        fi


        ### Checking inbound permission for HTTP (tcp/8080) of $EC2_PRIVATE_IP in $SECGRP_NAME
        echo -e -n "-> Checking inbound HTTP permission of EC2 private IP $EC2_PRIVATE_IP in security group $SECGRP_NAME ... : "
        checkInboundPermission_ofSecGrp_wSecGrpName_wProtocol_wPort_wCidr $SCRIPT_MODE $SHADOW_MODE $SECGRP_NAME "tcp" "8080" "$EC2_PRIVATE_IP/32"
        if [ $? -eq 0 ]
        then
            echo -e "${GREEN}already permitted${NC}"
        else
            echo -e "${RED}to be permitted${NC}"

            ### Grant the security group inbound permission for HTTP (tcp/8080) to the private IP of instance $EC2_ID. This is needed for a single security group to be shared within a Zookeeper cluster of many EC2 instances
            echo -e -n "-> Granting inbound HTTP permission of EC2 instance's private IP $EC2_PRIVATE_IP to security group $SECGRP_NAME ... : "
            grantPermission_ofSecGrp_wSecGrpName_wAwsProfileName_wRegion_wProtocol_wPort_wCidr $SHADOW_MODE $SECGRP_NAME $PROFILE_NAME $REGION tcp 8080 "$EC2_PRIVATE_IP/32"
            if [ $? -ne 0 ]
            then
                echo -e "${RED}ABORTING: Failed granting inbound HTTP permission of EC2 instance's private IP ${NC}$EC2_PRIVATE_IP${RED} to security group ${NC}$SECGRP_NAME${RED}. Script will exit.${NC}"
                safeExit 1
            fi
        fi



        ### TBD Low: Check existence of S3 bucket named $SSM_COMMAND_OUTPUT_S3_BUCKET_NAME
        ### If does not exist
            ### Create S3 bucket named $SSM_COMMAND_OUTPUT_S3_BUCKET_NAME 
            ### Look into reviseAwsResourceNameToAddPrefix() to add prefix



        echo -e -n "-> Starting first Zookeeper node on EC2 with instance ID $EC2_ID ... : "
        local ssmCommandId=$(startFirstZookeeperNodeOnEc2 ${SCRIPT_MODE} ${SHADOW_MODE} ${EC2_ID} )
        if [ $? -ne 0 ]
        then
            echo -e "${RED}ABORTING: Failed starting first Zookeeper node on EC2 instance ID ${NC}$EC2_ID${RED} due to failed/incomplete SSM command. To debug, look into SSM command history from AWS console. Script will exit.${NC}"
            echo "1"
            safeExit 1
        else
            echo "started Zookeeper at $EC2_ID"
            safeExit 0
        fi
    fi
}



main $@
####### END OF LAST FUNCTION #######
