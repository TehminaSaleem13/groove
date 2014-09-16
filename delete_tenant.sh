#!/bin/bash
bold=`tput bold`
normal=`tput sgr0`

while getopts ":n:f" opt; do
    case $opt in
        n)
            TENANT=$OPTARG
            ;;
        f)
            CONFIRMED=1
            ;;
        \?)
            echo "Unknown argument: -$OPTARG" >&2
            ;;
    esac
done

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
            RAILS_ENV=production rake groove:del_tenant -- --tenant ${TENANT}
            exit
EOF
        #mysql -u root -ppassword -Be "DROP SCHEMA IF EXISTS ${TENANT}; DELETE FROM groovepacks_production.tenants where tenants.name='${TENANT}' LIMIT 1;"
        #sudo service nginx start
    else
        echo "Cannot delete groovepacks_production"
    fi
fi
