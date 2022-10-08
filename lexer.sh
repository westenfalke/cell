#!/bin/bash

function usage () {
cat <<'HELPMSG'
  usage $0 [--help] []

HELPMSG
}
function help_wanted() {
   [ "$#" -ge "1" ] && [ "$1" = '-h' ] || [ "$1" = '--help' ] || [ "$1" = "-?" ]
}

if help_wanted "$@"; then
   usage
   exit 0
fi

die() {
  printf >&2 '%s\n' "$1"
  exit 1
}
from_source_file=$1

##new_lines="\r\n"
##stripp_source_code=$(tr --delete "x" < ${from_source_file:-/dev/null}) # just to fit in an array
##IFS=";" ; declare -a source_code=(${stripp_source_code}) ; for element in "${source_code[@]}" ; do echo "$element" ; done # each line 
 
ORIG_IFS="$IFS"
IFS=$'|\n;' ; read -d '' -a  source_code  < ${from_source_file} # don't stop on 'pipes', 'newlines' and 'semicolons'
IFS="$ORIG_IFS"
#echo '---';for element in "${source_code[@]}" ; do echo "$element" ; done ; echo '---' # put in a debug statement

PREV_LINE=-1
CURR_LINE=0
NEXT_LINE=1

echo ${source_code[$PREV_LINE]}
echo ${source_code[$CURR_LINE]}
echo ${source_code[$NEXT_LINE]}

# example for non alpha (*[![:alpha:]]*)
# ‘[a-dx-z]’ is equivalent to ‘[abcdxyz]’
# alnum   alpha   ascii   blank   cntrl   digit   graph   lower print   punct   space   upper   word    xdigit
CHAR_AMPERSAND='&'
CHAR_EOF=EOF
CHAR_NEWLINE='\n'
CHAR_PIPE='|'
CHAR_SEMICOLON=';'
CHAR_COLON=':'
CHAR_PLUS_SIGN='+'
CHAR_MINUS_SIGN='-'
CHAR_EQUAL_SIGN='='
CHAR_COMMA=','
CHAR_PARAN_OPEN='('
CHAR_PARAN_CLOSE=')'
CHAR_QUOTE="'"
CHAR_DOUBLE_QUOTE='"'
CHAR_CURLY_OPEN='{'
CHAR_CURLY_CLOSE='{'
CHAR_MUL='*'
CHAR_DIV='/'
CHAR_TAB='\t'

function lex () {
c=${1}
case "${c}" in
# Ignore (line breaking) white spacce
#    [[:space:]]|"${CHAR_NEWLINE}"|"${CHAR_TAB}") 
#    [[:space:]]|"${CHAR_NEWLINE}"|"${CHAR_TAB}") 
    [[:space:]]) 
        echo "pass:  # >>${c}<< is a [line breaking] whitspace"
        ;;
# special character        
#     ${CHAR_PARAN_OPEN}|${CHAR_PARAN_CLOSE}|${CHAR_CURLY_OPEN}|${CHAR_PARAN_CLOSE}|${CHAR_COMMA}|${CHAR_SEMICOLON}|${CHAR_EQUAL_SIGN}|${CHAR_COLON})
     [[:punct:]])
        echo "yild(c, \"\") # >>${c}<< is a special character "
        ;;
# operator
     ${CHAR_PLUS_SIGN}|${CHAR_MINUS_SIGN}|\${CHAR_MUL}|${CHAR_DIV})
        echo "yield (\"operation\", c)' # operator >>${c}<<"
        ;;
# string
     ${CHAR_QUOTE}|${CHAR_DOUBLE_QUOTE})
        echo "yield (\"string\", _scan_string(c, chars)) # >>${c}<<"
        ;;
# number
     [[:digit:]])
        echo "yield (\"number\", _scan(c, chars, \"[.0-9]\"))# >>${c}<<"
        ;;
# symbole
     [[:alpha:]])
        echo 'yield ("symbol", _scan(c, chars, "[_a-zA-Z0-9]"))'
        ;;
# TAB not allowed
     "${CHAR_TAB}")
        echo "raise Exception(\"Tabs >>${c}<< are not allowed in Cell\")"
        ;;
    *)
        echo "raise Exception(\"Unexpected character: >>${c}<<\")"
        ;;
    esac        
}

function PeekableString () {
    return
}

exit 0

function test () {
   lex ${CHAR_PARAN_OPEN}
   lex ${CHAR_PARAN_CLOSE}
   lex ${CHAR_CURLY_CLOSE}
   lex ${CHAR_EQUAL_SIGN}
   lex ${CHAR_SEMICOLON}
   lex '.'
   lex 9
   lex "9"
   lex "A"
   lex "i"
   lex '+'
   lex '-'
   lex '/'
   lex '"'
   lex "'"
   lex '\t'
   lex ${CHAR_NEWLINE}
   lex ' '
   lex " "
   return 0
}

test

amount_of_lines=${#source_code[*]}
for (( line_no=0; line_no<$(( $amount_of_lines )); line_no++ ))
do 
   line=${source_code[line_no]}
   chars=${#line}
   echo $chars' chars in line #'$line_no
   for (( prev_char=-1, curr_char=0, next_char=1; curr_char<$(( $chars )); curr_char++, prev_char=curr_char-1, next_char=curr_char+1 ))
   do
      echo "#$line_no: $prev_char,$curr_char,$next_char;'${source_code[$line_no]}'"
      echo "< prev_char '${source_code[$line_no]:$prev_char:1}'"
      echo "| curr_char   '${source_code[$line_no]:$curr_char:1}'"
      echo "> next_char    '${source_code[$line_no]:$next_char:1}'"

   done
done

