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
declare -r _DOT_='.'
declare -r _COMMA_=','
declare -r _PARAN_OPEN_='('
declare -r _PARAN_CLOSE_=')'
declare -r _QUOTE_="'"
declare -r _DOUBLE_QUOTE_='"'
declare -r _CURLY_OPEN_='{'
declare -r _CURLY_CLOSE_='}'
declare -r _MUL_='*'
declare -r _DIV_='/'
declare -r _TAB_='\t'
declare -r _PATTERN_NUMBER_STARTS_WITH_DIGIT_='(^([[:digit:]])*([.][[:digit:]]){,1}([[:digit:]])*)'
declare -r _PATTERN_NUMBER_STARTS_WITH_DOT_='[0-9]+'
declare -r _PATTERN_NUMBER_SLOPPY_='[-+0-9.]*'
declare -r _PATTERN_ALPHA_='^(([[:alpha:]]+)([[:alnum:][_])*)'

stop() {
   declare -r message=${1:-"OK (/)"}
   declare -r -i exit_code=${2:-0}
   if [[ ${exit_code} -gt 0 ]] || [[ ${OPT_VERBOSE} ]]; then 
      printf '%s (%i)\n' "${message}" "${exit_code}"
   fi
   exit "${exit_code}"
}

usage()
{
  echo "Usage: ${0} [ -g | --debug ] 
                        [ -b | --buffer a string]
                        [ -c | --char a singe char ] 
                        [filename]"
}

PARSED_ARGUMENTS=$(getopt -a -n ${0} -o g,v,b:c: --long debug,verbose,buffer:,char: -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

declare OPT_DEBUG=
declare OPT_VERBOSE=
declare ARG_BUFFER=
declare ARG_CHAR=
declare INFLILE=/dev/null

eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    -g | --debug)      declare -r -i OPT_DEBUG=1   ; shift   ;;
    -v | --verbose)    declare -r -i OPT_VERBOSE=1 ; shift   ;;
    -b | --buffer)     declare -r ARG_BUFFER="$2"  ; shift 2 ;;
    -c | --char)       declare -r ARG_CHAR="$2"    ; shift 2 ;;
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

if [[ ${OPT_VERBOSE} ]]; then 
   echo "PARSED_ARGUMENTS is '$PARSED_ARGUMENTS'"
   echo "OPT_DEBUG      : '${OPT_DEBUG}'"
   echo "OPT_VERBOSE    : '${OPT_VERBOSE}'"
   echo "ARG_BUFFER     : '${ARG_BUFFER}'"
   echo "ARG_CHAR       : '${ARG_CHAR}'"
   echo "INFILE         : '${INFLILE}' (alias filename)"
   echo "Parameters remaining are: '${@}'"
fi
if [[ ${OPT_DEBUG} ]]; then set -x ; fi
if [[ ! -r ${INFLILE} ]]; then stop "filename '${INFLILE}' is not readable or does not exist" '22' ; fi
declare -r from_source_file=${INFLILE}; 
 
ORIG_IFS="$IFS"
IFS=$';\n'
set +o errexit # -d '' works like a charm, but with exit code (1)?!
read -d '' -a source_code < "${from_source_file}" # don't stop on 'pipes', 'newlines' and 'semicolons' 
set -o errexit
IFS="$ORIG_IFS"
if [[ ${OPT_VERBOSE} ]]; then echo '---';for element in "${source_code[@]}" ; do echo "$element" ; done ; echo '---'; fi

################################################################################
### start of function lex ######################################################
################################################################################
function lex () {
   declare lex_buff="${1}"
   declare lex_token="${2}"
   declare lex_char
   declare -i lex_amount_of_processed_chars=0
   while [[ true ]]; do
      lex_buff=${lex_buff:${lex_amount_of_processed_chars}}
      lex_char="${lex_buff:0:1}"
      if [[ ! -z ${lex_token} ]]; then echo "${lex_token} " >&3 ; fi
      #############################
      [[ 0 -lt ${#lex_buff} ]] || break
      #############################      
      if [[ ${OPT_VERBOSE} ]]; then
         echo "lex_token = »${lex_token}« [${lex_amount_of_processed_chars}]"
         echo "lex_char = »${lex_char}«"              
         echo "lex_buff = »${lex_buff}« [${#lex_buff}]"
      fi      
      case "${lex_char}" in
         [[:space:]]) 
            lex_token="${_EMPTY_TOKEN_}"
            lex_amount_of_processed_chars=1
         ;;
         "${_PARAN_OPEN_}"|"${_PARAN_CLOSE_}"|"${_CURLY_OPEN_}"|"${_CURLY_CLOSE_}"|"${_COMMA_}"|"${_SEMICOLON_}"|"${_EQUAL_SIGN_}"|"${_COLON_}")
            lex_token="('${lex_char}', '${_NO_VALUE_}')" # special character are thier own type, but without a value
            lex_amount_of_processed_chars=1
         ;;
         "${_PLUS_SIGN_}"|"${_DIV_}"|"\${_MUL_}")
            lex_token="('${_OPERATION_TOKEN_}', '${lex_char}')"
            lex_amount_of_processed_chars=1
         ;;
         "${_MINUS_SIGN_}")
            lex_token="('${_OPERATION_TOKEN_}', '${lex_char}')"
            lex_amount_of_processed_chars=1
         ;;
         [[:digit:]])
            declare -r number=$(grep -Eo "${_PATTERN_NUMBER_STARTS_WITH_DIGIT_}" <<< ${lex_buff})
            if [[ ${number} == '' ]]; then stop "'$(grep -Eo "${_PATTERN_NUMBER_SLOPPY_}" <<< ${lex_buff})' is not a number" '1' ; fi
            lex_token="('${_NUMBER_TOKEN_}', '${number}')"
            lex_amount_of_processed_chars="${#number}"
         ;;
         "${_DOT_}")
            declare -r number=$(grep -Eo "${_PATTERN_NUMBER_STARTS_WITH_DOT_}" <<< ${lex_buff:1})
            if [[ ${number} == '' ]]; then stop "'$(grep -Eo "${_PATTERN_NUMBER_SLOPPY_}" <<< ${lex_buff})' is not a number" '1' ; fi
            lex_token="('${_NUMBER_TOKEN_}', '${_DOT_}${number}')"
            lex_amount_of_processed_chars="${#number}+1"
         ;;
         "${_QUOTE_}"|"${_DOUBLE_QUOTE_}")
            declare lex_uff=${lex_buff:1} # remove first (double) quote
            declare lex_string="${lex_uff%${lex_char}*}" # match text before next (double) quote
            declare -i lex_stringlen_=${#lex_string} # determin length of match to verify there is a (double) quote at the end
            if [[ ${lex_uff:${lex_stringlen_}:1} != ${lex_char} ]]; then stop 'A lex_string ran off the end of the program.' '77' ; fi
            lex_token="('${_STRING_TOKEN_}', '${lex_string}')"
            lex_amount_of_processed_chars="${lex_stringlen_}+2"
         ;;
         [[:alpha:]])
            declare lex_symbol=$(grep -o -E "${_PATTERN_ALPHA_}" <<< ${lex_buff})
            lex_token="('${_SYMBOL_TOKEN_}', '${lex_symbol}')"
            lex_amount_of_processed_chars="${#lex_symbol}"
         ;;
         "${_TAB_}")
            stop "Tabs are not allowed in Cell" '1';;
         *)
            stop "Unexpected character: >>${lex_char}<<" '1';;
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