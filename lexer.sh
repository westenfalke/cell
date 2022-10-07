#!/bin/bash
source_file_name=$1
source_code=$(tr -d "\n " < ${source_file_name:-/dev/null})
IFS=";" ; declare -a array=(${source_code}) ; for element in "${array[@]}" ; do echo "$element" ; done
echo '---'
#echo ${array[0]:0:2}


### for cur in "${!array[@]}"; do
###    echo ${array[0]:cur:2}
### done

lines=${#array[*]}
for (( line_no=0; line_no<=$(( $lines -1 )); line_no++ ))
do 
   line=${array[line_no]}
   chars=${#line}
   echo $chars chars per line in line $line_no
   for (( cur=0; cur<=$(( $chars -1 )); cur++ ))
   do
      let prev=cur-1
      let next=cur+1
     
      echo "$prev,$cur,$next;'${array[$line_no]}'"
      echo "prev '${array[$line_no]:$prev:1}'"
      echo "cur   '${array[$line_no]:$cur:1}'"
      echo "next   '${array[$line_no]:$next:1}'"
   done
done