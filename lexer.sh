#!/bin/bash
exec 3>&1 1>&2
stop() {
   message=${1:-"OK (/)"}
   exit_code=${2:-0}

   if [[ ${exit_code} -gt 0 ]] || [[ ${DEBUG} ]]; then 
      printf '%s (%i)\n' "${message}" "${exit_code}"
   fi
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
    -e | --expression) EXPRESSION="$3" ; shift 2 ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *) echo "Famous Last Words - Unexpected option: $1 - this should not happen."
       usage 
       stop "Unkown Parameter or option found" '22'

   ;;
  esac
done

INFLILE="${1:-${DEV_NULL}}" && shift # play it save
#INFLILE="${1}"&& shift #
if [[ ${DEBUG} ]]; then 
   echo "PARSED_ARGUMENTS is '$PARSED_ARGUMENTS'"
   echo "DEBUG      : '${DEBUG}'"
   echo "BUFFER     : '${BUFFER}'"
   echo "CHAR       : '${CHAR}'"
   echo "EXPRESSION : '${EXPRESSION}'"
   echo "Parameters remaining are: '${@}'"
fi

if [[ ! -r ${INFLILE} ]]; then stop "file '${INFLILE}' not readable or does not exist" '22' ; fi
from_source_file=${INFLILE}
 
ORIG_IFS="$IFS"
IFS=$'|\n;' ; read -d '' -a  source_code  < ${from_source_file} # don't stop on 'pipes', 'newlines' and 'semicolons'
IFS="$ORIG_IFS"
if [[ ${DEBUG} ]]; then echo '---';for element in "${source_code[@]}" ; do echo "$element" ; done ; echo '---'; fi

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

buff=''
c=''
token=''

function lex () {

buff="${1}"
c="${buff:0:1}"
token="${2}"

#echo -n "${token} " >&3
if [[ ! -z ${token} ]]; then echo "${token} " >&3 ; fi

if [[ ${DEBUG} ]]; then
   echo "token = »${token}«"
   echo "c = »${c}«"              
   echo "buff = »${buff}« [${#buff}]"
fi

if [[ 1 -gt "${#buff}" ]]; then return ; fi # here it's about time for the nest line of code
if [[ 1 -gt "${#c}"    ]]; then return ; fi

case "${c}" in
   # Ignore whitespacce
   [[:space:]]) 
      ###"pass:  # >>${c}<< is a [line breaking] whitspace"
      token=''
      if [[ 2 -gt ${#buff} ]]; then buff=""; fi
      buff="${buff: -(${#buff}-1)}"
      if [[ 1 -gt ${#buff} ]]; then return; fi
      lex "${buff}" "${token}"
   ;;
   # special character        
   "${CHAR_PARAN_OPEN}"|"${CHAR_PARAN_CLOSE}"|"${CHAR_CURLY_OPEN}"|"${CHAR_CURLY_CLOSE}"|"${CHAR_COMMA}"|"${CHAR_SEMICOLON}"|"${CHAR_EQUAL_SIGN}"|"${CHAR_COLON}")
      ###"yield(c, '') # is a special character "
      token="('${c}', '')"
      if [[ 2 -gt ${#buff} ]]; then buff=""; fi
      buff="${buff: -(${#buff}-1)}"
      lex "${buff}" "${token}"
   ;;
   # operator
   "${CHAR_PLUS_SIGN}"|"${CHAR_MINUS_SIGN}"|"\${CHAR_MUL}"|"${CHAR_DIV}")
      ###"yield ('operation', c) # operator >>${c}<< "
      token="('operation', '${c}')"
      if [[ 2 -gt ${#buff} ]]; then buff=""; fi
      buff="${buff: -(${#buff}-1)}"
      lex "${buff}" "${token}"
   ;;
   # string
   "${CHAR_QUOTE}"|"${CHAR_DOUBLE_QUOTE}")
      ###"yield ('string', _scan_string(c, chars)) # >>${c}<<"
      pattern="([\ a-zA-Z0-9.:,;%?=&$§^#_\(\)\{\})\[\]]){0,}"
      string_plus_quotes="$(grep -o -P "[${c}]${pattern}[${c}]" <<< ${buff})"
      string_len_plus_quotes="${#string_plus_quotes}"
      if [[ ${string_plus_quotes: -1} != ${c} ]]; then stop 'A string ran off the end of the program.' '77' ; fi
      string=${string_plus_quotes:1:-1}
      token="('string', '${string}')"
      string_len="${#string}"
      buff="${buff:${string_len_plus_quotes}:${#buff}}"
      lex "${buff}" "${token}"
   ;;
   # number
   [[:digit:]]|".")
      ###"yield ('number', _scan(c, chars, '[.0-9]))# >>${c}<<"
      sloppy=""
      pattern="(^([[:digit:]])*([.][[:digit:]]){,1}([[:digit:]])*)"
      number=$(grep -Eo "${pattern}" <<< ${buff})
      if [[ ${number} == '' ]]; then stop "'$(grep -Eo "[-+0-9.]*" <<< ${buff})' is not a number" '1' ; fi
      token="('number', '${number}')"
      if [[ ${#number} -eq ${#buff} ]]; then buff=""; fi
      buff="${buff:${#number}:${#buff}}"
      lex "${buff}" "${token}"
   ;;
   # symbols
   [[:alpha:]])
      ###'yield ('symbol', _scan(c, chars, "[_a-zA-Z0-9]"))'
      symbol=$(grep -o -E "^(([[:alpha:]]+)([[:alnum:][_])*)*" <<< ${buff})
      token="('symbol', '${symbol}')"
      if [[ ${#symbol} -eq ${#buff} ]]; then buff=""; fi
      buff="${buff:${#symbol}:${#buff}}"
      lex "${buff}" "${token}"
   ;;
   # TAB not allowed
   "${CHAR_TAB}")
      stop "raise Exception(\"Tabs >>${c}<< are not allowed in Cell\")" '1'
      ;;
   *)
      stop "raise Exception(\"Unexpected character: >>${c}<<\")" '1'
   ;;
esac
}

if [[ ${BUFFER} ]]; then
   line=$(tr -d '\n\r\t' <<< ${BUFFER})
   chars=${#line}
      lex "${line}" "('BUFFER', '${line}')"
fi

amount_of_lines=${#source_code[*]}
if [[ amount_of_lines -gt 0 ]]; then
   for (( line_no=0; line_no<$(( $amount_of_lines )); line_no++ )); do
      line=${source_code[line_no]}
      lex "${line}${CHAR_SEMICOLON}" "('LINE_${line_no}', '${line}${CHAR_SEMICOLON}')"
   done
fi
