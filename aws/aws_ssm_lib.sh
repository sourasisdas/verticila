#!/bin/bash

invokeAndGetId_ofSsmCmd_wRemoteCmdString_wEc2InstId_wStartTimeout_wExecTimeout_wOutS3BktName_wRegion()
{
    eval shadowMode="$1"
    eval wRemoteCmdString="$2"
    eval wEc2InstId="$3"
    eval wStartTimeout="$4"
    eval wExecTimeout="$5"
    eval wOutS3BktName="$6"
    eval wRegion="$7"

    source $VERTICILA_HOME/aws/aws_utils.sh
    local ssmCommandId=$(executeRemoteSsmCommandAndEchoReturnValue "\${shadowMode}" "\${wRemoteCmdString}" "\${wEc2InstId}" "\${wStartTimeout}" "\${wExecTimeout}" "\${wOutS3BktName}" "\${wRegion}")
    local status=$?
    echo $ssmCommandId
    return $?
}


waitAndGetStatus_ofSsmCmd_wSsmCmdId_wEc2InstId_wTimeToWait()
{
    eval shadowMode="$1"
    eval wSsmCmdId="$2"
    eval wEc2InstId="$3"
    eval wTimeToWait="$4"

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
            echo "ssm_command_status_untraceable"
            return 2
        fi

        if [ $commandStatus == "Success" ]
        then
            echo "ssm_command_successfully_executed"
            return 0
        elif [ $commandStatus == "Failed" ]
            echo "ssm_command_executed_with_failure"
            return 1
        else
            :   # Continue until waiting time is over
        fi

        totalTimeWaited=$(( $totalTimeWaited + $timeToWaitInEachIteration ))
        if [ $totalTimeWaited -ge $totalTimeout ]
        then
            echo "ssm_command_run_timeout"
            return 3
        fi
    done
}

invokeAndGetStatus_ofSsmCmd_wRemoteCmdString_wEc2InstId_wStartTimeout_wExecTimeout_wOutS3BktName_wRegion()
{
    eval shadowMode="$1"
    eval wRemoteCmdString="$2"
    eval wEc2InstId="$3"
    eval wStartTimeout="$4"
    eval wExecTimeout="$5"
    eval wOutS3BktName="$6"
    eval wRegion="$7"

    local ssmCommandId=$(invokeAndGetId_ofSsmCmd_wRemoteCmdString_wEc2InstId_wStartTimeout_wExecTimeout_wOutS3BktName_wRegion "\${shadowMode}" "\${wRemoteCmdString}" "\${wEc2InstId}" "\${wStartTimeout}" "\${wExecTimeout}" "\${wOutS3BktName}" "\${wRegion}")
    local status=$?

    if [ $status -ne 0 ]
    then
        echo "ssm_command_invocation_failed"
        return $status
    fi


    ### Let SSM command execution finish, and get back status of it
    local totalTimeout=$(( $wStartTimeout + $wExecTimeout ))
    local ssmCommandStatus=$(waitAndGetStatus_ofSsmCmd_wSsmCmdId_wEc2InstId_wTimeToWait "\${shadowMode}" "\${ssmCommandId}" "\${wEc2InstId}" "\${totalTimeout}")
    status=$?

    echo $ssmCommandStatus
    return $status
}
