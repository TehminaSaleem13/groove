#!/bin/bash
bold=`tput bold`
normal=`tput sgr0`

while getopts ":n:e:f" opt; do
    case $opt in
        n)
            TENANT=$OPTARG
            ;;
        f)
            CONFIRMED=1
            ;;
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

if [ -z "$TENANT"  ]; then
    echo "Enter name of tenant to delete"
    read TENANT
fi

if [ -z "$CONFIRMED" ]; then
echo "Are you sure you want to delete ${bold}${TENANT}${normal} tenant?"
PS3="y/n: "
select yn in "Yes" "No"; do
    case "$REPLY" in
        ("Yes"|"Y"|"y"|1)  CONFIRMED=1; break;;
        ("No"|"N"|"n"|2|0)  CONFIRMED=0;break;;
        *) echo "Unknown input, please try again!";;
    esac
done
fi

if [ $CONFIRMED == 1 ]; then
    if [ $TENANT  != "groovepacks_production" ]; then
        #sudo service nginx stop
        sudo su groovepacker <<EOF
            source /usr/local/rvm/scripts/rvm

            cd ~/groove
            RAILS_ENV=${ENV} rake groove:del_tenant -- --tenant ${TENANT}
            exit
EOF
        #mysql -u root -ppassword -Be "DROP SCHEMA IF EXISTS ${TENANT}; DELETE FROM groovepacks_production.tenants where tenants.name='${TENANT}' LIMIT 1;"
        #sudo service nginx start
    else
        echo "Cannot delete groovepacks_production"
    fi
fi
