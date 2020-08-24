#!/bin/bash

executeAwsCommandAndExit()
{
    eval shadowMode="$1"
    eval commandString="$2"
    eval passMsg="$3"
    eval failMsg="$4"

    local trimmedCommandString="$(sed -e 's/[[:space:]]*$/ /' <<<${commandString})"
    
    if [ $shadowMode -eq 0 ]
    then
        local outStream=/dev/null
        if [ $VERTICILA_LOGGING -eq 1 ]
        then
            outStream=~/.verticila/log
            mkdir -p ~/.verticila/
            touch $outStream
            tail -n 2000 $outStream > ~/.verticila/log.tmp
            mv ~/.verticila/log.tmp $outStream
        fi

        if [ $VERTICILA_LOGGING -eq 1 ]
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
    exit $status
}
