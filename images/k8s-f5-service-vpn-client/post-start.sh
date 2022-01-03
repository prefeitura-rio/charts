#!/usr/bin/env bash

observe_f5fpc() {
  last_result=-1
  while [ 1 ] ; do
    output=$(/usr/local/bin/f5fpc -i)
    result=$?
    case $result in
      0) # Everything seems to be ok
        ;;
      1)
        if [ "$last_result" != "1" ] ; then
          echo "Session initialized"
        fi
        ;;
      2)
        if [ "$last_result" != "2" ] ; then
          echo "User login in progress"
        fi
        ;;
      3)
        if [ "$last_result" != "3" ] ; then
          echo "Waiting..."
        fi
        ;;
      4)
        if [ "$last_result" != "4" ] ; then
          echo "Retrieving favorites list..."
        fi
        ;;
      5)
        if [ "$last_result" != "5" ] ; then
          echo "Connection established successfully"
          exit
        fi
        ;;
      7)
        echo "Logon denied"
        echo "$output"
        echo "Shutting down..."
        echo ""
        exit 1
        ;;
      9)
        echo "Connection timed out"
        echo "Shutting down..."
        echo ""
        exit 1
        ;;
      85) # client not connected
        echo "Client not connected"
        echo "Shutting down..."
        echo ""
        exit 1
        ;;
      *)
        echo "Unknown result code: $result"
        echo "Please create an issue with this code here:"
        echo "https://github.com/prefeitura-rio/charts/issues/new"
        echo ""
        echo "Additional information:"
        echo "$output"
        ;;
    esac
    last_result="$result"
  done
}

observe_f5fpc