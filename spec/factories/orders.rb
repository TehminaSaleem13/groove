# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order do
    increment_id "12345678"
    order_placed_time "2013-09-03 23:21:02"
    store nil
    firstname "Shyam"
    lastname "Visamsetty"
    email "svisamsetty@navaratan.com"
    address_1 "7-1-79, SV's Meera Mansion"
    address_2 "Ameerpet, Hyderabad"
    city "Hyderabad"
    state "Andhra Pradesh"
    postcode "500016"
    country "India"
    status "awaiting"
    scanned_on ""
  end
end
