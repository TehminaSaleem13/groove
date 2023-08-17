# frozen_string_literal: true

class OriginStoresController < ApplicationController
  before_action :groovepacker_authorize!
  before_action :find_store, only: [:update]

  def update
    if @origin_store.update(origin_store_params)
      render json: @origin_store
    else
      render json: { errors: @origin_store.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def origin_store_params
    params.require(:origin_store).permit(:store_name)
  end

  def find_store
    @origin_store = OriginStore.find_by(origin_store_id: params[:origin_store_id])

    render json: { error: 'Origin Store not found' }, status: :not_found unless @origin_store
  end
end
