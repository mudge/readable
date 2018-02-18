# Readable

Inspired by [`Enumerator`](http://ruby-doc.org/core/Enumerator.html), an attempt to provide a generic way of creating an IO-like object from any source.

```ruby
require 'csv'
require 'zlib'

readable = Readable.new do |yielder|
  yielder << "\u001F\x8B\b\u0000[\u0017\x88Z\u0000"
  yielder << "\u0003\xF3H\xCD\xC9\xC9\xD7)\xCF/\xCAI"
  yielder << "\u0001\u0000)^\u0014\xFC\v\u0000\u0000\u0000"
end
gz_reader = Zlib::GzipReader.new(readable)

CSV(gz_reader).gets
#=> ['Hello', 'world']
```

## Why?

This came from a problem at [work](https://www.altmetric.com) where we needed to do the following:

1. Download a series of large, compressed JSON files from S3
2. Uncompress each file
3. Parse JSON out of them, saving each parsed object to a database

I wished we could do each of these things lazily so we only download as much as we needed to uncompress and only uncompress enough to parse and only parse as much as we need to save to the database.

Tantalisingly, each step of this process offered _some_ form of streaming interface, e.g. the S3 client allows you to read objects in chunks:

```ruby
s3_client.get_object do |chunk|
  # do something with chunk
end
```

And Ruby's standard library has a [`GzipReader`](http://ruby-doc.org/stdlib/libdoc/zlib/rdoc/Zlib/GzipReader.html) that supports uncompressing a compressed [`IO`](http://ruby-doc.org/core/IO.html) object a line at a time.

```ruby
reader = Zlib::GzipReader.new(io)
reader.each_line do |line|
  # do something with line
end
```

Many JSON libraries support passing an `IO` object as an input source and some support yielding objects as they are parsed.

As a lot of libraries report supporting an "IO-like" object, the missing piece is being able to turn something like the S3 client interface into an IO. I was hoping there'd be an interface like Ruby's [`Enumerable`](https://ruby-doc.org/core/Enumerable.html) (where you need only implement `each`) but for creating your own `IO`-compatible class. Sadly, this doesn't seem to exist and the IO interface is pretty large.

Inspired by [`Enumerator`](https://ruby-doc.org/core/Enumerator.html), I wanted to provide the easiest possible way to convert any streaming input source into an `IO` and tried to reverse engineer exactly which methods on `IO` classes like `CSV` and `Zlib::GzipReader` actually use.

While I had [some success](https://github.com/mudge/readable/blob/master/spec/readable_spec.rb#L7-L28), usage of `IO` methods is pretty inconsistent. Yajl has [its own wrapper for `GzipReader`](https://github.com/brianmario/yajl-ruby/blob/master/lib/yajl/gzip/stream_reader.rb) because its `read` implementation does not match `IO`'s. More damningly, you can't plug together a `Zlib::GzipReader` and the default `JSON` parser as `Zlib::GzipReader#to_io` returns the inner, compressed source and not an `IO`-compatible object as intended.

If there was a smaller, well-defined interface for `IO` (ala `Enumerable`) then it might be more ergonomic to model everything as a stream that you can glue together but for now this is a bit of a failed experiment.

## License

Copyright © 2018 Paul Mucur

Distributed under the MIT License.
