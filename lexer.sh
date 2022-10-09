#!/bin/bash
stop() {
  message=${1:-"OK (/)"}
  exit_code=${2:-0}
  printf >&2 '%s (%i)\n' "${message}" "${exit_code}"
  exit "${exit_code}"
}

DEV_NULL="/dev/null"
DEBUG=
BUFFER=
CHAR=
EXPRESSION=

usage()
{
  echo "Usage: ${0} [ -g | --debug ] 
                        [ -b | --buffer a string]
                        [ -c | --char a singe char ] 
                        [ -e | --expression (operation|string|number|symbol)]
                        [filename]"
  stop "Invalid argument" '22'
}

PARSED_ARGUMENTS=$(getopt -a -n ${0} -o g,b:c:e: --long debug,buffer:,char:,expression: -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    -g | --debug)      DEBUG=1         ; shift   ;;
    -b | --buffer)     BUFFER="$2"     ; shift 2 ;;
    -c | --char)       CHAR="$2"       ; shift 2 ;;
    -e | --expression) EXPRESSION="$2" ; shift 2 ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *) echo "Famous Last Words - Unexpected option: $1 - this should not happen."
       usage ;;
  esac
done

INFLILE="${1:-${DEV_NULL}}"
if [[ ${DEBUG} ]]; then 
   echo "PARSED_ARGUMENTS is $PARSED_ARGUMENTS"
   echo "DEBUG   : ${DEBUG}"
   echo "BUFFER  : ${BUFFER}"
   echo "CHAR    : ${CHAR}"
   echo "EXPRESSION   : ${EXPRESSION}"
   echo "INFLILE : ${INFLILE}"
   echo "Parameters remaining are: ${@}"
fi

from_source_file=${INFLILE} # play it save
 
ORIG_IFS="$IFS"
IFS=$'|\n;' ; read -d '' -a  source_code  < ${from_source_file} # don't stop on 'pipes', 'newlines' and 'semicolons'
IFS="$ORIG_IFS"
#if [[ ${DEBUG} ]]; then echo '---';for element in "${source_code[@]}" ; do echo "$element" ; done ; echo '---'; fi #


CHAR_AMPERSAND='&'
CHAR_EOF=EOF
CHAR_NEWLINE='\n'
CHAR_CARRIAGE_RETURN='\r'
CHAR_PIPE='|'
CHAR_SEMICOLON=';'
CHAR_COLON=':'
CHAR_PLUS_SIGN='+'
CHAR_MINUS_SIGN='-'
CHAR_EQUAL_SIGN='='
CHAR_COMMA=','
CHAR_PARAN_OPEN='('
CHAR_PARAN_CLOSE=')'
CHAR_QUOTE="'"
CHAR_DOUBLE_QUOTE='"'
CHAR_CURLY_OPEN='{'
CHAR_CURLY_CLOSE='}'
CHAR_MUL='*'
CHAR_DIV='/'
CHAR_TAB='\t'
PASS='0'

