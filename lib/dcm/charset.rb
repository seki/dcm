# coding: us-ascii
module DCM_CharSet
  class InvalidCharSet < RuntimeError
  end

  class Context
    def initialize(dcm_00080005)
      ary = parse_charset(dcm_00080005).map {CharactorSet[_1]}

      if ary.size == 1 && ary.first[:encoding]
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
    def initialize(code_element, escape_sequence, encoding)
      @code_element = code_element
      @escape_sequence = escape_sequence.pack('c*')
      @encoding = encoding
    end
    attr_reader :escape_sequence, :encoding, :code_element

    def encode(str)
      str.force_encoding(@encoding)
    end

    def inspect
      "#<#{self.class.to_s}:#{@escape_sequence.inspect} #{@encoding}>"
    end
  end

  module E_shift_to_GR
    def encode(str)
      str.each_byte.map {|x| x | 0x80}.pack('c*').force_encoding(@encoding)
    end
  end

  AsciiElement = Element.new('GL', [0x1B, 0x28, 0x42], 'ascii')

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
      :elements => [AsciiElement]
    },

    'ISO 2022 IR 100' => {
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x41], 'ISO_8859_1')
      ]
    },

    'ISO 2022 IR 101' => {
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x42], 'iso-8859-2')
      ]
    },

    'ISO 2022 IR 109' => {
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x43], 'iso-8859-3')
      ]
    },

    'ISO 2022 IR 110' => {
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x44], 'iso-8859-4')
      ]
    },
    
    'ISO 2022 IR 144' => {
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x4C], 'iso-8859-5')
      ]
    },

    'ISO 2022 IR 127' => {
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x47], 'iso-8859-6')
      ]
    },

    'ISO 2022 IR 126' => {
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x46], 'iso-8859-7')
      ]
    },

    'ISO 2022 IR 138' => {
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x48], 'iso-8859-8')
      ]
    },

    'ISO 2022 IR 148' => {
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x4D], 'iso-8859-9')
      ]
    },

    # Japanese
    'ISO 2022 IR 13' => {
      :elements => [
        Element.new('GL', [0x1B, 0x28, 0x4A], 'cp50221'),
        Element.new('GR', [0x1B, 0x29, 0x49], 'cp50221')
      ]
    },

    'ISO 2022 IR 166' => {
      :elements => [
        AsciiElement, 
        Element.new('GR', [0x1B, 0x2D, 0x54], 'tis-620')
      ]
    },

    # Multi-byte with extensions 

    'ISO 2022 IR 87' => {
      :elements => [
        Element.new('GL', [0x1B, 0x24, 0x42], 'euc-jp').extend(E_shift_to_GR)
      ]
    },

    'ISO 2022 IR 159' => {
      :elements => [
        Element.new('GL', [0x1B, 0x24, 0x28, 0x44], 'euc-jp').extend(E_shift_to_GR)
      ]
    },

    'ISO 2022 IR 149' => {
      :elements => [
        Element.new('GR', [0x1B, 0x24, 0x29, 0x43], 'euc-kr')
      ]
    },

    'ISO 2022 IR 58' => {
      :elements => [
        Element.new('GR', [0x1B, 0x24, 0x29, 0x41], 'gb18030')
      ]
    },

    # Multi-byte without extensions
    'ISO_IR 192' => { 
      :encoding =>'utf-8',
    },

    'GB18030' => {
      :encoding => 'GB18030',
    },

    'GBK' => { 
      :encoding => 'gbk',
    }
  }

end

if __FILE__ == $0

  def do_it(dcm_00080005, str)
    pp DCM_CharSet::Context.new(dcm_00080005).convert(str).map {|x| x.encode('utf-8')}
  end

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

  do_it("\\ISO 2022 IR 87", "Yamada^Tarou=\033$B;3ED\033(B^\033$BB@O:\033(B=\033$B$d$^$@\033(B^\033$B$?$m$&\033(B")
  do_it("ISO 2022 IR 13\\ISO 2022 IR 87", "\324\317\300\336^\300\333\263=\033$B;3ED\033(J^\033$BB@O:\033(J=\033$B$d$^$@\033(J^\033$B$?$m$&\033(J")
  do_it("\\ISO 2022 IR 149", "Hong^Gildong=\033$)C\373\363^\033$)C\321\316\324\327=\033$)C\310\253^\033$)C\261\346\265\277")
  do_it("ISO_IR 192", "\x57\x61\x6e\x67\x5e\x58\x69\x61\x6f\x44\x6f\x6e\x67\x3d\xe7\x8e\x8b\x5e\xe5\xb0\x8f\xe6\x9d\xb1\x3d")
  do_it("GB18030", "\x57\x61\x6e\x67\x5e\x58\x69\x61\x6f\x44\x6f\x6e\x67\x3d\xcd\xf5\x5e\xd0\xa1\xb6\xab\x3d")
  do_it("\\ISO 2022 IR 58", "\x5A\x68\x61\x6E\x67\x5E\x58\x69\x61\x6F\x44\x6F\x6E\x67\x3D\x1B\x24\x29\x41\xD5\xC5\x5E\x1B\x24\x29\x41\xD0\xA1\xB6\xAB\x3D\x20")
end