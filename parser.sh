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
declare -r -i _TOKEN_NO_NONE_=-1
declare -r -i _TOKEN_TYPE_=0
declare -r -i _TOKEN_VALUE_=1
declare -r _TOKEN_TYPE_NONE_=''
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

declare -a TOKEN
declare -A MAP_TO_TYPE
declare -A MAP_TO_VALUE
declare -i AMOUNT_OF_TOKEN_TO_PARSE=0
declare -i PARSED_TOKEN=0

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


function unwrap_token () {
   declare -r -i unwrap_token_amount_of_token=${#PRE_LOAD_TOKEN[*]}
   AMOUNT_OF_TOKEN_TO_PARSE=unwrap_token_amount_of_token
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
         read -d '\t' -a unwrap_token_type_value_pair <<< "${unwrap_token_tab_buff}" # -d '' works like a charm, but with exit code (1)?!
      set -o errexit
      IFS="${ORIG_IFS}"
      declare unwrap_token_type="${unwrap_token_type_value_pair[${_TOKEN_TYPE_}]:1:-1}"   # unquote
      declare unwrap_token_value="${unwrap_token_type_value_pair[${_TOKEN_VALUE_}]:1:-2}" # unquote un[[:space:]]
      if [[ ${_VERBOSETY_LEVEL_HIGH_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then
         echo "unwrap_token_type          = »${unwrap_token_type}«" 
         echo "unwrap_token_value         = »${unwrap_token_value}«" 
      fi
      MAP_TO_TYPE["${unwrap_token_buff}"]="${unwrap_token_type}"
      MAP_TO_VALUE["${unwrap_token_buff}"]="${unwrap_token_value}"
   done
   if [[ ${_VERBOSETY_LEVEL_ULTRA_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then
      echo "TOKEN"
      for key in "${!TOKEN[@]}"; do
         echo -n "key:${_TAB_}[${key}]${_TAB_}"
         echo    "value: »${TOKEN[$key]}«"
      done
      echo "MAP_TO_TYPE"
      for key in "${!MAP_TO_TYPE[@]}"; do
         echo "token  : »$key«"
         echo "     type: »${MAP_TO_TYPE[$key]}«"
      done
      echo "MAP_TO_VALUE"
      for key in "${!MAP_TO_VALUE[@]}"; do
         echo "token  : »$key«"
         echo "              value: »${MAP_TO_VALUE[$key]}«"
      done
   fi
}

function next_expression () {
   declare -r -i next_expression_curr_token_no="${1}"
   declare -r -i next_expression_prev_token_no="${2}"
   declare -r next_expression_stop_at_type="${3}"
   declare -r next_expression_curr_token=${TOKEN[${next_expression_curr_token_no}]}
   declare -r next_expression_curr_token_type=${MAP_TO_TYPE[${next_expression_curr_token}]}
   declare -r next_expression_prev_token=${TOKEN[${next_expression_prev_token_no}]}
   declare -r next_expression_prev_token_type=${MAP_TO_TYPE[${next_expression_prev_token}]}
   if [[ ${_TOKEN_NO_NONE_} -eq next_expression_prev_token_no ]]; then
      case "${next_expression_curr_token_type}" in
         ${_SYMBOL_TOKEN_}|${_STRING_TOKEN_}|${_NUMBER_TOKEN_})
            echo ${next_expression_curr_token} >&3
         ;;
         *) stop "unexpected token '${next_expression_curr_token}'" 1 ;;
      esac
   fi


   return 
}

################################################################################
### start of function parse ####################################################
################################################################################
function parse () {
   parse_stop_at_token=${1}
   while [[ true ]]; do
      declare parse_token=${TOKEN[${PARSED_TOKEN}]}
      declare parse_token_type=${MAP_TO_TYPE[${parse_token}]}
      #declare parse_token_value=${MAP_TO_VALUE[${parse_token}]}
      if [[ ${_VERBOSETY_LEVEL_HIGH_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then
         echo "PARSED_TOKEN             = [${PARSED_TOKEN}]" 
         echo "AMOUNT_OF_TOKEN_TO_PARSE = [${AMOUNT_OF_TOKEN_TO_PARSE}]" 
         echo "parse_stop_at_token      = »${parse_stop_at_token}«" 
         echo "parse_token              = »${parse_token}«"
         echo "parse_token_type         = »${parse_token_type}«"
      fi

      if [[ ${parse_stop_at_token} ==  ${parse_token_type} ]]; then
         declare -i parse_prev_token_no=(${PARSED_TOKEN}-1)
         declare    parse_prev_token=${TOKEN[${parse_prev_token_no}]}
         echo ${parse_prev_token} >&3
         return
      fi
      #############################
      [[ ${PARSED_TOKEN} -lt ${AMOUNT_OF_TOKEN_TO_PARSE} ]] || break
      #############################      
      let PARSED_TOKEN=${PARSED_TOKEN}+1

      #declare -i parse_curr_token_no=${AMOUNT_OF_TOKEN_TO_PARSE}
      #next_expression "${AMOUNT_OF_TOKEN_TO_PARSE}" "${_TOKEN_NO_NONE_}"


      #############################
      [[ ${PARSED_TOKEN} -lt ${AMOUNT_OF_TOKEN_TO_PARSE} ]] || break
      #############################      

      case "" in
         ${_SEMICOLON_}) 

         ;;
         ${_EQUAL_SIGN_})

         ;;
         ${_OPERATION_TOKEN_})

         ;;
         ${_SYMBOL_TOKEN_}|${_STRING_TOKEN_}|${_NUMBER_TOKEN_})
            
         ;;
         ${_PARAN_OPEN_}|${_PARAN_CLOSE_})

         ;;
         ${_CURLY_OPEN_}|${_CURLY_CLOSE_})

         ;;
         ${_COMMA_})

         ;;
         #*) stop "UPS" '1' ;;
      esac

   done
}

function main () {
   read_token "${ARG_INFLILE}"
   unwrap_token
   #         stop_at
   parse ${_SEMICOLON_} 
   return 0
}

main
 