#!/bin/bash
exec 3>&1 1>&2
set -o errexit
set -o nounset

declare -r -i _VERBOSETY_LEVEL_LOW_=0
declare -r -i _VERBOSETY_LEVEL_HIGH_=1
declare -r -i _VERBOSETY_LEVEL_ULTRA_=2
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
function init_opts_n_args () {   
set +o errexit
_PARSED_ARGUMENTS_=$(getopt -a -n ${_ARG_THIS_} -o h,g,v,b:c: --long help,debug,buffer:,char: -- "$@")
declare -r -i _AMOUNT_OF_UNRECOGNIZED_OPTIONS_="${?}"
if [ "$_AMOUNT_OF_UNRECOGNIZED_OPTIONS_" -gt '0' ]; then
   usage
   stop "Illegal Argument" '22'
fi
set -o errexit
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
   --) shift; break ;;
   # If invalid options were passed, then getopt should have reported an error,
   # which we checked as _AMOUNT_OF_UNRECOGNIZED_OPTIONS_ when getopt was called...
   *) echo "Famous Last Words - Unexpected option: $1 - this should not happen."
      usage 
      stop "Unkown Parameter or option found" '22'

   ;;
esac
done

if [[ ! -z ${@} ]]; then ARG_INFLILE=${1} && shift ; fi # the remaining parameter is supposed to be the filname
if [[ ${_VERBOSETY_LEVEL_LOW_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then 
   echo "_PARSED_ARGUMENTS_ is     '$_PARSED_ARGUMENTS_'"
   echo "_OPT_DEBUG_LEVEL_       : '${_OPT_DEBUG_LEVEL_}'"
   echo "OPT_VERBOSETY_LEVEL     : '${OPT_VERBOSETY_LEVEL}'"
   echo "_ARG_BUFFER_            : '${_ARG_BUFFER_}'"
   echo "_ARG_CHAR_              : '${_ARG_CHAR_}'"
   echo "INFILE                  : '${ARG_INFLILE}' (alias filename)"
   echo "Parameters remaining are: '${@}'"
fi
if [[ ! -r ${ARG_INFLILE} ]]; then stop "filename '${ARG_INFLILE}' is not readable or does not exist" '22' ; fi
if [[ ${_OPT_DEBUG_LEVEL_} ]]; then set -x ; fi
}

function read_token () {
   ORIG_IFS="$IFS"
   IFS=$'\n' # don't stop on 'newlines'
   set +o errexit 
   read -d "${_NEWLINE_}" -r -a _TOKEN_ < "${ARG_INFLILE}" # -d '' works like a charm, but with exit code (1)?!
   set -o errexit
   IFS="$ORIG_IFS"
   if [[ ${_VERBOSETY_LEVEL_HIGH_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then echo '---';for element in "${_TOKEN_[@]}" ; do echo "$element" ; done ; echo '---'; fi
}

################################################################################
### start of function parse ####################################################
################################################################################
function parse () {
   declare -i parse_cur_token_no=${1}
   declare -r parse_prev_token_type="${2}"
   while [[ true ]]; do
      declare parse_buff=${_TOKEN_[parse_cur_token_no]}
      declare parse_stripped_buff="${parse_buff:1:-3}"
      parse_stripped_buff=${parse_stripped_buff/${_COMMA_}${_SPACE_}/${_TAB_}} #OK
      if [[ ${_VERBOSETY_LEVEL_ULTRA_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then
         echo "--- token #[${parse_cur_token_no}]"
         echo "parse_buff            = »${parse_buff}« [${#parse_buff}]"
         echo "parse_stripped_buff   =  »${parse_stripped_buff/${_TAB_}/${_ESC_TAB_}}«  [${#parse_stripped_buff}]"
      fi
      ORIG_IFS="${IFS}"
      IFS=$'\t'
      set +o errexit # don't stop on 'newlines'
         read -d '' -a parse_a_token <<< "${parse_stripped_buff}" # -d '' works like a charm, but with exit code (1)?!
      set -o errexit
      IFS="${ORIG_IFS}"
      declare parse_token_type="${parse_a_token[0]:1:-1}"
      declare parse_token_value="${parse_a_token[1]:1:-1}" 
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
               echo "   ${_TOKEN_[parse_cur_token_no-1]}," >&3
               echo ")" >&3
               return
               echo "   ${_TOKEN_[parse_cur_token_no+1]}," >&3
               echo "   ${_TOKEN_[parse_cur_token_no+2]}" >&3
            fi
         ;;
         ${_OPERATION_TOKEN_})
            #echo "${_TOKEN_[parse_cur_token_no+0]}" >&3
         ;;
         ${_SYMBOL_TOKEN_}|${_STRING_TOKEN_}|${_NUMBER_TOKEN_})
            #echo "${_TOKEN_[parse_cur_token_no+0]}" >&3
         ;;
         ${_PARAN_OPEN_}|${_PARAN_CLOSE_})
            #echo "${_TOKEN_[parse_cur_token_no+0]}" >&3
         ;;
         ${_CURLY_OPEN_}|${_CURLY_CLOSE_})
            #echo "${_TOKEN_[parse_cur_token_no+0]}" >&3
         ;;
         ${_COMMA_})
            #echo "${_TOKEN_[parse_cur_token_no+0]}" >&3
         ;;
         *) stop "unkowm token type »${parse_token_type}« found in line #${parse_cur_token_no} parsing »${parse_buff}« [${#parse_buff}]" '1' ;;
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

# _VAIABLES_ with underscores are supposed to be R/O alias static,
# never the less, the _OPT_NAME_ and _ARG_NAME_ vars are declared twice
# they are initialized neutal/empty to run this script with 'nounset' option.
# They'll become R/O even if they are not set again during getopt  
declare -r _ARG_THIS_="${0}"
declare _AMOUNT_OF_UNRECOGNIZED_PARAMETER_=
declare _OPT_DEBUG_LEVEL_=
declare -i OPT_VERBOSETY_LEVEL=0 # will be risen during getopt -v -vv -vvv
declare _ARG_BUFFER_=
declare _ARG_CHAR_=
declare ARG_INFLILE=/dev/null # the_TOKEN_ array gets always initialised
function main () {
   init_opts_n_args "${@}"
   declare local main_prev_token_type=${_NONE_}
   read_token
   main_i_amount_of_token=${#_TOKEN_[*]}
   for (( main_cur_token_no=0; 
          main_cur_token_no < $(( $main_i_amount_of_token )); 
          main_cur_token_no++ )); do
      parse  "${main_cur_token_no}" "${main_prev_token_type}"
      if [[ ${_VERBOSETY_LEVEL_ULTRA_} -lt ${OPT_VERBOSETY_LEVEL} ]]; then echo "main_prev_token_type  = »${main_prev_token_type}«"; fi
   done
   return 0
}

main "${@}"
 