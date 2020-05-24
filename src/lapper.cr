# This module provides a simple data-structure for fast interval searches.
# ## Features
# - Extremely fast on most genomic datasets.
# - Extremly fast on in order queries.
#
# Example query:
# ```text
#       0  1  2  3  4  5  6  7  8  9  10 11
# (0,10]X  X  X  X  X  X  X  X  X  X
# (2,5]       X  X  X
# (3,8]          X  X  X  X  X
# (3,8]          X  X  X  X  X
# (3,8]          X  X  X  X  X
# (3,8]          X  X  X  X  X
# (5,9]                X  X  X  X
# (8,11]                        X  X  X
#
# Query: (8, 11]
# Answer: ((0,10], (5,9], (8,11])
# ```
#
# Most interaction with this shard will be through the `Lapper` class.
# The main methods are `Lapper#find` and `Lapper#seek`.
#
# The overlap function for this assumes a zero based genomic coordinate system. So
# [start, stop) is not inclusive of the stop position for neither queries nor the
# `Intervals`.
#
# Lapper does not use an interval tree, instead, it operates on the assumtion that most intervals are
# of similar length; or, more exactly, that the longest interval in the set is not long compred to
# the average distance between intervals.
#
# For cases where this holds true (as it often does with genomic data), we can sort by start and
# use binary search on the starts, accounting for the length of the longest interval. The advantage
# of this approach is simplicity of implementation and speed. In realistic tests queries returning
# the overlapping intervals are 1000 times faster than brute force and queries that merely check
# for the overlaps are > 5000 times faster.
#
# # Examples
# ```
# require "lapper"
#
# # Create some fake data
# data = (0..100).step(by: 20).map { |x| Lapper::Interval(Int32).new(x, x + 10, 0) }.to_a
#
# # Create the lapper
# lapper = Lapper::Lapper(Int32).new(data)
#
# # Demo `find`
# lapper = Lapper::Lapper(Int32).new(data)
# lapper.find(5, 11).size == 2
#
# # Demo `seek` - calculate overlap between queries and the found intervals
# sum = 0
# cursor = 0
# (0..10).step(by: 3).each do |i|
#   sum += lapper.seek(i, i + 2).map { |iv| Math.min(i + 2, iv.stop) - Math.max(i, iv.start) }.sum
# end
# ```
module Lapper
  VERSION = "1.1.0"

  # Represent an interval that can hold a *val* of any type
  struct Interval(T)
    include Comparable(Interval(T))

    getter start
    getter stop
    getter val

    # Creates an `Interval`
    # ```
    # iv = Interval(String).new(5, 10, "chr1")
    # ```
    def initialize(@start : Int32, @stop : Int32, @val : T)
    end

    # Compute the intersect between two intervals
    # ```
    # iv = Interval(Int32).new(0, 5, 0)
    # iv.intersect(Interval(Int32).new(4, 6, 0)) # => 1
    # ```
    def intersect(other : self) : Int32
      intersect = Math.min(@stop, other.stop) - Math.max(@start, other.start)
      intersect < 0 ? 0 : intersect
    end

    # Compute wheter self overlaps a range
    # ```
    # iv = Interval(Int32).new(0, 5, 0)
    # iv.overlap(4, 6) # => true
    # ```
    def overlap(start : Int32, stop : Int32) : Bool
      @start < stop && @stop > start
    end

    # Compare two intervals
    def <=>(other : self)
      if @start < other.start
        -1
      elsif other.start < @start
        1
      else
        @stop <=> other.stop
      end
    end
  end

  # Lapper is the primary data structure that contains the sorted Array of `Interval(T)`
  # ```
  # data = (0..100).step(by: 20).map { |x| Interval(Int32).new(x, x + 10, 0) }.to_a
  # lapper = Lapper(Int32).new(data)
  # ```
  class Lapper(T)
    getter intervals : Array(Interval(T))

    def initialize(@intervals : Array(Interval(T)), @cursor : Int32 = 0, @max_len : Int32 = 0)
      @intervals.sort!
      @cursor = 0
      # Find the largest interval in the list
      max_iv = intervals.max_by { |iv| iv.stop - iv.start }
      @max_len = max_iv.stop - max_iv.start
    end

    # Determine the first index that we should start checkinf for overlaps for via binary search
    protected def lower_bound(start : Int32, intervals : Array(Interval(T))) : Int32
      size = intervals.size
      low = 0
      while size > 0
        half = size // 2
        other_half = size - half
        probe = low + half
        other_low = low + other_half
        v = intervals.unsafe_fetch(probe)
        size = half
        low = v.start < start ? other_low : low
      end
      low
    end

    # Find all intervals that overlap start .. stop.
    # Returns a new array for each query.
    # ```
    # data = (0..100).step(by: 5).map { |x| Interval(Int32).new(x, x + 2, 0) }.to_a
    # lapper = Lapper(Int32).new(data)
    # lapper.find(5, 11).size == 2
    # ```
    def find(start : Int32, stop : Int32)
      result = [] of Interval(T)
      off = lower_bound(start - @max_len, @intervals)
      while off < @intervals.size
        interval = @intervals.unsafe_fetch(off)
        off += 1
        if interval.overlap(start, stop)
          result << interval
        elsif interval.start >= stop
          break
        end
      end
      result
    end

    # Find all intervals that overlap start .. stop.
    # Reuses an passed in array.
    # ```
    # data = (0..100).step(by: 5).map { |x| Interval(Int32).new(x, x + 2, 0) }.to_a
    # lapper = Lapper(Int32).new(data)
    # lapper.find(5, 11, [] of Interval(Int32)).size == 2
    # ```
    def find(start : Int32, stop : Int32, ivs : Array(Interval(T)))
      if ivs.size != 0
        ivs.clear
      end
      off = lower_bound(start - @max_len, @intervals)
      while off < @intervals.size
        interval = @intervals.unsafe_fetch(off)
        off += 1
        if interval.overlap(start, stop)
          ivs << interval
        elsif interval.start >= stop
          break
        end
      end
    end

    # Find all intervals that overlap start .. stop.
    # Takes a block that accepts an interval.
    # ```
    # data = (0..100).step(by: 5).map { |x| Interval(Int32).new(x, x + 2, 0) }.to_a
    # lapper = Lapper(Int32).new(data)
    # total = 0
    # lapper.find(5, 11) { |iv| total += 1 }
    # total # => 2
    # ```
    def find(start : Int32, stop : Int32, &block)
      off = lower_bound(start - @max_len, @intervals)
      while off < @intervals.size
        interval = @intervals.unsafe_fetch(off)
        off += 1
        if interval.overlap(start, stop)
          yield interval
        elsif interval.start >= stop
          break
        end
      end
    end

    # Find all intervals that overlap start .. stop when queries are in sorted (by start) order.
    # It uses a linear search from the last query instead of a binary search. A reference to a
    # cursor must be passed in. This reference will be modified and should be reused in the next
    # query. This allows seek to not need to make mutate the lapper itself and be useable across
    # threads.
    # ```
    # data = (0..100).step(by: 5).map { |x| Interval(Int32).new(x, x + 2, 0) }.to_a
    # lapper = Lapper(Int32).new(data)
    # cursor = 0
    # lapper.intervals.each do |i|
    #   lapper.seek(i.start, i.stop).size == 1
    # end
    # ```
    def seek(start : Int32, stop : Int32)
      if @cursor == 0 || @cursor >= @intervals.size || @intervals[@cursor].start > start
        @cursor = lower_bound(start - @max_len, @intervals)
      end
      while (@cursor + 1) < @intervals.size && @intervals[@cursor + 1].start < (start - @max_len)
        @cursor += 1
      end
      result = [] of Interval(T)
      intervals[@cursor..].each do |interval|
        if interval.overlap(start, stop)
          result << interval
        elsif interval.start >= stop
          break
        end
      end
      result
    end

    # Find all intervals that overlap start .. stop when queries are in sorted (by start) order.
    # This variant takes a block that will be called for each found interval.
    # ```
    # data = (0..100).step(by: 5).map { |x| Interval(Int32).new(x, x + 2, 0) }.to_a
    # lapper = Lapper(Int32).new(data)
    # cursor = 0
    # lapper.intervals.each do |i|
    #   size = 0
    #   lapper.seek(i.start, i.stop) { |iv| size += 1 }
    #   size == 1
    # end
    # ```
    def seek(start : Int32, stop : Int32, &block)
      if @cursor == 0 || @cursor >= @intervals.size || @intervals[@cursor].start > start
        @cursor = lower_bound(start - @max_len, @intervals)
      end
      while (@cursor + 1) < @intervals.size && @intervals[@cursor + 1].start < (start - @max_len)
        @cursor += 1
      end
      intervals[@cursor..].each do |interval|
        if interval.overlap(start, stop)
          yield interval
        elsif interval.start >= stop
          break
        end
      end
    end

    # Find all intervals that overlap start .. stop when queries are in sorted (by start) order.
    # This variant adds to an array ref that is passed in.
    # ```
    # data = (0..100).step(by: 5).map { |x| Interval(Int32).new(x, x + 2, 0) }.to_a
    # lapper = Lapper(Int32).new(data)
    # cursor = 0
    # ivs = [] of Interval(Int32)
    # lapper.intervals.each do |i|
    #   lapper.seek(i.start, i.stop, ivs)
    #   ivs.size == 1
    # end
    # ```
    def seek(start : Int32, stop : Int32, ivs : Array(Interval(T)))
      if ivs.size != 0
        ivs.clear
      end
      if @cursor == 0 || @cursor >= @intervals.size || @intervals[@cursor].start > start
        @cursor = lower_bound(start - @max_len, @intervals)
      end
      while (@cursor + 1) < @intervals.size && @intervals[@cursor + 1].start < (start - @max_len)
        @cursor += 1
      end
      intervals[@cursor..].each do |interval|
        if interval.overlap(start, stop)
          ivs << interval
        elsif interval.start >= stop
          break
        end
      end
    end
  end
end
