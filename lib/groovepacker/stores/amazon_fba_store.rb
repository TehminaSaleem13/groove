# frozen_string_literal: true

module Groovepacker
  module Stores
    class AmazonFbaStore
      def initialize(store, params, result)
        @store = store
        @result = result
        @params = params
      end

      def fba_csv_data(order_file_data)
        split_from = if order_file_data.include? "\r\n"
                       "\r\n"
                     else
                       "\n"
                     end
        csv = order_file_data.split(split_from)
        shipment_id = csv[0]
        count = 0
        csv.each do |row|
          break if row.include?('Merchant SKU') && row.include?('Title')

          count += 1
        end
        (1..count).to_a.each { |_ind| csv.delete_at(0) }

        if split_from == "\r\n"
          index_0 = csv[0].split("\t").index('Merchant SKU')
          index_1 = csv[0].split("\t").index('Title')
          index_2 = csv[0].split("\t").index('ASIN')
          index_3 = csv[0].split("\t").index('FNSKU')
          index_4 = csv[0].split("\t").index('Shipped')
          index_4 = csv[0].split("\t").index("Shipped\r") if index_4.nil?
          index_arr1 = (0..csv[0].split("\t").count - 1).to_a
          index_arr = [index_0, index_1, index_2, index_3, index_4]
          index_arr1 -= index_arr
          index_arr1 = index_arr1.sort.reverse
          csv.each_with_index do |row, index|
            row = row.split("\t")
            index_arr1.each do |ind|
              row.delete_at(ind)
            end
            if index == 0
              csv[index] = "Shipment ID\t" + row.join("\t")
            else
              val = (order_file_data.split("\r\n")[0].split("\t")[1]).to_s
              csv[index] = "#{val.split("\r")[0]}\t" + row.join("\t")
              csv[index] = csv[index].tr(',', ' ')
            end
          end
          order_file_data = csv.join("\n\r").tr("\t", ',').delete('"')
        else
          new_csv = 'Shipment ID,' + csv[0]
          csv.drop(1).each do |c|
            new_csv = new_csv + "\n#{order_file_data.split(',')[1]}," + c
          end
          order_file_data = new_csv
         end
        order_file_data
      end
    end
  end
end
