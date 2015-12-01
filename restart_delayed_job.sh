#!/bin/bash
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

NUM_JOBS=10

if [ ${ENV} != 'staging' ] && [ ${ENV} != 'production' ]; then
    echo "${bold}$ENV${normal} environment not recognized. Please select an environment"
    PS3="p/s/q: "
    select yn in "Staging" "Production" "Quit"; do
        case "$REPLY" in
            ("Staging"|"S"|"s"|"STAGING"|"staging"|"STAGE"|"Stage"|1)  ENV='staging'; break;;
            ("Production"|"P"|"p"|"PRODUCTION"|"prod"|"PROD"|"Prod"|2)  ENV='production'; break;;
            ("Quit"|"q"|"QUIT"|"quit"|3|0)  echo "Bye.."; exit;;
            *) echo "Unknown input, please try again!";;
        esac
    done
fi
echo "${bold}$ENV${normal} environment selected"

sudo chown groovepacker:groovepacker /home/groovepacker/groove -R

if [ ${ENV} == 'staging' ]; then
    NUM_JOBS=1
fi

sudo su groovepacker <<EOF
source /usr/local/rvm/scripts/rvm

cd ~/groove

RAILS_ENV=${ENV} bundle exec script/delayed_job stop
git remote set-url origin git@bitbucket.org:groovepacker/groovepacker.git

git stash
git checkout ${ENV}
git pull origin ${ENV}


#RAILS_ENV=${ENV} bundle exec bundle install --deployment
#RAILS_ENV=${ENV} bundle exec script/delayed_job -n ${NUM_JOBS} start

exit
EOF
