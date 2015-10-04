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
    ENV='Unkown'
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

#RAILS_ENV=${ENV} script/delayed_job stop

sudo su groovepacker <<EOF
mv public/maintainance_off.html public/maintainance_on.html
source /usr/local/rvm/scripts/rvm

cd ~/groove

git remote set-url origin git@bitbucket.org:groovepacker/groovepacker.git

git stash
git checkout ${ENV}
git pull origin ${ENV}

git submodule init
git submodule update --recursive

rm vendor/assets/components/**/*.js.{gzip,map}
RAILS_ENV=${ENV} bundle exec bundle install --deployment
RAILS_ENV=${ENV} bundle exec rake db:migrate
RAILS_ENV=${ENV} bundle exec rake db:seed
RAILS_ENV=${ENV} bundle exec rake assets:clean
RAILS_ENV=${ENV} bundle exec rake assets:precompile
RAILS_ENV=${ENV} bundle exec rake fs:delete_files
mv public/maintainance_on.html public/maintainance_off.html

exit
EOF
#RAILS_ENV=${ENV} script/delayed_job -n ${NUM_JOBS} start

sudo service nginx stop
sudo service nginx start
