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
  sum += lapper.seek(i, i + 2).map { |iv| Math.min(i + 2, iv.stop) - Math.max(i, iv.start) }.sum
end
puts sum
```

## Performance

Has not yet been benchmarked for the Crystal implementation. For other languages this library outperforms [all implementations](https://github.com/sstadick/rust-lapper#benchmarks) when the intervals are not heavily nested. For another Crystal implementation of an interval lib, see [klib.cr](https://github.com/lh3/biofast/blob/master/lib/klib.cr), which is based on the [cgranges](https://github.com/lh3/cgranges) lib by the same author.

### Bench against klib

Benchmarked against the klib.cr implementation and using the script found in `bench/biofast.cr` (uses the `find` with block method).

```text
Benchmark #1: ./bedcov_c1_cgr -c ../biofast-data-v1/ex-rna.bed ../biofast-data-v1/ex-anno.bed > bedcov_c1_cgr.out
  Time (mean ± σ):      3.221 s ±  0.128 s    [User: 3.091 s, System: 0.122 s]
  Range (min … max):    3.075 s …  3.423 s    10 runs

Benchmark #2: ./bedcov_cr1_klib ../biofast-data-v1/ex-rna.bed ../biofast-data-v1/ex-anno.bed > bedcov_cr1_klib.out
  Time (mean ± σ):      8.045 s ±  0.223 s    [User: 5.457 s, System: 2.688 s]
  Range (min … max):    7.764 s …  8.440 s    10 runs

Benchmark #3: bedcov_cr1_lapper/bin/bedcov_cr1_lapper ../biofast-data-v1/ex-rna.bed ../biofast-data-v1/ex-anno.bed > bedcov_cr1_lapper.out
  Time (mean ± σ):      9.591 s ±  0.116 s    [User: 6.966 s, System: 2.751 s]
  Range (min … max):    9.498 s …  9.835 s    10 runs

Summary
  './bedcov_c1_cgr -c ../biofast-data-v1/ex-rna.bed ../biofast-data-v1/ex-anno.bed > bedcov_c1_cgr.out' ran
    2.50 ± 0.12 times faster than './bedcov_cr1_klib ../biofast-data-v1/ex-rna.bed ../biofast-data-v1/ex-anno.bed > bedcov_cr1_klib.out'
    2.98 ± 0.12 times faster than 'bedcov_cr1_lapper/bin/bedcov_cr1_lapper ../biofast-data-v1/ex-rna.bed ../biofast-data-v1/ex-anno.bed > bedcov_cr1_lapper.out'
```

### `find` and `seek` variants on query data sorted by start

```text
      find  13.86  ( 72.17ms) (± 8.03%)  81.5MB/op   1.63× slower
      seek  15.31  ( 65.33ms) (± 4.51%)  81.5MB/op   1.48× slower
find_yield  21.95  ( 45.57ms) (± 5.29%)  1.53MB/op   1.03× slower
seek_yield  22.61  ( 44.23ms) (± 1.52%)  1.53MB/op        fastest
find_share  15.36  ( 65.08ms) (± 3.68%)  81.5MB/op   1.47× slower
seek_share  15.52  ( 64.43ms) (± 4.30%)  81.5MB/op   1.46× slower
```

Note that for more queries than represented here, `seek` should get faster.

The `bench\bench.cr` script is expecting the [this](https://github.com/lh3/biofast/releases/download/biofast-data-v1/biofast-data-v1.tar.gz) data to be in the top top level dir of the repo and untarred.


## Contributing

1. Fork it (<https://github.com/sstadick/lapper.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Seth Stadick](https://github.com/sstadick) - creator and maintainer