function lex () {
local c="${1}"
local buff="${2}"
local token="${3}"
echo "IN : c='${c}' buff='${buff}' [${#buff}] token='${token}'"

if [[ 1 -gt "${#buff}" ]]; then return ; fi # here it's about time for the nest line of code
if [[ 1 -gt "${#c}"    ]]; then return ; fi

case "${c}" in
   # Ignore (line breaking) white spacce
   [[:space:]]|"${CHAR_NEWLINE}"|"${CHAR_TAB}"|"${CHAR_CARRIAGE_RETURN}") 
      echo "pass:  # >>${c}<< is a [line breaking] whitspace"
      token='whitspace'
      if [[ 2 -gt ${#buff} ]]; then buff=""; fi
      buff="${buff: -(${#buff}-1)}"
      c="${buff:0:1}"
      echo "OUT: c='${c}' buff='${buff}' [${#buff}] token='${token}'" 
      if [[ 1 -gt ${#buff} ]]; then return; fi
      lex "${c}" "${buff}" "${token}"
   ;;
   # special character        
   ${CHAR_PARAN_OPEN}|${CHAR_PARAN_CLOSE}|${CHAR_CURLY_OPEN}|${CHAR_CURLY_CLOSE}|${CHAR_COMMA}|${CHAR_SEMICOLON}|${CHAR_EQUAL_SIGN}|${CHAR_COLON})
      #echo "yield(c, '') # is a special character "
      token='special'
      if [[ 2 -gt ${#buff} ]]; then buff=""; fi
      buff="${buff: -(${#buff}-1)}"
      c="${buff:0:1}"
      echo "OUT: c='${c}' buff='${buff}' [${#buff}] token='${token}'" 
      if [[ 1 -gt ${#buff} ]]; then return; fi
      lex "${c}" "${buff}" "${token}"
   ;;
   # operator
   ${CHAR_PLUS_SIGN}|${CHAR_MINUS_SIGN}|\${CHAR_MUL}|${CHAR_DIV})
      #echo "yield ('operation', c) # operator >>${c}<< "
      token='operation'
      if [[ 2 -gt ${#buff} ]]; then buff=""; fi
      buff="${buff: -(${#buff}-1)}"
      c="${buff:0:1}"
      echo "OUT: c='${c}' buff='${buff}' [${#buff}] token='${token}'" 
      if [[ 1 -gt ${#buff} ]]; then return; fi
      lex "${c}" "${buff}" "${token}"
   ;;
   # string
   ${CHAR_QUOTE}|${CHAR_DOUBLE_QUOTE})
      #echo "yield ('string', _scan_string(c, chars)) # >>${c}<<"
      token='string'
      if [[ 2 -gt ${#buff} ]]; then buff=""; fi
      buff="${buff: -(${#buff}-1)}"
      c="${buff:0:1}"
      echo "OUT: c='${c}' buff='${buff}' [${#buff}] token='${token}'" 
      if [[ 1 -gt ${#buff} ]]; then return; fi
      #lex "${c}" "${buff}" "${token}"
   ;;
   # number
   [[:digit:]])
      #echo "yield ('number', _scan(c, chars, \"[.0-9]\"))# >>${c}<<"
      token='number'
      if [[ 2 -gt ${#buff} ]]; then buff=""; fi
      echo "OUT: c='${c}' buff='${buff}' [${#buff}] token='${token}'" 
      if [[ 1 -gt ${#buff} ]]; then return; fi
      #lex "${c}" "${buff}" "${token}"
   ;;
   # symbols
   [[:alpha:]])
      #echo 'yield ('symbol', _scan(c, chars, "[_a-zA-Z0-9]"))'
      token="symbol"
      symbol=$(grep -o -E "^(([[:alpha:]]+)([[:alnum:][_])*)*" <<< ${buff})
      echo "symbol='${symbol}' [${#symbol}]"
      if [[ ${#symbol} -eq ${#buff} ]]; then buff=""; fi
      buff="${buff:${#symbol}:${#buff}}"
      c="${buff:0:1}"
      echo "OUT: c='${c}' buff='${buff}' [${#buff}] token='${token}'" 
      if [[ 1 -gt ${#buff} ]]; then return; fi
      lex "${c}" "${buff}" "${token}"
   ;;
   # TAB not allowed
   "${CHAR_TAB}")
      echo "OUT: c='${c}' buff='${buff}' [${#buff}] token='${token}'" 
      echo "raise Exception(\"Tabs >>${c}<< are not allowed in Cell\")"
      ;;
   *)
      echo "OUT: c='${c}' buff='${buff}' [${#buff}] token='${token}'" 
      echo "raise Exception(\"Unexpected character: >>${c}<<\")"
   ;;
esac
}

function PeekableString () {
    return
}

amount_of_lines=${#source_code[*]}

#source test.sh
### if [[ ! -z ${CHAR} ]] 
### then
###    lex "${CHAR}"
### fi

#   line=${source_code[line_no]}
#   chars=${#line}
if [[ ${BUFFER} ]]; then
   line=${BUFFER}
   chars=${#line}
###   for (( prev_char=-1, curr_char=0, next_char=1; curr_char<$(( $chars )); curr_char++, prev_char=curr_char-1, next_char=curr_char+1 ))
###   do
####      echo "#$line_no: $prev_char,$curr_char,$next_char;'${source_code[$CURR_LINE]}' char='${source_code[$line_no]:$curr_char:1}'"
####      echo "$prev_char,$curr_char,$next_char;'${line}' char='${line:$curr_char:1}'"
###
####      lex "${source_code[$line_no]:$curr_char:1}"
###
###      lex "${line:$curr_char:1}"
      lex  "${line:0:1}" "${line}"
stop
###
####      echo "< prev_char '${source_code[$line_no]:$prev_char:1}'"
####      echo "| curr_char   '${source_code[$line_no]:$curr_char:1}'"
####      echo "> next_char    '${source_code[$line_no]:$next_char:1}'"

###   done
fi

stop
