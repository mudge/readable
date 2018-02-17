require 'csv'
require 'oj'
require 'readable'
require 'zlib'

RSpec.describe Readable do
  it 'can be used to lazily parse compressed CSV' do
    readable = described_class.new do |yielder|
      yielder << "\u001F\x8B\b\u0000[\u0017\x88Z\u0000"
      yielder << "\u0003\xF3H\xCD\xC9\xC9\xD7)\xCF/\xCAI"
      yielder << "\u0001\u0000)^\u0014\xFC\v\u0000\u0000\u0000"
    end
    gz_reader = Zlib::GzipReader.new(readable)
    csv_parser = CSV(gz_reader)

    expect(csv_parser.gets).to eq(['Hello', 'world'])
  end

  it 'can be used to lazily parse compressed JSON' do
    readable = described_class.new do |yielder|
      yielder << "\u001F\x8B\b\u0000\xC74\x88Z\u0000"
      yielder << "\u0003\xABVJ\xCB\xCFW\xB2RJJ,R\xAA"
      yielder << "\u0005\u0000\xEF\xF5+\xFE\r\u0000\u0000\u0000"
    end
    gz_reader = Zlib::GzipReader.new(readable)
    json = Oj.load(gz_reader)

    expect(json).to eq('foo' => 'bar')
  end

  describe '.new' do
    it 'returns an object that can be read' do
      readable = described_class.new do |yielder|
        yielder << 'Some'
        yielder << ' data!'
      end

      expect(readable.read).to eq('Some data!')
    end

    it 'returns an object that can be partially read' do
      readable = described_class.new do |yielder|
        yielder << 'Some'
        yielder << ' data!'
      end

      expect(readable.readpartial(4)).to eq('Some')
    end
  end

  describe '#seek' do
    it 'allows rewinding the last read' do
      readable = described_class.new do |yielder|
        yielder << 'Foo'
        yielder << 'bar'
      end
      readable.readpartial(3)
      readable.seek(-3, IO::SEEK_CUR)

      expect(readable.readpartial(3)).to eq('Foo')
    end

    it 'allows rewinding part of the last read' do
      readable = described_class.new do |yielder|
        yielder << 'Foo'
        yielder << 'bar'
      end
      readable.readpartial(3)
      readable.seek(-2, IO::SEEK_CUR)

      expect(readable.readpartial(3)).to eq('oob')
    end

    it 'allows rewinding at the end of the file' do
      readable = described_class.new do |yielder|
        yielder << 'Foo'
        yielder << 'bar'
      end
      readable.readpartial(1024)
      readable.seek(-6, IO::SEEK_CUR)

      expect(readable.readpartial(3)).to eq('Foo')
    end

    it 'does not support seeking from the end' do
      readable = described_class.new do |yielder|
        yielder << 'Foo'
      end

      expect { readable.seek(-1, IO::SEEK_END) }.to raise_error(NotImplementedError)
    end

    it 'does not support seeking absolutely' do
      readable = described_class.new do |yielder|
        yielder << 'Foo'
      end

      expect { readable.seek(-1, IO::SEEK_SET) }.to raise_error(NotImplementedError)
    end
  end

  describe '#read' do
    it 'returns the full string' do
      readable = described_class.new do |yielder|
        yielder << 'Some'
        yielder << ' data!'
      end

      expect(readable.read).to eq('Some data!')
    end

    it 'returns an empty string at the end of the file' do
      readable = described_class.new do |yielder|
        yielder << 'Foo'
      end
      readable.readpartial(3)

      expect(readable.read).to eq('')
    end
  end

  describe '#readpartial' do
    it 'returns less than the maxlen if there is nothing more to read' do
      readable = described_class.new do |consumer|
        consumer << 'Fo'
        consumer << 'o'
      end

      expect(readable.readpartial(1024)).to eq('Foo')
    end

    it 'returns no more than the maxlen' do
      readable = described_class.new do |consumer|
        consumer << 'Foo'
        consumer << 'bar'
      end

      expect(readable.readpartial(3)).to eq('Foo')
    end

    it 'returns bytes, not characters' do
      readable = described_class.new do |consumer|
        consumer << 'é'
      end

      expect(readable.readpartial(1)).to eq("\xC3")
    end

    it 'can be called multiple times to read off byteslices' do
      readable = described_class.new do |consumer|
        consumer << 'Foobar'
      end
      readable.readpartial(3)

      expect(readable.readpartial(3)).to eq('bar')
    end

    it 'returns an EOF error once the content is finished' do
      readable = described_class.new do |consumer|
        consumer << 'Foo'
      end
      readable.readpartial(3)

      expect { readable.readpartial(3) }.to raise_error(EOFError)
    end
  end
end
