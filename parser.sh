#!/bin/bash
exec 3>&1 1>&2
set -o errexit
set -o nounset

declare -r _EMPTY_TOKEN_=''
declare -r _NONE_=''
declare -r _SYMBOL_TOKEN_='symbol'
declare -r _STRING_TOKEN_='string'
declare -r _NUMBER_TOKEN_='number'
declare -r _OPERATION_TOKEN_='operation'
declare -r _NO_VALUE_=''
declare -r _CLEAR_=''
declare -r _SPACE_=' '
declare -r _SPACE_CLASS_='[[:space:]]'
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
declare -r _ESC_TAB_='\t'
declare -r _TAB_='	'
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
IFS=$'\n'
set +o errexit # don't stop on 'newlines'
read -d '\n' -a source_code < "${from_source_file}" # -d '' works like a charm, but with exit code (1)?!
set -o errexit
IFS="$ORIG_IFS"
if [[ ${OPT_VERBOSE} ]]; then echo '---';for element in "${source_code[@]}" ; do echo "$element" ; done ; echo '---'; fi

declare PREV_TYPE=${_NONE_}

################################################################################
### start of function parse ####################################################
################################################################################

function parse () {
   declare -r parse_buff="${1}"
   declare -r parse_token="${2}"
   declare -r prev_type="${3}"
   declare -i parse_amount_of_token="${line_no}"
   while [[ true ]]; do
      declare parse_stripped_buff="${parse_buff:1:-2}"
      parse_stripped_buff=${parse_stripped_buff/${_COMMA_}${_SPACE_}/${_TAB_}} #OK
      if [[ ! -z ${parse_token} ]]; then echo "${parse_token} " >&3 ; fi
      if [[ ${OPT_VERBOSE} ]]; then
         echo "--- line #[${parse_amount_of_token}]"
         echo "parse_buff          = »${parse_buff}« [${#parse_buff}]"
         echo "parse_stripped_buff =  »${parse_stripped_buff/${_TAB_}/${_ESC_TAB_}}«  [${#parse_stripped_buff}]"
      fi
      ORIG_IFS="${IFS}"
      IFS=$'\t'
      set +o errexit # don't stop on 'newlines'
         read -d '' -a parse_a_token <<< "${parse_stripped_buff}" # -d '' works like a charm, but with exit code (1)?!
      set -o errexit
      IFS="${ORIG_IFS}"
      declare parse_token_type="${parse_a_token[0]:1:-1}"
      declare parse_token_value="${parse_a_token[1]:1:-1}" 
      if [[ ${OPT_VERBOSE} ]]; then 
         echo "prev_type  = »${prev_type}«" 
         echo "type       = »${parse_token_type}«" 
         echo "value      = »${parse_token_value}«" 
      fi

      case "${parse_token_type}" in
         ${_SEMICOLON_})
            return
         ;;
         ${_EQUAL_SIGN_})
            if [[ ${_SYMBOL_TOKEN_} == ${prev_type} ]]; then
               echo "(\"assignment\"," >&3
               echo "   ${source_code[line_no-1]}," >&3
               echo ")" >&3
               return
               echo "   ${source_code[line_no+1]}," >&3
               echo "   ${source_code[line_no+2]}" >&3
            fi
         ;;
         ${_OPERATION_TOKEN_})
            #echo "${source_code[line_no+0]}" >&3
         ;;
         ${_SYMBOL_TOKEN_}|${_STRING_TOKEN_}|${_NUMBER_TOKEN_})
            #echo "${source_code[line_no+0]}" >&3
         ;;
         ${_PARAN_OPEN_}|${_PARAN_CLOSE_})
            #echo "${source_code[line_no+0]}" >&3
         ;;
         ${_CURLY_OPEN_}|${_CURLY_CLOSE_})
            #echo "${source_code[line_no+0]}" >&3
         ;;
         ${_COMMA_})
            #echo "${source_code[line_no+0]}" >&3
         ;;
         *) stop "unkowm token type »${parse_token_type}« found in line #${line_no} parsing »${parse_buff}« [${#parse_buff}]" '1' ;;
      esac

      parse_stripped_buff="${_CLEAR_}";
      #############################
      [[ 0 -lt ${#parse_stripped_buff} ]] || PREV_TYPE="${parse_token_type}"; break
      #############################      
   done
}

################################################################################
### end of function parse ######################################################
################################################################################

if [[ ${ARG_BUFFER} ]]; then
   declare buff_line="$(tr -d '\n\r\t' <<< ${ARG_BUFFER})" 
   declare buff_line_token="('ARG_BUFFER', '${buff_line}')"
   parse "${buff_line}" "${_EMPTY_TOKEN_}" "${PREV_TYPE}"
fi

amount_of_lines=${#source_code[*]}
for (( line_no=0; line_no<$(( $amount_of_lines )); line_no++ )); do
   declare one_line="${source_code[line_no]}"
   parse "${one_line:0:-1}" "${_EMPTY_TOKEN_}" "${PREV_TYPE}"
done