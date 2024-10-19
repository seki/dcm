# coding: us-ascii

require 'pp'

module DCM
  class Reader
    module ImplicitLittle
      def read_tag; read(4).unpack('vv') end
      def read_vr; nil; end
      def read_i2; read(2).unpack('v').first end
      def read_i4; read(4).unpack('V').first end
    end

    module ExplicitBig
      def read_tag; read(4).unpack('nn') end
      def read_vr; read(2).unpack('a2').first end
      def read_i2; read(2).unpack('n').first end
      def read_i4; read(4).unpack('N').first end
    end

    def initialize(buf, transfer_syntax=nil)
      @data = buf
      @cur = 0
      @transfer_syntax = transfer_syntax
      @in_file_meta = transfer_syntax ? false : true
      if transfer_syntax
        self.extend(ImplicitLittle) if @transfer_syntax == '1.2.840.10008.1.2'
        self.extend(ExplicitBig) if @transfer_syntax == '1.2.840.10008.1.2.2'
      else
        raise 'not dicom file' if !dicm?
      end
    end

    def forward(n)
      @cur += n
    end

    def read(n)
      @data[@cur, n]
    ensure
      forward(n)
    end

    def read_tag; read(4).unpack('vv') end
    def read_vr; read(2).unpack('a2').first end
    def read_i2; read(2).unpack('v').first end
    def read_i4; read(4).unpack('V').first end

    def parse(root={})
      stack = []
      stack.push(root)
      in_file_meta?(root)
      while it = (visit_attr(stack) rescue nil)
        in_file_meta?(root)
        break if @data.size <= @cur
      end
      root
    end

    def parse_sq(items=[])
      stack = []
      stack.push(items)
      while it = (visit_attr(stack) rescue nil)
        break if @data.size <= @cur
      end
      items
    end

    def in_file_meta?(root)
      if @in_file_meta
        group = @data[@cur, 2].unpack('v').first rescue return
        if group != 2
          @in_file_meta = false
          @transfer_syntax = root.dig("00020010", :value).to_s.strip
          self.extend(ImplicitLittle) if @transfer_syntax == '1.2.840.10008.1.2'
          self.extend(ExplicitBig) if @transfer_syntax == '1.2.840.10008.1.2.2'
        end
      end
    end

    def visit_attr(stack)
      tag = read_tag
      case tag
      when nil
        return false
      when [0xfffe, 0xe000]
        len = read_i4
        if len == 0xffffffff
          node = {}
          stack.last << node
          stack.push(node)
        else
          node = self.class.new(read(len), @transfer_syntax || true).parse({})
          stack.last << node
        end
      when [0xfffe, 0xe00d]
        # Hash === @stack.last
        len = read_i4
        stack.pop
      when [0xfffe, 0xe0dd]
        # Array === @stack.last
        len = read_i4
        stack.pop
      else
        vr = read_vr
        case vr
        when nil
          len = read_i4
        when 'OB', 'OW', 'OF', 'SQ', 'UN'
          forward(2)
          len = read_i4
        else
          len = read_i2
        end
        tag = sprintf("%04X%04X", *tag)
        if len == 0xffffffff
          ary = []
          stack.last[tag] = {:vr => vr, :value => ary}
          stack.push(ary)
        elsif vr == 'SQ'
          ary = self.class.new(read(len), @transfer_syntax || true).parse_sq
          stack.last[tag] = {:vr => vr, :value => ary}
        else
          stack.last[tag] = {:vr => vr, :value => read(len)}
        end
      end
      tag
    end

    def dicm?
      forward(128)
      read(4) == 'DICM'
    end
  end
end

if __FILE__ == $0
  while fname = ARGV.shift
    dcm = DCM::Reader.new(File.binread(fname))
    tree = dcm.parse
    pp tree
  end
end