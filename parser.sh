#!/bin/bash
exec 3>&1 1>&2
set -o errexit
set -o nounset

# _VAIABLES_ with underscores are supposed to be R/O alias static,
# never the less, the _OPT_NAME_ and _ARG_NAME_ vars are declared twice
# they are initialized neutal/empty to run this script with 'nounset' option.
# They'll become R/O even if they are not set again during getopt  
declare _AMOUNT_OF_UNRECOGNIZED_PARAMETER_=
declare _OPT_DEBUG_LEVEL_=
declare -i OPT_VERBOSETY_LEVEL=0 # will be risen during getopt -v -vv -vvv
declare _ARG_BUFFER_=
declare _ARG_CHAR_=
declare ARG_INFLILE= # the_TOKEN_ array gets always initialised

# CONST
declare -r _ARG_THIS_="${0}"
declare -r -i _VERBOSETY_LEVEL_LOW_=0
declare -r -i _VERBOSETY_LEVEL_HIGH_=1
declare -r -i _VERBOSETY_LEVEL_ULTRA_=2
declare -r _EMPTY_TOKEN_=''
declare -r -i _TOKEN_TYPE_=0
declare -r -i _TOKEN_VALUE_=1
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

function usage()
{
  echo "Usage: ${_ARG_THIS_} [ -g | --debug ] [ -h | --help ] [-v | -vv | -vvv] verbose
                        [ -b | --buffer a string]
                        [ -c | --char a singe char ] 
                        [filename]"
}

function stop() {
   declare -r stop_message=${1:-"OK (/)"}
   declare -r -i stop_exit_code=${2:-0}
   if [[ ${stop_exit_code} -gt 0 ]] || [[$((${_VERBOSETY_LEVEL_LOW_} -lt ${OPT_VERBOSETY_LEVEL})) ]];  then 
      printf '%s (%i)\n' "${stop_message}" "${stop_exit_code}"
   fi
   exit "${stop_exit_code}"
}

################################################################################
### getopt start ###############################################################
################################################################################

set +o errexit
_PARSED_ARGUMENTS_=$(getopt -a -n ${_ARG_THIS_} -o h,g,v,b:c: --long help,debug,buffer:,char: -- "$@")
declare -r -i _AMOUNT_OF_UNRECOGNIZED_OPTIONS_="${?}"
set -o errexit
if [ "$_AMOUNT_OF_UNRECOGNIZED_OPTIONS_" -gt '0' ]; then
   usage
   stop "Illegal Argument" '22'
fi
eval set -- "${_PARSED_ARGUMENTS_}"

while :
do
case "$1" in
   -h | --help)   usage                                 ; exit 0  ;;
   -g | --debug)  declare -r -i _OPT_DEBUG_LEVEL_=1     ; shift   ;;
   -v)                           OPT_VERBOSETY_LEVEL+=1 ; shift   ;;
   -b | --buffer) declare -r    _ARG_BUFFER_="$2"       ; shift 2 ;;
   -c | --char)   declare -r    _ARG_CHAR_="$2"         ; shift 2 ;;
   # -- means the end of the arguments; drop this, and break out of the while loop
   --) shift; 
      set +o nounset
      declare -r ARG_INFLILE="${1:-/dev/null}" # the remaining parameter is supposed to be the filname
      set -o nounset
      if [[ ! -z ${@} ]]; then shift ; fi # shift only if there was a last parameter
      if [[ ! -r ${ARG_INFLILE} ]]; then stop "filename '${ARG_INFLILE}' is not readable or does not exist" '22' ; fi
      break 
   ;;
   # If invalid options were passed, then getopt should have reported an error,
   # which we checked as _AMOUNT_OF_UNRECOGNIZED_OPTIONS_ when getopt was called...
   *) echo "Famous Last Words - Unexpected option: $1 - this should not happen."
      usage 
      stop "Unkown Parameter or option found" '22'
   ;;
esac
done

