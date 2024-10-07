# coding: us-ascii
module DCM_CharSet
  class InvalidCharSet < RuntimeError
  end

  class Context
    def initialize(dcm_00080005)
      @charset_names = parse_charset(dcm_00080005)
      ary = @charset_names.map {CharactorSet[_1]}
      if ary.size == 1 && ary.first[:extension].nil?
        @wo_extensions = true
        @encoding = ary.first[:encoding]
      else
        @default_encoding = ary.first
        @wo_extensions = false
        @allow_encoding = {}
        ary.each do |x|
          x[:elements].each do |y|
            @allow_encoding[y.escape_sequence] = y
          end
        end
        seg = @allow_encoding.keys.map{Regexp.escape(_1)} + ['[\000-\032\034-\177]+', '[\200-\377]+']
        
        @reg = Regexp.new(seg.join('|'), 0)
      end
    end
    attr_reader :allow_encoding

    def parse_charset(charset)
      ary = charset ? charset.strip.split('\\').map {|x| x.strip.upcase} : []
      return ['ISO_IR 6'] if ary.empty?
      ary[0] = 'ISO 2022 IR 6' if ary[0].empty?
  
      ary.each do |x|
        raise(InvalidCharSet.new(x)) unless CharactorSet.include?(x)
      end
  
      ary
    end

    def without_extensions?
      @wo_extensions
    end

    def scan(str)
      return [str] if without_extensions?
      str.scan(@reg)
    end

    def convert(str)
      return convert_wo_extensions(str) if without_extensions?

      element = {}
      @default_encoding[:elements].each do |x|
        element[x.code_element] = x
      end

      result = []
      scan(str).each do |seg|
        if seg[0] == "\e"
          e = @allow_encoding[seg]
          element[e.code_element] = e
        elsif seg.bytes.first < 0x80
          e = element['GL']
          result << e.encode(seg)
        else
          e = element['GR']
          result << e.encode(seg)
        end
      end

      result
    end

    def convert_wo_extensions(str)
      [str.force_encoding(@encoding)]
    end
  end
end


