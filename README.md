[![GitHub release](https://img.shields.io/github/release/sstadick/crystal-lapper.svg)](https://github.com/sstadick/crystal-lapper/releases)
[![Build Status](https://travis-ci.org/sstadick/crystal-lapper.svg?branch=master)](https://travis-ci.org/sstadick/crystal-lapper)

# Lapper

This is a Crystal port of Brent Pendersen's [nim-lapper](https://github.com/brentp/nim-lapper). This crate works well for most genomic interval data. It does have a notable worst case scenario when very long regions engulf large percentages of the other intervals. As usual, you should benchmark on your expected data and see how it works.

## Installation

TODO: Write installation instructions here

## Usage

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/sethrad/lapper/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Seth Stadick](https://github.com/sethrad) - creator and maintainer

## TODOs

- Clean up docs so that they link to each-other
- Add high level docs to readme
- Figure out how to publish as a shard
- Make sure code examples work / check other ways of doing that?
