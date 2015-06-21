module Groovepacker
  module Dashboard
    module Color
      class Pallete
        attr_accessor :palletes

        def initialize(size, base_color)
          color = Paleta::Color.new(:hex, base_color)
          @palettes = Paleta::Palette.generate(
            :type => :tetrad, :from => :color, :size => size, :color => color)
        end

        def get(index)
          @palettes[index].hex
        end
      
      end
    end
  end
end