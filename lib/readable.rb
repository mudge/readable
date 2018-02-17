class Readable
  attr_reader :enumerator, :buffer, :eof, :last_read

  def initialize(&blk)
    @enumerator = Enumerator.new(&blk)
    @buffer = ''
    @last_read = nil
    @eof = false
  end

  def seek(amount, whence = IO::SEEK_SET)
    fail NotImplementedError, 'only supports seeking relative to current position' unless whence == IO::SEEK_CUR || whence == :CUR

    buffer.prepend(last_read.byteslice(amount, last_read.bytesize))
  end

  def read
    bytes = ''

    loop do
      bytes << readpartial(1024)
    end
  rescue EOFError
    bytes
  end

  def readpartial(maxlen)
    fail EOFError, 'enumerator ended' if eof && buffer.empty?

    fill_buffer(maxlen)

    @last_read = buffer.byteslice(0, maxlen)
    @buffer = buffer.byteslice(last_read.length, buffer.length)

    last_read
  end

  private

  def fill_buffer(maxlen)
    buffer << enumerator.next until buffer.length > maxlen
  rescue StopIteration
    @eof = true
  end
end
