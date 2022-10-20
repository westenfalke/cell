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



