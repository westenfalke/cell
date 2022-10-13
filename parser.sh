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
IFS=$'\n|'
set +o errexit # -d '' works like a charm, but with exit code (1)?!
read -d '\n' -a source_code < "${from_source_file}" # don't stop on 'pipes', 'newlines' and 'semicolons' 
set -o errexit
IFS="$ORIG_IFS"
if [[ ${OPT_VERBOSE} ]]; then echo '---';for element in "${source_code[@]}" ; do echo "$element" ; done ; echo '---'; fi


################################################################################
### start of function parse ####################################################
################################################################################

function parse () {
    echo "$@"  >&3
}

################################################################################
### end of function parse ######################################################
################################################################################

if [[ ${ARG_BUFFER} ]]; then
   declare buff_line="$(tr -d '\n\r\t' <<< ${ARG_BUFFER})" 
   declare buff_line_token="('ARG_BUFFER', '${buff_line}')"
   parse "${buff_line}" "${buff_line_token}"
fi

amount_of_lines=${#source_code[*]}
for (( line_no=0; line_no<$(( $amount_of_lines )); line_no++ )); do
   declare one_line="${source_code[line_no]}${_SEMICOLON_}" # the semicolon was stipprd while reading INFILE into the array
   declare extra_line_token="('LINE_${line_no}', '${one_line}')" 
   parse "${one_line}" "${extra_line_token}"
done