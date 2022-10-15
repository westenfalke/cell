#!/bin/bash
exec 3>&1 1>&2
set -o errexit
set -o nounset
# _VAIABLES_ with underscores are supposed to be R/O alias static,
# never the less, the _OPT_NAME_ and _ARG_NAME_ vars are declared twice
# they are initialized empty to run this script with 'nounset' option.
# They'll become R/O even if they are not set in fn init_args_n_noptions()   
declare _AMOUNT_OF_UNRECOGNIZED_PARAMETER_=
declare _OPT_DEBUG_LEVEL_=
declare _OPT_VERBOSETY_LEVEL_=
declare _ARG_BUFFER_=
declare _ARG_CHAR_=
declare _ARG_INFLILE_=/dev/null

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
   declare -r stop_message=${1:-"OK (/)"}
   declare -r -i stop_exit_code=${2:-0}
   if [[ ${stop_exit_code} -gt 0 ]] || [[ ${_OPT_VERBOSETY_LEVEL_} ]]; then 
      printf '%s (%i)\n' "${stop_message}" "${stop_exit_code}"
   fi
   exit "${stop_exit_code}"
}

usage()
{
  echo "Usage: ${_ARG_THIS_} [ -g | --debug ] [ -h | --help ] 
                        [ -b | --buffer a string]
                        [ -c | --char a singe char ] 
                        [filename]"
}


function init_args_n_noptions () {
   declare -r _ARG_THIS_="${0}"
   set +o errexit
   _PARSED_ARGUMENTS_=$(getopt -a -n ${_ARG_THIS_} -o h,g,v,b:c: --long help,debug,verbose,buffer:,char: -- "$@")
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
      -h | --help)       usage                                 ; exit 0  ;;
      -g | --debug)      declare -r -i _OPT_DEBUG_LEVEL_=1     ; shift   ;;
      -v | --verbose)    declare -r -i _OPT_VERBOSETY_LEVEL_=1 ; shift   ;;
      -b | --buffer)     declare -r _ARG_BUFFER_="$2"          ; shift 2 ;;
      -c | --char)       declare -r _ARG_CHAR_="$2"            ; shift 2 ;;
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

   if [[ ! -z ${@} ]]; then _ARG_INFLILE_=${1} ; fi # the remaining parameter is supposed to be the filname
   if [[ ${_OPT_VERBOSETY_LEVEL_} ]]; then 
      echo "_PARSED_ARGUMENTS_ is     '$_PARSED_ARGUMENTS_'"
      echo "_OPT_DEBUG_LEVEL_       : '${_OPT_DEBUG_LEVEL_}'"
      echo "_OPT_VERBOSETY_LEVEL_   : '${_OPT_VERBOSETY_LEVEL_}'"
      echo "_ARG_BUFFER_            : '${_ARG_BUFFER_}'"
      echo "_ARG_CHAR_              : '${_ARG_CHAR_}'"
      echo "INFILE                  : '${_ARG_INFLILE_}' (alias filename)"
      echo "Parameters remaining are: '${@}'"
   fi
   if [[ ! -r ${_ARG_INFLILE_} ]]; then stop "filename '${_ARG_INFLILE_}' is not readable or does not exist" '22' ; fi
   if [[ ${_OPT_DEBUG_LEVEL_} ]]; then set -x ; fi
}


################################################################################
### start of function parse ####################################################
################################################################################

function parse () {
   declare -i parse_cur_token_no=${1}
   declare -r prev_type="${2}"
   while [[ true ]]; do
      declare parse_buff=${_TOKEN_[parse_cur_token_no]}
      declare parse_stripped_buff="${parse_buff:1:-3}"
      parse_stripped_buff=${parse_stripped_buff/${_COMMA_}${_SPACE_}/${_TAB_}} #OK
      if [[ ${_OPT_VERBOSETY_LEVEL_} ]]; then
         echo "--- token #[${parse_cur_token_no}]"
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
      if [[ ${_OPT_VERBOSETY_LEVEL_} ]]; then 
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
      [[ 0 -lt ${#parse_stripped_buff} ]] || PREV_TYPE="${parse_token_type}"; break
      #############################      
   done
}

################################################################################
### end of function parse ######################################################
################################################################################

### if [[ ${_ARG_BUFFER_} ]]; then
###    declare buff_line="$(tr -d '\n\r\t' <<< ${_ARG_BUFFER_})" 
###    declare buff_line_token="('_ARG_BUFFER_', '${buff_line}')"
###    parse "${buff_line}" "${_EMPTY_TOKEN_}" "${PREV_TYPE}"
### fi

function read_token () {
   ORIG_IFS="$IFS"
   IFS=$'\n' # don't stop on 'newlines'
   set +o errexit 
   read -d "${_NEWLINE_}" -r -a _TOKEN_ < "${_ARG_INFLILE_}" # -d '' works like a charm, but with exit code (1)?!
   set -o errexit
   IFS="$ORIG_IFS"
   if [[ ${_OPT_VERBOSETY_LEVEL_} ]]; then echo '---';for element in "${_TOKEN_[@]}" ; do echo "$element" ; done ; echo '---'; fi
}

function main () {
   declare PREV_TYPE=${_NONE_}
   init_args_n_noptions ${@}
   read_token
   main_i_amount_of_token=${#_TOKEN_[*]}
   for (( main_cur_token_no=0; main_cur_token_no<$(( $main_i_amount_of_token )); main_cur_token_no++ )); do
      parse  main_cur_token_no "${PREV_TYPE}"
   done
   return 0
}

main ${@}
 