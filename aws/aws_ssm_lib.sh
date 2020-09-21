#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

invokeAndGetId_ofSsmCmd_wRemoteCmdString_wEc2InstId_wStartTimeout_wExecTimeout_wOutS3BktName_wRegion()
{
    eval scriptMode="$1"
    eval shadowMode="$2"
    eval wRemoteCmdString="$3"
    eval wEc2InstId="$4"
    eval wStartTimeout="$5"
    eval wExecTimeout="$6"
    eval wOutS3BktName="$7"
    eval wRegion="$8"

    source $VERTICILA_HOME/aws/aws_utils.sh
    local ssmCommandId=$(executeRemoteSsmCommandAndEchoReturnValue "\${shadowMode}" "\${wRemoteCmdString}" "\${wEc2InstId}" "\${wStartTimeout}" "\${wExecTimeout}" "\${wOutS3BktName}" "\${wRegion}")
    local status=$?
    echo $ssmCommandId
    return $?
}


waitAndGetStatus_ofSsmCmd_wSsmCmdId_wEc2InstId_wTimeToWait()
{
    eval scriptMode="$1"
    eval shadowMode="$2"
    eval wSsmCmdId="$3"
    eval wEc2InstId="$4"
    eval wTimeToWait="$5"

    ### Poll SSM command execution status every 1/100th of total time to wait
    local totalTimeWaited=0
    local timeToWaitInEachIteration=$(( $wTimeToWait / 100 ))
    while [ 1 ]
    do
        sleep $timeToWaitInEachIteration

        local CommandString="aws ssm get-command-invocation \
                             --instance-id $wEc2InstId \
                             --command-id $wSsmCmdId \
                             --query 'StatusDetails' \
                             --output text"

        source $VERTICILA_HOME/aws/aws_utils.sh
        local commandStatus=$(executeAwsCommandAndEchoReturnValue "\${shadowMode}" "\${commandString}")
        local status=$?
        if [ $status -ne 0 ]
        then
            echo -e "${RED}ssm_command_status_untraceable${NC}"
            return 2
        fi

        if [[ $commandStatus == "Success" ]]
        then
            echo -e "${GREEN}ssm_command_executed_successfully${NC}"
            return 0
        elif [[ $commandStatus == "Failed" ]]
        then
            echo -e "${RED}ssm_command_executed_with_failure${NC}"
            return 1
        else
            :   # Continue until waiting time is over
        fi

        totalTimeWaited=$(( $totalTimeWaited + $timeToWaitInEachIteration ))
        if [ $totalTimeWaited -ge $totalTimeout ]
        then
            echo -e "${RED}ssm_command_run_timeout${NC}"
            return 3
        fi
    done
}

invokeAndGetStatus_ofSsmCmd_wRemoteCmdString_wEc2InstId_wStartTimeout_wExecTimeout_wOutS3BktName_wRegion()
{
    eval scriptMode="$1"
    eval shadowMode="$2"
    eval wRemoteCmdString="$3"
    eval wEc2InstId="$4"
    eval wStartTimeout="$5"
    eval wExecTimeout="$6"
    eval wOutS3BktName="$7"
    eval wRegion="$8"

    local ssmCommandId=$(invokeAndGetId_ofSsmCmd_wRemoteCmdString_wEc2InstId_wStartTimeout_wExecTimeout_wOutS3BktName_wRegion "\${scriptMode}" "\${shadowMode}" "\${wRemoteCmdString}" "\${wEc2InstId}" "\${wStartTimeout}" "\${wExecTimeout}" "\${wOutS3BktName}" "\${wRegion}")
    local status=$?

    if [ $status -ne 0 ]
    then
        echo -e "${RED}ssm_command_invocation_failed${NC}"
        return $status
    else
        echo -e "${GREEN}ssh_command_invocation_success${NC}"
    fi


    ### Let SSM command execution finish, and get back status of it
    local totalTimeout=$(( $wStartTimeout + $wExecTimeout ))
    local ssmCommandStatus=$(waitAndGetStatus_ofSsmCmd_wSsmCmdId_wEc2InstId_wTimeToWait "\${scriptMode}" "\${shadowMode}" "\${ssmCommandId}" "\${wEc2InstId}" "\${totalTimeout}")
    status=$?

    echo $ssmCommandStatus
    return $status
}
