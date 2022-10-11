#!/bin/bash
exec 3>&1 1>&2
set -o nounset

declare -r _EMPTY_TOKEN_=''
declare -r _SYMBOL_TOKEN_='symbol'
declare -r _STRING_TOKEN_='string'
declare -r _NUMBER_TOKEN_='number'
declare -r _OPERATION_TOKEN_='operation'
declare -r _NO_VALUE_=''
declare -r _AMPERSAND_='&'
declare -r _NEWLINE_='\n'
declare -r _CARRIAGE_RETURN_='\r'
declare -r _CHAR_PIPE_='|'
declare -r _SEMICOLON_=';'
declare -r _COLON_=':'
declare -r _PLUS_SIGN_='+'
declare -r _MINUS_SIGN_='-'
declare -r _EQUAL_SIGN_='='
declare -r _COMMA_=','_DIV_
declare -r _PARAN_OPEN_='('
declare -r _PARAN_CLOSE_=')'
declare -r _QUOTE_="'"
declare -r _DOUBLE_QUOTE_='"'
declare -r _CURLY_OPEN_='{'
declare -r _CURLY_CLOSE_='}'
declare -r _MUL_='*'
declare -r _DIV_='/'
declare -r _TAB_='\t'

stop() {
   declare -r message=${1:-"OK (/)"}
   declare -r -i exit_code=${2:-0}
   if [[ ${exit_code} -gt 0 ]] || [[ ${OPT_DEBUG} ]]; then 
      printf '%s (%i)\n' "${message}" "${exit_code}"
   fi
   exit "${exit_code}"
}

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

declare OPT_DEBUG=
declare ARG_BUFFER=
declare ARG_CHAR=
declare ARG_EXPRESSION=
declare INFLILE=/dev/null

eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    -g | --debug)      declare -r OPT_DEBUG=1         ; shift   ;;
    -b | --buffer)     declare -r ARG_BUFFER="$2"     ; shift 2 ;;
    -c | --char)       declare -r ARG_CHAR="$2"       ; shift 2 ;;
    -e | --expression) declare -r ARG_EXPRESSION="$3" ; shift 2 ;;
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

#if [[ ! -z ${@} ]]; then declare -r INFLILE=${1} ; fi # the remaining parameter is supposed to be the filname
if [[ ! -z ${@} ]]; then INFLILE=${1} ; fi # the remaining parameter is supposed to be the filname

if [[ ${OPT_DEBUG} ]]; then 
   echo "PARSED_ARGUMENTS is '$PARSED_ARGUMENTS'"
   echo "OPT_DEBUG      : '${OPT_DEBUG}'"
   echo "ARG_BUFFER     : '${ARG_BUFFER}'"
   echo "ARG_CHAR       : '${ARG_CHAR}'"
   echo "ARG_EXPRESSION : '${ARG_EXPRESSION}'"
   echo "INFILE         : '${INFLILE}' (alias filename)"
   echo "Parameters remaining are: '${@}'"
fi

if [[ ! -r ${INFLILE} ]]; then stop "filename '${INFLILE}' is not readable or does not exist" '22' ; fi
declare -r from_source_file=${INFLILE}; 
 
ORIG_IFS="$IFS"
IFS=$';\n'
set +o errexit # -d '' works like a charm, but with exit code (1)?!
read -d '' -a source_code < "${from_source_file}" # don't stop on 'pipes', 'newlines' and 'semicolons' 
set -o errexit
IFS="$ORIG_IFS"
if [[ ${OPT_DEBUG} ]]; then echo '---';for element in "${source_code[@]}" ; do echo "$element" ; done ; echo '---'; fi

