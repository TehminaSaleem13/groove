# frozen_string_literal: true

class ApiKeysController < ApplicationController
  before_action :groovepacker_authorize!
  before_action :set_api_key, only: %i[destroy]

  def create
    api_key = ApiKey.create(author: current_user)
    ApiKey.all.where.not(id: api_key.id).update_all(deleted_at: Time.current)
    render json: { status: true, success_messages: ['Api Key generated'] }, status: :created
  end

  def destroy
    @api_key.update(deleted_at: Time.current)
    render json: { status: true, success_messages: ['Api Key deleted'] }, status: :ok
  end

  private

  def set_api_key
    @api_key = ApiKey.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { status: false, error_messages: ['Api Key not found'] }, status: :not_found
  end
end
