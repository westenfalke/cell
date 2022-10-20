#! Constructor
#! int parser ( <object_name>=1 <filename>=2 [<stop_at>=3:-";"] )

parser(){
    . <(sed "s/obj/$1/g" parser.class)
    ${1}.self = ${1}
    ${1}.filename = ${2}
    ${1}.stop_at = ${3}

    ${1}.read_token
    echo "DONE ${1}.read_token"
    ${1}.unwrap_token
    echo "DONE ${1}.unwrap_token"

}