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
   declare buff="${1}"
   declare token="${2}"
   declare c
   declare -i amount_of_processed_chars=0
   while [[ true ]]; do
      buff=${buff:${amount_of_processed_chars}:${#buff}}
      c="${buff:0:1}"
      if [[ ! -z ${token} ]]; then echo "${token} " >&3 ; fi
      #############################
      [[ 0 -lt ${#buff} ]] || break
      #############################      
      if [[ ${OPT_DEBUG} ]]; then
         echo "token = »${token}«"
         echo "c = »${c}«"              
         echo "buff = »${buff}« [${#buff}]"
         echo "amount_of_processed_chars = [${amount_of_processed_chars}]"
      fi      
      case "${c}" in
         [[:space:]]) 
            token="${_EMPTY_TOKEN_}"
            amount_of_processed_chars=1
         ;;
         "${_PARAN_OPEN_}"|"${_PARAN_CLOSE_}"|"${_CURLY_OPEN_}"|"${_CURLY_CLOSE_}"|"${_COMMA_}"|"${_SEMICOLON_}"|"${_EQUAL_SIGN_}"|"${_COLON_}")
            token="('${c}', '${_NO_VALUE_}')" # special character are thier own type, but without a value
            amount_of_processed_chars=1
         ;;
         "${_PLUS_SIGN_}"|"${_MINUS_SIGN_}"|"\${_MUL_}"|"${_DIV_}")
            token="('${_OPERATION_TOKEN_}', '${c}')"
            amount_of_processed_chars=1
         ;;
         "${_QUOTE_}"|"${_DOUBLE_QUOTE_}")
            pattern="([\ a-zA-Z0-9.:,;%?=&$§^#_\(\)\{\})\[\]]){0,}"
            string_plus_quotes="$(grep -o -P "[${c}]${pattern}[${c}]" <<< ${buff})"
            if [[ ${string_plus_quotes: -1} != ${c} ]]; then stop 'A string ran off the end of the program.' '77' ; fi
            string=${string_plus_quotes:1:-1}
            token="('${_STRING_TOKEN_}', '${string}')"
            amount_of_processed_chars="${#string_plus_quotes}"
         ;;
         [[:digit:]]|".")
            sloppy="[-+0-9.]*"
            pattern="(^([[:digit:]])*([.][[:digit:]]){,1}([[:digit:]])*)"
            number=$(grep -Eo "${pattern}" <<< ${buff})
            if [[ ${number} == '' ]]; then stop "'$(grep -Eo "${sloppy}" <<< ${buff})' is not a number" '1' ; fi
            token="('${_NUMBER_TOKEN_}', '${number}')"
            amount_of_processed_chars="${#number}"
         ;;
         [[:alpha:]])
            symbol=$(grep -o -E "^(([[:alpha:]]+)([[:alnum:][_])*)" <<< ${buff})
            token="('${_SYMBOL_TOKEN_}', '${symbol}')"
            amount_of_processed_chars="${#symbol}"
         ;;
         "${_TAB_}")
            stop "Tabs are not allowed in Cell" '1'
            ;;
         *)
            stop "Unexpected character: >>${c}<<" '1'
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