#!/bin/bash
#set -o nounset

function testFunc(){
    echo "param #1 is : '$1'"
    echo "param #2 is : '$2'"
    echo "param #3 is : '$3'"
    echo "---"
}



testFunc
testFunc "1" "2" "3"
testFunc ""  "2" "3"
testFunc "1" "" "3"
testFunc "1" "2" ""
testFunc "" " " "  "
