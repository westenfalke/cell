#!/bin/bash
set -e
set -u
#set -x
source system.h
source parser.h



parser token_parser "syntax_w_nl.l" ";"
echo '---'
system.stdout.printString "value of filename is"
system.stdout.printValue token_parser.filename
echo '---'
token_parser.to_string
echo '---'
echo printToken
token_parser.tokens_to_string

for foo in "${token_parser_token_at[@]}" ; do 
    system.stdout.printString "foo = '${foo}'"
    system.stdout.printValue token_parser.token.next
    system.stdout.printValue token_parser.type.next
    system.stdout.printString "'$(token_parser.value.next)'"
    token_parser.token.move_next
    system.stdout.printValue token_parser.token.prev
    system.stdout.printValue token_parser.type.prev
    system.stdout.printString "'$(token_parser.value.prev)'"
done




