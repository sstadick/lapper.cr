[![GitHub release](https://img.shields.io/github/release/sstadick/crystal-lapper.svg)](https://github.com/sstadick/lapper.cr/releases)
[![Build Status](https://travis-ci.org/sstadick/crystal-lapper.svg?branch=master)](https://travis-ci.org/sstadick/lapper.cr)
[![GitHub license](https://img.shields.io/github/license/sstadick/lapper.cr.svg)](https://github.com/sstadick/lapper.cr/blob/master/LICENSE)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://GitHub.com/sstadick/lapper.cr/graphs/commit-activity)
[![Docs](https://img.shields.io/badge/Documentation-yes-green.svg)](https://sstadick.github.io/lapper.cr/)

# lapper.cr

This is a Crystal port of Brent Pendersen's [nim-lapper](https://github.com/brentp/nim-lapper). This crate works well for most genomic interval data. It does have a notable worst case scenario when very long regions engulf large percentages of the other intervals. As usual, you should benchmark on your expected data and see how it works.

## Documentation

See [here](https://sstadick.github.io/lapper.cr/)

## Installation

1. Add the dependency to your `shard.yml`

```yml
dependencies:
  lapper:
    github: sstadick/lapper.cr
```

## Usage

```crystal
require "lapper"

# Create some fake data
data = (0..100).step(by: 20).map { |x| Lapper::Interval(Int32).new(x, x + 10, 0) }.to_a

# Create the lapper
lapper = Lapper::Lapper(Int32).new(data)

# Demo `find`
lapper = Lapper::Lapper(Int32).new(data)
lapper.find(5, 11).size == 2

# Demo `seek` - calculate overlap between queries and the found intervals
sum = 0
cursor = 0
(0..10).step(by: 3).each do |i|
  sum += lapper.seek(i, i + 2, pointerof(cursor)).map { |iv| Math.min(i + 2, iv.stop) - Math.max(i, iv.start) }.sum
end
puts sum
```

## Performance

Has not yet been benchmarked for the Crystal implementation. For other languages this library outperforms [all implementations](https://github.com/sstadick/rust-lapper#benchmarks) when the intervals are not heavily nested. For another Crystal implementation of an interval lib, see [klib.cr](https://github.com/lh3/biofast/blob/master/lib/klib.cr), which is based on the [cgranges](https://github.com/lh3/cgranges) lib by the same author.

TODO:

- Benchmark the `seek` and `find` methods against eachother
- Benchmark against naive case like `nim-lapper`
- Benchmakr against klib

## Contributing

1. Fork it (<https://github.com/sstadick/lapper.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Seth Stadick](https://github.com/sstadick) - creator and maintainer