module DCM_CharSet
  class Element
    def initialize(code_element, escape_sequence, encoding, bytes_per_code_point)
      @code_element = code_element
      @escape_sequence = escape_sequence.pack('C*')
      @encoding = encoding
      @bytes_per_code_point = bytes_per_code_point
    end
    attr_reader :escape_sequence, :encoding, :code_element

    def encode(str)
      str.force_encoding(@encoding)
    end
  end

  module E_shift_GL_to_GR
    def encode(str)
      str.each_byte.map {|x| x | 0x80}.pack('c*').force_encoding(@encoding)
    end
  end

  AsciiElement = Element.new('GL', [0x1B, 0x28, 0x42], 'ascii', 1)

  CharactorSet = {
    # single-byte w/o extensions
    "ISO_IR 6" => {
      :encoding => 'ascii'
    },

    'ISO_IR 100' => {
      :encoding => 'windows-1252'
    },

    'ISO_IR 101' => {
      :encoding => 'iso-8859-2'
    },

    'ISO_IR 109' => {
      :encoding =>'iso-8859-3'
    },

    'ISO_IR 110' => {
      :encoding => 'iso-8859-4'
    },

    'ISO_IR 144' => {
      :encoding => 'iso-8859-5'
    },

    'ISO_IR 127' => {
      :encoding => 'iso-8859-6' 
    },

    'ISO_IR 126' => {
      :encoding => 'iso-8859-7'
    },

    'ISO_IR 138' => {
      :encoding => 'iso-8859-8'
    },

    # Latin alphabet No. 5
    'ISO_IR 148' => {
      :encoding => 'windows-1254' # FIXME
    },

    # FIXME
    'ISO_IR 13' => {
      :encoding => 'shift-jis' #FIXME
    },

    'ISO_IR 166' => {
      :encoding => 'tis-620'
    },

    # single-byte with extensions
    
    'ISO 2022 IR 6' =>{
      :extension => true,
      :elements => [AsciiElement]
    },

    'ISO 2022 IR 100' => {
      :extension => true,
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x41], 'ISO_8859_1', 1)
      ]
    },

    'ISO 2022 IR 101' => {
      :extension => true,
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x42], 'iso-8859-2', 1)
      ]
    },

    'ISO 2022 IR 109' => {
      :extension => true,
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x43], 'iso-8859-3', 1)
      ]
    },

    'ISO 2022 IR 110' => {
      :extension => true,
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x44], 'iso-8859-4', 1)
      ]
    },
    
    'ISO 2022 IR 144' => {
      :extension => true,
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x4C], 'iso-8859-5', 1)
      ]
    },

    'ISO 2022 IR 127' => {
      :extension => true,
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x47], 'iso-8859-6', 1)
      ]
    },

    'ISO 2022 IR 126' => {
      :extension => true,
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x46], 'iso-8859-7', 1)
      ]
    },

    'ISO 2022 IR 138' => {
      :extension => true,
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x48], 'iso-8859-8', 1)
      ]
    },

    'ISO 2022 IR 148' => {
      :extension => true,
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x4D], 'iso-8859-9', 1)
      ]
    },

    # Japanese
    'ISO 2022 IR 13' => {
      :extension => true,
      :elements => [
        Element.new('GL', [0x1B, 0x28, 0x4A], 'cp50221', 1),
        Element.new('GR', [0x1B, 0x29, 0x49], 'cp50221', 1)
      ]
    },

    'ISO 2022 IR 166' => {
      :extension => true,
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x54], 'tis-620', 1)
      ]
    },

    # Multi-byte with extensions 

    'ISO 2022 IR 87' => {
      :extension => true,
      :multi_byte => true,
      :elements => [
        Element.new('GL', [0x1B, 0x24, 0x42],
                    'euc-jp', 2).extend(E_shift_GL_to_GR)
      ]
    },

    'ISO 2022 IR 159' => {
      :extension => true,
      :multi_byte => true,
      :elements => [
        Element.new('GL', [0x1B, 0x24, 0x28, 0x44],
                    'euc-jp', 2).extend(E_shift_GL_to_GR)
      ]
    },

    'ISO 2022 IR 149' => {
      :extension => true,
      :multi_byte => true,
      :elements => [
        Element.new('GR', [0x1B, 0x24, 0x29, 0x43], 'euc-kr', 2)
      ]
    },

    'ISO 2022 IR 58' => {
      :extension => true,
      :multi_byte => true,
      :elements => [
        Element.new('GR', [0x1B, 0x24, 0x29, 0x41], 'gb18030', 2)
      ]
    },

    # Multi-byte without extensions
    'ISO_IR 192' => { 
      :encoding =>'utf-8',
      :multi_byte => true
    },

    'GB18030' => {
      :encoding => 'GB18030',
      :multi_byte => true 
    },

    'GBK' => { 
      :encoding => 'gbk',
      :multi_byte => true 
    }
  }

end

if __FILE__ == $0
  c = DCM_CharSet::Context.new("\\ISO 2022 IR 87\\ISO 2022 IR 13")

  data = [
    "\e$BB@EDAm9gIB1!\e(B",
    "SEKI^TOSHIKAZU=\e$B4X!!=SOB\e(B=\e)I\xBE\xB7\e(B^\e)I\xC4\xBC\xB6\xBD\xDE\e(B",
    "=\e$BCf_7!!Ju\e(B ",
    "\e$B<*I!0v9\"2J\e(B", 
    "\e$BF,ItD04o\e(B(\e$B;XDj$J$7\e(B)\e$BC1=c\e(B",
    "\e$BB@EDAm9gIB1!\e(B",
    "\e$BFb<*\e(B",
  ]
  data.each {|s| pp c.convert(s).map {|x| x.encode('utf-8')}}

end