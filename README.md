# Readable

Inspired by [`Enumerator`](http://ruby-doc.org/core/Enumerator.html), an attempt to provide a generic way of creating an IO-like object from any source.

```ruby
require 'csv'
require 'zlib'

readable = described_class.new do |yielder|
  yielder << "\u001F\x8B\b\u0000[\u0017\x88Z\u0000"
  yielder << "\u0003\xF3H\xCD\xC9\xC9\xD7)\xCF/\xCAI"
  yielder << "\u0001\u0000)^\u0014\xFC\v\u0000\u0000\u0000"
end
gz_reader = Zlib::GzipReader.new(readable)

CSV(gz_reader).gets
#=> ['Hello', 'world']
```

## License

Copyright © 2018 Paul Mucur

Distributed under the MIT License.
