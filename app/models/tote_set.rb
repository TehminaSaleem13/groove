# frozen_string_literal: true

class ToteSet < ApplicationRecord
  # attr_accessible :name, :max_totes, :number

  has_many :totes, dependent: :destroy
  has_many :users
  
  after_create :create_totes

  def create_totes
    if totes.count < max_totes
      Range.new(1, (max_totes - totes.count)).to_a.each do
        totes.create(name: "#{name}-#{totes.all.count + 1}", number: totes.all.count + 1)
      end
    end
  end
end
