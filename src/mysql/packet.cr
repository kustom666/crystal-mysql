class MySql::Packet
  include IO

  def initialize(@io)
    header :: UInt8[4]
    io.read_fully(header.to_slice)
    @length = @remaining = header[0].to_i + (header[1].to_i << 8) + (header[2].to_i << 16)
    @seq = header[3]
  end

  def to_s(io)
    io << "MySql::Packet[length: " << io << @length << ", seq: " << @seq << ", remaining: " << @remaining << "]"
  end

  def read(slice : Slice(UInt8), count)
    return 0 unless @remaining > 0
    read_bytes = @io.read(slice, count)
    @remaining -= read_bytes
    read_bytes
  end

  def read_byte!
    read_byte || raise "Unexpected EOF"
  end

  def read_string
    String.build do |buffer|
      while (b = read_byte) != 0 && b
        buffer.write_byte b if b
      end
    end
  end

  def read_string(length)
    String.build do |buffer|
      length.times do
        buffer.write_byte read_byte!
      end
    end
  end

  def read_lenenc_string
    length = read_lenenc_int
    read_string(length)
  end

  def read_int
    read_byte!.to_i + (read_byte!.to_i << 8) + (read_byte!.to_i << 16) + (read_byte!.to_i << 24)
  end

  def read_fixed_int(n)
    int = 0
    n.times do |i|
      int += (read_byte!.to_i << (i * 8))
    end
    int
  end

  def read_lenenc_int(h = read_byte!)
    if h < 251
      h.to_i
    elsif h == 0xfc
      read_byte!.to_i + (read_byte!.to_i << 8)
    elsif h == 0xfd
      read_byte!.to_i + (read_byte!.to_i << 8) + (read_byte!.to_i << 16)
    elsif h == 0xfe
      raise "8 byte int not implemented"
    else
      raise "Unexpected int length"
    end
  end

  def read_byte_array(length)
    Array(UInt8).new(length) { |i| read_byte! }
  end

  def read_int_string(length)
    value = 0
    length.times do
      value = value * 10 + read_byte!.chr.to_i
    end
    value
  end

  def discard
    read(@remaining) if @remaining > 0
  end
end
