#!/bin/bash
exec 3>&1 1>&2
set -o errexit
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

################################################################################
### start of function lex ######################################################
################################################################################
function lex () {
   declare BUFF="${1}"
   declare TOKEN="${2}"
   declare C
   declare -i AMOUNT_OF_PROCESSED_CHARS=0
   while [[ true ]]; do
      BUFF=${BUFF:${AMOUNT_OF_PROCESSED_CHARS}:${#BUFF}}
      C="${BUFF:0:1}"
      if [[ ! -z ${TOKEN} ]]; then echo "${TOKEN} " >&3 ; fi
      #############################
      [[ 0 -lt ${#BUFF} ]] || break
      #############################      
      if [[ ${OPT_DEBUG} ]]; then
         echo "TOKEN = »${TOKEN}«"
         echo "C = »${C}«"              
         echo "BUFF = »${BUFF}« [${#BUFF}]"
         echo "AMOUNT_OF_PROCESSED_CHARS = [${AMOUNT_OF_PROCESSED_CHARS}]"
      fi      
      case "${C}" in
         [[:space:]]) 
            TOKEN="${_EMPTY_TOKEN_}"
            AMOUNT_OF_PROCESSED_CHARS=1
         ;;
         "${_PARAN_OPEN_}"|"${_PARAN_CLOSE_}"|"${_CURLY_OPEN_}"|"${_CURLY_CLOSE_}"|"${_COMMA_}"|"${_SEMICOLON_}"|"${_EQUAL_SIGN_}"|"${_COLON_}")
            TOKEN="('${C}', '${_NO_VALUE_}')" # special character are thier own type, but without a value
            AMOUNT_OF_PROCESSED_CHARS=1
         ;;
         "${_PLUS_SIGN_}"|"${_MINUS_SIGN_}"|"\${_MUL_}"|"${_DIV_}")
            TOKEN="('${_OPERATION_TOKEN_}', '${C}')"
            AMOUNT_OF_PROCESSED_CHARS=1
         ;;
         "${_QUOTE_}"|"${_DOUBLE_QUOTE_}")
            pattern="([\ a-zA-Z0-9.:,;%?=&$§^#_\(\)\{\})\[\]]){0,}"
            string_plus_quotes="$(grep -o -P "[${C}]${pattern}[${C}]" <<< ${BUFF})"
            if [[ ${string_plus_quotes: -1} != ${C} ]]; then stop 'A string ran off the end of the program.' '77' ; fi
            string=${string_plus_quotes:1:-1}
            TOKEN="('${_STRING_TOKEN_}', '${string}')"
            AMOUNT_OF_PROCESSED_CHARS="${#string_plus_quotes}"
         ;;
         [[:digit:]]|".")
            sloppy="[-+0-9.]*"
            pattern="(^([[:digit:]])*([.][[:digit:]]){,1}([[:digit:]])*)"
            number=$(grep -Eo "${pattern}" <<< ${BUFF})
            if [[ ${number} == '' ]]; then stop "'$(grep -Eo "${sloppy}" <<< ${BUFF})' is not a number" '1' ; fi
            TOKEN="('${_NUMBER_TOKEN_}', '${number}')"
            AMOUNT_OF_PROCESSED_CHARS="${#number}"
         ;;
         [[:alpha:]])
            symbol=$(grep -o -E "^(([[:alpha:]]+)([[:alnum:][_])*)" <<< ${BUFF})
            TOKEN="('${_SYMBOL_TOKEN_}', '${symbol}')"
            AMOUNT_OF_PROCESSED_CHARS="${#symbol}"
         ;;
         "${_TAB_}")
            stop "Tabs are not allowed in Cell" '1'
            ;;
         *)
            stop "Unexpected character: >>${C}<<" '1'
         ;;
      esac
   done
}
################################################################################
### end of function lex ########################################################
################################################################################

if [[ ${ARG_BUFFER} ]]; then
   declare buff_line="$(tr -d '\n\r\t' <<< ${ARG_BUFFER})" 
   declare buff_line_token="('ARG_BUFFER', '${buff_line}')"
   lex "${buff_line}" "${buff_line_token}"
fi

amount_of_lines=${#source_code[*]}
for (( line_no=0; line_no<$(( $amount_of_lines )); line_no++ )); do
   declare one_line="${source_code[line_no]}${_SEMICOLON_}" # the semicolon was stipprd while reading INFILE into the array
   declare extra_line_token="('LINE_${line_no}', '${one_line}')" 
   lex "${one_line}" "${extra_line_token}"
done