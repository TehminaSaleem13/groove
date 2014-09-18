#!/bin/sh
bold=`tput bold`
normal=`tput sgr0`
while getopts ":e:" opt; do
    case $opt in
        e)
            if [[ $OPTARG == p* ]] || [[ $OPTARG == P* ]]; then
                ENV='production'

            elif [[ $OPTARG == s* ]] || [[ $OPTARG == S* ]]; then
                ENV='staging'
            else
                ENV=$OPTARG
            fi
            ;;
        \?)
            echo "Unknown argument: -$OPTARG" >&2
            ;;
    esac
done

if [ -z "$ENV"  ]; then
    ENV='Unknown'
fi

if [ ${ENV} != 'staging' ] && [ ${ENV} != 'production' ]; then
    echo "${bold}$ENV${normal} environment not recognized. Please select an environment"
    PS3="p/s/n: "
    select yn in "Staging" "Production" "Quit"; do
        case "$REPLY" in
            ("Production"|"P"|"p"|"PRODUCTION"|"prod"|"PROD"|"Prod"|1)  ENV='production'; break;;
            ("Staging"|"S"|"s"|"STAGING"|"staging"|"STAGE"|"Stage"|1)  ENV='staging'; break;;
            ("Quit"|"q"|"QUIT"|"quit"|3|0)  echo "Bye.."; exit;;
            *) echo "Unknown input, please try again!";;
        esac
    done
fi
echo "${bold}$ENV${normal} environment selected"

sudo chown groovepacker:groovepacker /home/groovepacker/groove -R

sudo su groovepacker <<EOF
source /usr/local/rvm/scripts/rvm

cd ~/groove

RAILS_ENV=${ENV} script/delayed_job stop
RAILS_ENV=${ENV} script/delayed_job -n 2 start

exit
EOF
