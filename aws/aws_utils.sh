#!/bin/bash

executeAwsCommand()
{
    eval shadowMode="$1"
    eval commandString="$2"
    eval passMsg="$3"
    eval failMsg="$4"

    local trimmedCommandString="$(sed -e 's/[[:space:]]*$/ /' <<<${commandString})"
    local status=0
    
    if [ $shadowMode -eq 0 ]
    then
        local outStream="/dev/null"
        if [[ ! -z "${VERTICILA_LOG_FILE_NAME}" ]]
        then
            mkdir -p ~/.verticila/
            outStream=~/.verticila/${VERTICILA_LOG_FILE_NAME}
            touch $outStream
            tail -n 2000 $outStream > $outStream.tmp
            mv $outStream.tmp $outStream
        fi

        if [[ ! -z "${VERTICILA_LOG_FILE_NAME}" ]]
        then
            echo >> $outStream ;
            echo "################ $trimmedCommandString" >> $outStream 2>&1
        fi

        eval $trimmedCommandString >> $outStream 2>&1
        status=$?
        echo "STATUS=$status" >> $outStream 2>&1

        if [ $status -eq 0 ]
        then
            echo $passMsg
        else
            echo $failMsg
        fi
    else
        echo $trimmedCommandString
    fi
    return $status
}

executeAwsCommandAndLogOutput()
{
    eval shadowMode="$1"
    eval commandString="$2"
    eval passMsg="$3"
    eval failMsg="$4"
    eval logFile="$5"

    CURR_VERTICILA_LOG_FILE_NAME=${VERTICILA_LOG_FILE_NAME}

    VERTICILA_LOG_FILE_NAME=$logFile
    mkdir -p ~/.verticila/
    outStream=~/.verticila/${VERTICILA_LOG_FILE_NAME}
    rm -rf $outStream
    touch $outStream

    local status=executeAwsCommand $shadowMode $commandString $passMsg $failMsg
    VERTICILA_LOG_FILE_NAME=$CURR_VERTICILA_LOG_FILE_NAME

    if [[ ! -z "${VERTICILA_LOG_FILE_NAME}" ]]
    then
        cat $outStream >> ~/.verticila/${VERTICILA_LOG_FILE_NAME}
    fi

    return $status
}


executeAwsCommandAndEchoReturnValue()
{
    eval shadowMode="$1"
    eval commandString="$2"

    local trimmedCommandString="$(sed -e 's/[[:space:]]*$/ /' <<<${commandString})"
    local status=0
    
    if [ $shadowMode -eq 0 ]
    then
        local outStream="/dev/null"
        if [[ ! -z "${VERTICILA_LOG_FILE_NAME}" ]]
        then
            mkdir -p ~/.verticila/
            outStream=~/.verticila/${VERTICILA_LOG_FILE_NAME}
            touch $outStream
            tail -n 2000 $outStream > $outStream.tmp
            mv $outStream.tmp $outStream
        fi

        if [[ ! -z "${VERTICILA_LOG_FILE_NAME}" ]]
        then
            echo >> $outStream ;
            echo "################ $trimmedCommandString" >> $outStream 2>&1
        fi

        local retVal=`$trimmedCommandString`
        status=$?
        if [ $status -ne 0 ]
        then
            retVal="failed"
        fi
        echo "$retVal" >> $outStream 2>&1
        echo $retVal
    else
        echo $trimmedCommandString
    fi
    return $status
}

executeRemoteSsmCommandAndEchoReturnValue()
{
    eval shadowMode="$1"
    eval remoteCommandToRun="$2"
    eval ec2InstanceId="$3"
    eval startTimeout="$4"
    eval executionTimeout="$5"
    eval outputS3BucketName="$6"
    eval region="$7"

    local commandString=="aws ssm send-command --document-name "\""AWS-RunShellScript"\"" --document-version "\""1"\"" --targets '[{"\""Key"\"":"\""InstanceIds"\"","\""Values"\"":["\""$ec2InstanceId"\""]}]' --parameters '{"\""commands"\"":["\""$remoteCommandToRun"\""],"\""workingDirectory"\"":["\"""\""],"\""executionTimeout"\"":["\""$executionTimeout"\""]}' --timeout-seconds $startTimeout --max-concurrency "\""50"\"" --max-errors "\""0"\"" --output-s3-bucket-name "\""$outputS3BucketName"\"" --region $region" --query "Command.CommandId" --output text

    local trimmedCommandString="$(sed -e 's/[[:space:]]*$/ /' <<<${commandString})"
    local status=0
    
    if [ $shadowMode -eq 0 ]
    then
        local outStream="/dev/null"
        if [[ ! -z "${VERTICILA_LOG_FILE_NAME}" ]]
        then
            mkdir -p ~/.verticila/
            outStream=~/.verticila/${VERTICILA_LOG_FILE_NAME}
            touch $outStream
            tail -n 2000 $outStream > $outStream.tmp
            mv $outStream.tmp $outStream
        fi

        if [[ ! -z "${VERTICILA_LOG_FILE_NAME}" ]]
        then
            echo >> $outStream ;
            echo "################ $trimmedCommandString" >> $outStream 2>&1
        fi

        local retVal=`$trimmedCommandString`
        status=$?
        if [ $status -ne 0 ]
        then
            retVal="failed"
        fi
        echo "$retVal" >> $outStream 2>&1
        echo $retVal
    else
        echo $trimmedCommandString
    fi
    return $status
}