# remove recursion, hence the use of global variable is sufficient
declare BUFF=''
declare C=''
declare TOKEN=''
declare -i AMOUNT_OF_PROCESSED_CHARS=0
function lex () {

BUFF="${1}"
BUFF=${BUFF:${AMOUNT_OF_PROCESSED_CHARS}:${#BUFF}}
C="${BUFF:0:1}"
TOKEN="${2}"

#echo -n "${TOKEN} " >&3
if [[ ! -z ${TOKEN} ]]; then echo "${TOKEN} " >&3 ; fi

if [[ ${OPT_DEBUG} ]]; then
   echo "TOKEN = »${TOKEN}«"
   echo "C = »${C}«"              
   echo "BUFF = »${BUFF}« [${#BUFF}]"
   echo "AMOUNT_OF_PROCESSED_CHARS = [${AMOUNT_OF_PROCESSED_CHARS}]"
fi

if [[ 1 -gt "${#BUFF}" ]]; then return ; fi # here it's about time for the nest line of code
#if [[ 1 -gt "${#C}"    ]]; then return ; fi

case "${C}" in
   [[:space:]]) 
      TOKEN="${_EMPTY_TOKEN_}"
      if [[ 2 -gt ${#BUFF} ]]; then BUFF=""; fi
      AMOUNT_OF_PROCESSED_CHARS=1
      lex "${BUFF}" "${TOKEN}"
   ;;
   "${_PARAN_OPEN_}"|"${_PARAN_CLOSE_}"|"${_CURLY_OPEN_}"|"${_CURLY_CLOSE_}"|"${_COMMA_}"|"${_SEMICOLON_}"|"${_EQUAL_SIGN_}"|"${_COLON_}")
      TOKEN="('${C}', '${_NO_VALUE_}')" # special character are thier own type, but without a value
      if [[ 2 -gt ${#BUFF} ]]; then BUFF=""; fi
      AMOUNT_OF_PROCESSED_CHARS=1
      lex "${BUFF}" "${TOKEN}"
   ;;
   "${_PLUS_SIGN_}"|"${_MINUS_SIGN_}"|"\${_MUL_}"|"${_DIV_}")
      TOKEN="('${_OPERATION_TOKEN_}', '${C}')"
      if [[ 2 -gt ${#BUFF} ]]; then BUFF=""; fi
      AMOUNT_OF_PROCESSED_CHARS=1
      lex "${BUFF}" "${TOKEN}"
   ;;
   "${_QUOTE_}"|"${_DOUBLE_QUOTE_}")
      pattern="([\ a-zA-Z0-9.:,;%?=&$§^#_\(\)\{\})\[\]]){0,}"
      string_plus_quotes="$(grep -o -P "[${C}]${pattern}[${C}]" <<< ${BUFF})"
      string_len_plus_quotes="${#string_plus_quotes}"
      if [[ ${string_plus_quotes: -1} != ${C} ]]; then stop 'A string ran off the end of the program.' '77' ; fi
      string=${string_plus_quotes:1:-1}
      TOKEN="('${_STRING_TOKEN_}', '${string}')"
      string_len="${#string}"
      AMOUNT_OF_PROCESSED_CHARS="${#string_plus_quotes}"
      lex "${BUFF}" "${TOKEN}"
   ;;
   [[:digit:]]|".")
      sloppy="[-+0-9.]*"
      pattern="(^([[:digit:]])*([.][[:digit:]]){,1}([[:digit:]])*)"
      number=$(grep -Eo "${pattern}" <<< ${BUFF})
      if [[ ${number} == '' ]]; then stop "'$(grep -Eo "${sloppy}" <<< ${BUFF})' is not a number" '1' ; fi
      TOKEN="('${_NUMBER_TOKEN_}', '${number}')"
      if [[ ${#number} -eq ${#BUFF} ]]; then BUFF=""; fi
      AMOUNT_OF_PROCESSED_CHARS="${#number}"
      lex "${BUFF}" "${TOKEN}"
   ;;
   [[:alpha:]])
      symbol=$(grep -o -E "^(([[:alpha:]]+)([[:alnum:][_])*)" <<< ${BUFF})
      TOKEN="('${_SYMBOL_TOKEN_}', '${symbol}')"
      #if [[ ${#symbol} -eq ${#BUFF} ]]; then BUFF=""; fi
      AMOUNT_OF_PROCESSED_CHARS="${#symbol}"
      lex "${BUFF}" "${TOKEN}"
   ;;
   "${_TAB_}")
      stop "Tabs are not allowed in Cell" '1'
      ;;
   *)
      stop "Unexpected character: >>${C}<<" '1'
   ;;
esac
}

if [[ ${ARG_BUFFER} ]]; then
   line=$(tr -d '\n\r\t' <<< ${ARG_BUFFER})
   chars=${#line}
      lex "${line}" "('ARG_BUFFER', '${line}')"
fi

amount_of_lines=${#source_code[*]}
for (( line_no=0; line_no<$(( $amount_of_lines )); line_no++ )); do
   AMOUNT_OF_PROCESSED_CHARS=0 # reset
   line=${source_code[line_no]}
   lex "${line}${_SEMICOLON_}" "('LINE_${line_no}', '${line}${_SEMICOLON_}')"
done
