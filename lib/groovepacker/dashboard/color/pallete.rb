module Groovepacker
  module Dashboard
    module Color
      class Pallete
        attr_accessor :palletes

        def initialize(size, base_color)
          color = Paleta::Color.new(:hex, base_color)
          if size >= 4
            pallete_type = :tetrad
          elsif size >= 3
            pallete_type = :triad
          elsif size >= 2
            pallete_type = :split_complement
          else
            pallete_type = :monochromatic
          end

          @palettes = Paleta::Palette.generate(
            :type => pallete_type, :from => :color, :size => size, :color => color)
        end

        def get(index)
          @palettes[index].hex
        end
      
      end
    end
  end
end