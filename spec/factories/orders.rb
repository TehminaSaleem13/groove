# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order do
    
    increment_id 12345678
    order_placed_time "2013-09-03 23:21:02"
    store_id 1
    firstname "Shyam"
    lastname "Visamsetty"
    email "svisamsetty@navaratan.com"
    address_1 "7-1-79, SV's Meera Mansion"
    address_2 "Ameerpet, Hyderabad"
    city "Hyderabad"
    state "Andhra Pradesh"
    postcode "500016"
    country "India"
    status "Awaiting Scanning"
    scanned_on ""
# varchar(255)
# lastname
# varchar(255)
# email
# varchar(255)
# address_1
# text
# address_2
# text
# city
# varchar(255)
# state
# varchar(255)
# postcode
# varchar(255)
# country
# varchar(255)
# method
# varchar(255)
# created_at
# datetime
# updated_at
# datetime
# notes_internal
# varchar(255)
# notes_toPacker
# varchar(255)
# notes_fromPacker
# varchar(255)
# tracking_processed
# tinyint(1)
# status
# varchar(255)
# scanned_on
# date
# tracking_num
# varchar(255)
# company
# varchar(255)
  end
end