if [[ ${_VERBOSETY_LEVEL_LOW_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then 
   echo "_PARSED_ARGUMENTS_ is     '$_PARSED_ARGUMENTS_'"
   echo "_OPT_DEBUG_LEVEL_       : '${_OPT_DEBUG_LEVEL_}'"
   echo "OPT_VERBOSETY_LEVEL     : '${OPT_VERBOSETY_LEVEL}'"
   echo "_ARG_BUFFER_            : '${_ARG_BUFFER_}'"
   echo "_ARG_CHAR_              : '${_ARG_CHAR_}'"
   echo "INFILE                  : '${ARG_INFLILE}' (alias filename)"
   echo "Parameters remaining are: '${@}'"
fi
if [[ ${_OPT_DEBUG_LEVEL_} ]]; then set -x ; fi

###^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^###
### getopt done ################################################################
################################################################################

function read_token () {
   ORIG_IFS="$IFS"
   IFS=$'\n' # don't stop on 'newlines'
   set +o errexit 
   read -d "" -r -a PRE_LOAD_TOKEN<"${1}" # -d '' works like a charm, but with exit code (1)?!
   set -o errexit
   IFS="$ORIG_IFS"
   if [[ ${_VERBOSETY_LEVEL_HIGH_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then echo '---';for element in "${PRE_LOAD_TOKEN[@]}" ; do echo "$element" ; done ; echo '---'; fi
}

   declare -A TOKEN_TYPES
   declare -A TOKEN_VALUES
   declare -a TOKEN

function unwrap_token () {
   declare -r -i unwrap_token_amount_of_token=${#PRE_LOAD_TOKEN[*]}
   for (( unwrap_token_no=0; 
          unwrap_token_no < $(( $unwrap_token_amount_of_token )); 
          unwrap_token_no++ )); do
      declare unwrap_token_buff=${PRE_LOAD_TOKEN[unwrap_token_no]:0:-1}
      TOKEN[unwrap_token_no]="${unwrap_token_buff}"
      declare unwrap_token_stripped_buff="${unwrap_token_buff:1:-1}"
      declare unwrap_token_tab_buff=${unwrap_token_stripped_buff/${_COMMA_}${_SPACE_}/${_TAB_}} #OK
      if [[ ${_VERBOSETY_LEVEL_ULTRA_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then
         echo "--- token #[${unwrap_token_no}]"
         echo "unwrap_token_buff          = »${unwrap_token_buff}« [${#unwrap_token_buff}]"
         echo "unwrap_token_stripped_buff =  »${unwrap_token_stripped_buff}« [${#unwrap_token_stripped_buff}]"
         echo "unwrap_token_tab_buff      =  »${unwrap_token_tab_buff/${_TAB_}/${_ESC_TAB_}}«  [${#unwrap_token_tab_buff}]"
      fi
      ORIG_IFS="${IFS}"
      IFS=$'\t'
      set +o errexit # don't stop on 'newlines'
         read -d '' -a unwrap_token_type_value_pair <<< "${unwrap_token_tab_buff}" # -d '' works like a charm, but with exit code (1)?!
      set -o errexit
      IFS="${ORIG_IFS}"
      declare unwrap_token_type="${unwrap_token_type_value_pair[${_TOKEN_TYPE_}]:1:-1}"   # unquote
      declare unwrap_token_value="${unwrap_token_type_value_pair[${_TOKEN_VALUE_}]:1:-1}" # unquote
      if [[ ${_VERBOSETY_LEVEL_HIGH_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then
         echo "unwrap_token_type          = »${unwrap_token_type}«" 
         echo "unwrap_token_value         = »${unwrap_token_value}«" 
      fi
      TOKEN_TYPES["${unwrap_token_buff}"]="${unwrap_token_type}"
      TOKEN_VALUES["${unwrap_token_buff}"]="${unwrap_token_value}"
   done
   if [[ ${_VERBOSETY_LEVEL_ULTRA_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then
      echo "TOKEN_TYPES"
      for key in "${!TOKEN_TYPES[@]}"; do
         echo -n "type: »${TOKEN_TYPES[$key]}«"
         echo "${_TAB_}token  : »$key«"
      done
      echo "TOKEN_VALUES"
      for key in "${!TOKEN_VALUES[@]}"; do
         echo "token  : »$key«"
         echo "value: »${TOKEN_VALUES[$key]}«"
      done
   fi
}

function next_expression () {
   declare -r next_expression_curr_token_no="${1}"
   declare -r next_expression_curr_token_type="${2}"
   declare -r next_expression_prev_token_type="${3}"
}

################################################################################
### start of function parse ####################################################
################################################################################
function parse () {
   declare -i parse_curr_token_no=${1}
   declare -r parse_prev_token_type="${2}"
   while [[ true ]]; do
      declare parse_buff=${TOKEN[parse_curr_token_no]}
      declare parse_token_type="${TOKEN_TYPES[${parse_buff}]}"
      declare parse_token_value="${TOKEN_VALUES[${parse_buff}]}" 
      if [[ ${_VERBOSETY_LEVEL_HIGH_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then
         echo "parse_prev_token_type = »${parse_prev_token_type}«" 
         echo "type                  = »${parse_token_type}«" 
         echo "value                 = »${parse_token_value}«" 
      fi

      case "${parse_token_type}" in
         ${_SEMICOLON_})
            return
         ;;
         ${_EQUAL_SIGN_})
            if [[ ${_SYMBOL_TOKEN_} == ${parse_prev_token_type} ]]; then
               echo "(\"assignment\"," >&3
               echo "   ${TOKEN[parse_curr_token_no-1]}," >&3
               echo ")" >&3
               return
               echo "   ${TOKEN[parse_curr_token_no+1]}," >&3
               echo "   ${TOKEN[parse_curr_token_no+2]}" >&3
            fi
         ;;
         ${_OPERATION_TOKEN_})
            echo "${TOKEN[parse_curr_token_no+0]}" >&3
         ;;
         ${_SYMBOL_TOKEN_}|${_STRING_TOKEN_}|${_NUMBER_TOKEN_})
            echo "${TOKEN[parse_curr_token_no+0]}" >&3
         ;;
         ${_PARAN_OPEN_}|${_PARAN_CLOSE_})
            echo "${TOKEN[parse_curr_token_no+0]}" >&3
         ;;
         ${_CURLY_OPEN_}|${_CURLY_CLOSE_})
            echo "${TOKEN[parse_curr_token_no+0]}" >&3
         ;;
         ${_COMMA_})
            echo "${TOKEN[parse_curr_token_no+0]}" >&3
         ;;
         *) stop "unkowm token type »${parse_token_type}« found in line #${parse_curr_token_no} parsing »${parse_buff}« [${#parse_buff}]" '1' ;;
      esac

      parse_stripped_buff="${_CLEAR_}";
      #############################
      [[ 0 -lt ${#parse_stripped_buff} ]] || main_prev_token_type="${parse_token_type}"; break
      #############################      
   done
}

### if [[ ${_ARG_BUFFER_} ]]; then
###    declare buff_line="$(tr -d '\n\r\t' <<< ${_ARG_BUFFER_})" 
###    declare buff_line_token="('_ARG_BUFFER_', '${buff_line}')"
###    parse "${buff_line}" "${_EMPTY_TOKEN_}" "${main_prev_token_type}"
### fi

function main () {
   read_token "${ARG_INFLILE}"
   unwrap_token
   declare local main_prev_token_type=${_NONE_}
   declare -r -i main_amount_of_token=${#TOKEN[*]}
   for (( main_curr_token_no=0; 
          main_curr_token_no < $(( $main_amount_of_token )); 
          main_curr_token_no++ )); do
      #           self                       prev                 stop_at
      parse  "${main_curr_token_no}" "${main_prev_token_type}" ""
      if [[ ${_VERBOSETY_LEVEL_ULTRA_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then echo "main_prev_token_type  = »${main_prev_token_type}«"; fi
   done
   return 0
}
main
 