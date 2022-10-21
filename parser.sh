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
declare -r -i _TOKEN_NO_NONE_=-1
declare -r -i _TOKEN_TYPE_=0
declare -r -i _TOKEN_VALUE_=1
declare -r _EMPTY_TOKEN_=''
declare -r _NO_VALUE_=''
declare -r _CLEAR_=''
declare -r _TOKEN_TYPE_NONE_=''
declare -r _SYMBOL_TOKEN_='symbol'
declare -r _STRING_TOKEN_='string'
declare -r _NUMBER_TOKEN_='number'
declare -r _OPERATION_TOKEN_='operation'
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

declare -A MAP_TO_TYPE
declare -A MAP_TO_VALUE
declare -a TOKEN_AT

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
# int read_token ( void ) 
function read_token () {
   ORIG_IFS="$IFS"
   IFS=
   while read -r obj_line || [[ -n "${obj_line}" ]]; do
      TOKEN_AT+=("${obj_line:0:-1}")
   done < ${ARG_INFLILE}
   IFS="$ORIG_IFS"
   if [[ ${_VERBOSETY_LEVEL_HIGH_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then echo '---';for element in "${TOKEN_AT[@]}" ; do echo "$element" ; done ; echo '---'; fi
}


# int unwrap_token ( void ) 
# <)/   PRE_LOAD_TOKEN[*]
# <)/(> TOKEN_AT
# <)/(> MAP_TO_TYPE
# <)/(> MAP_TO_VALUE
function unwrap_token () {
   for token in "${TOKEN_AT[@]}" ; do
      declare unwrap_token_stripped_buff="${token:1:-1}"
      declare unwrap_token_tab_buff=${unwrap_token_stripped_buff/${_COMMA_}${_SPACE_}/${_TAB_}} #OK
      if [[ ${_VERBOSETY_LEVEL_ULTRA_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then
         echo "--- token"
         echo "token                      = »${token}« [${#token}]"
         echo "unwrap_token_stripped_buff =  »${unwrap_token_stripped_buff}« [${#unwrap_token_stripped_buff}]"
         echo "unwrap_token_tab_buff      =  »${unwrap_token_tab_buff/${_TAB_}/${_ESC_TAB_}}«  [${#unwrap_token_tab_buff}]"
      fi
      declare unwrap_token_quoted_type
      declare unwrap_token_quoted_value
      ORIG_IFS="${IFS}"
      IFS=$'\t'
      read -r unwrap_token_quoted_type unwrap_token_quoted_value <<< "${unwrap_token_tab_buff}"
      IFS="${ORIG_IFS}"
      declare unwrap_token_type="${unwrap_token_quoted_type:1:-1}"   # unquote
      declare unwrap_token_value="${unwrap_token_quoted_value:1:-1}" # unquote 
      if [[ ${_VERBOSETY_LEVEL_HIGH_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then
         echo "unwrap_token_type          = »${unwrap_token_type}«" 
         echo "unwrap_token_value         = »${unwrap_token_value}«" 
      fi
      MAP_TO_TYPE["${token}"]="${unwrap_token_type}"
      MAP_TO_VALUE["${token}"]="${unwrap_token_value}"
   done
   if [[ ${_VERBOSETY_LEVEL_ULTRA_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then
      echo "MAP_TO_TYPE"
      for token in "${!MAP_TO_TYPE[@]}"; do
         echo -n "type: »${MAP_TO_TYPE[$token]}«"
         echo "${_TAB_}token  : »$token"
      done
      echo "MAP_TO_VALUE"
      for token in "${!MAP_TO_VALUE[@]}"; do
         echo "token  : »$token«"
         echo "value: »${MAP_TO_VALUE[$token]}«"
      done
   fi
}

# int next_expression ( prev=1 )
#   /(> fd 5
# <)/   MAP_TO_TYPE
# <)/   MAP_TO_VALUE
function next_expression () {
   return 
}

# int parse ( parse_curr_token_no=1  parse_prev_token_type=2 )
#   !(> main_parse_prev_token_type !!!
# <)/   fd 5
# <)/   MAP_TO_TYPE
# <)/   MAP_TO_VALUE
function parse () {
   while [[ true ]]; do
      if [[ ${_VERBOSETY_LEVEL_HIGH_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then true; fi
      ########################################################################################
      #######################################!!!!!!!!!!!!!!!!!!!!#############################
      [[ 0 -lt 0 ]] || break
      ########################################################################################
      case "foo" in
         *) stop "parse: foo" '1' ;;
      esac
   done
}



# int main ( void )
# <)/   ARG_INFLILE
# <)/   TOKEN_AT
# <)/   MAP_TO_TYPE
function main () {
   read_token "${ARG_INFLILE}"
   unwrap_token
   declare local main_parse_prev_token_type=${_TOKEN_TYPE_NONE_}
   declare -r -i main_amount_of_token=${#TOKEN_AT[*]}
   for (( token_no=0; 
          token_no < $(( $main_amount_of_token )); 
          token_no++ )); do
      declare local token=${TOKEN_AT[${token_no}]}
      if [[ ${_VERBOSETY_LEVEL_ULTRA_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then echo "main_parse_prev_token_type  = »${main_parse_prev_token_type}«"; fi
      #          self               prev                 stop_at
      parse "${token_no}" "${main_parse_prev_token_type}" "${_SEMICOLON_}"
      main_parse_prev_token_type=${MAP_TO_TYPE[${token}]}
   done
   return 0
}
main
 