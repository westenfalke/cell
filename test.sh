
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
   lex ${CHAR_CARRIAGE_RETURN}
   lex ' '
   lex " "
   return 0
}


PREV_LINE=-1
CURR_LINE=0
NEXT_LINE=1

echo ${source_code[$PREV_LINE]}
echo ${source_code[$CURR_LINE]}
echo ${source_code[$NEXT_LINE]}

test