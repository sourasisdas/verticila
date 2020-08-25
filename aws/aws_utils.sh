#!/bin/bash

executeAwsCommand()
{
    eval shadowMode="$1"
    eval commandString="$2"
    eval passMsg="$3"
    eval failMsg="$4"

    local trimmedCommandString="$(sed -e 's/[[:space:]]*$/ /' <<<${commandString})"
    
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
        local status=$?
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
        if [ $? -ne 0 ]
        then
            retVal="failed"
        fi
        echo "$retVal" >> $outStream 2>&1
        echo $retVal
    else
        echo $trimmedCommandString
    fi
}



