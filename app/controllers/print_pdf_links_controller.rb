# app/controllers/print_pdf_links_controller.rb

class PrintPdfLinksController < ApplicationController
  before_action :groovepacker_authorize!
    def create
      json_array = params["_json"]
        # Iterate through the array and access the "uri" key in each hash
      json_array.each do |item|
        uri = item["uri"]
        file_name = item["name"]
        
        file_name = generate_unique_file_name(file_name)
        pdf_data = extract_pdf_data(uri)
        GroovS3.create_pdf(Apartment::Tenant.current, file_name, pdf_data)
        pdf_url = ENV['S3_BASE_URL'] + '/' + Apartment::Tenant.current + '/pdf/' + file_name
        @pdf_link = PrintPdfLink.new(url: pdf_url, is_pdf_printed: false, pdf_name: item["name"])
      end
      
      if @pdf_link.save
        render json: @pdf_link, status: :created
      else
        render json: @pdf_link.errors, status: :unprocessable_entity
      end
    end


    def get_pdf_list
      @result = {}
      @result = @result.merge('pdfs' => make_pdfs_list())
      render json: @result
    end

    def update_is_printed()
      print_pdf_link = PrintPdfLink.find_by(url: params[:url])
      if print_pdf_link
        # Attempt to update the is_pdf_printed attribute and save changes
        if print_pdf_link.update(is_pdf_printed: true)
          # Return true if the update was successful
          render json: { success: true }, status: :ok
        else
          # Return false if the update failed
          render json: { success: false }, status: :unprocessable_entity
        end
      else
        # Return false if the record was not found
        render json: { success: false }, status: :not_found
      end
    end
  
    private

    def generate_unique_file_name(original_name)
      "#{SecureRandom.random_number(20_000)}_#{Time.current.strftime('%d_%b_%Y_%I__%M_%p')}_#{original_name}"
    end
  
    def extract_pdf_data(uri)
      data_uri = uri.split(',')[1]
      Base64.decode64(data_uri.to_s)
    end

    def make_pdfs_list
      result = []
      PrintPdfLink.all.each do |pdf|
        product_hash = {'url' => pdf.url, 
        'is_pdf_printed' =>  pdf.is_pdf_printed,
        'pdf_name' => pdf.pdf_name,
        'id' => pdf.id}
        result.push(product_hash)
      end
      result
    end
  end
  