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
    ENV='Unkown'
fi

if [ ${ENV} != 'staging' ] && [ ${ENV} != 'production' ]; then
    echo "${bold}$ENV${normal} environment not recognized. Please select an environment"
    PS3="p/s/q: "
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

sudo service nginx stop

sudo chown groovepacker:groovepacker /home/groovepacker/groove -R

sudo su groovepacker <<EOF
source /usr/local/rvm/scripts/rvm

cd ~/groove
git remote set-url origin git@bitbucket.org:jonnyclean/groovepacker.git

git stash
git pull origin master

RAILS_ENV=${ENV} script/delayed_job stop
RAILS_ENV=${ENV} bundle install --deployment
RAILS_ENV=${ENV} rake db:migrate
RAILS_ENV=${ENV} rake db:seed
RAILS_ENV=${ENV} rake assets:precompile
RAILS_ENV=${ENV} rake fs:delete_pdfs
RAILS_ENV=${ENV} script/delayed_job start

exit
EOF

sudo service nginx start
