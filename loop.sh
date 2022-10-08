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
