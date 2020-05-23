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
# Most interaction with this shard will be through the `Lapper#Lapper` class.
# The main methods are `Lapper#Lapper#find` and `Lapper#Lapper#seek`.
#
# The overlap function for this assumes a zero based genomic coordinate system. So
# [start, stop) is not inclusive of the stop position for neither queries nor the
# `Lapper#Intervals`.
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
# require "Lapper"
#
# # Create some fake data
# data = (0..100).step(by: 20).map { |x| Interval(Int32).new(x, x + 10, 0) }.to_a
#
# # Create the lapper
# lapper = Lapper(Int32).new(data)
#
# # Demo `find`
# lapper = Lapper(Int32).new(data)
# lapper.find(5, 11).size == 2
#
# # Demo `seek` - calculate overlap between queries and the found intervals
# sum = 0
# cursor = 0
# (0..10).step(by: 3).each do |i|
#   sum += lapper.seek(i, i + 2, pointerof(cursor)).map { |iv| Math.min(i + 2, iv.stop) - Math.max(i, iv.start) }.sum
# end
# ```
module Lapper
  VERSION = "0.1.0"

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

  # Helper struct to enable returning a iterator for a query, see `Lapper#find` or `Lapper#seek`
  private struct IterFind(T)
    include Iterator(Interval(T))

    # Create an `IterFind` instance
    def initialize(@inner : Lapper(T), @off : Int32, @last : Int32, @stop : Int32, @start : Int32)
    end

    # Implement `next` for `Iterator(Interval(T))`
    def next
      while @off < @last
        interval = @inner.intervals[@off]
        @off += 1
        if interval.overlap(@start, @stop)
          return interval
        elsif interval.start >= @stop
          stop
        end
      end
      stop
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
      # Find the largest interval in the list
      intervals.each do |interval|
        i_len = interval.stop - interval.start
        if i_len > @max_len
          @max_len = i_len
        end
      end
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
        v = intervals[probe]
        size = half
        low = v.start < start ? other_low : low
      end
      low
    end

    # Find all intervals that overlap start .. stop
    # ```
    # data = (0..100).step(by: 5).map { |x| Interval(Int32).new(x, x + 2, 0) }.to_a
    # lapper = Lapper(Int32).new(data)
    # lapper.find(5, 11).size == 2
    # ```
    def find(start : Int32, stop : Int32)
      IterFind(T).new(
        inner: self,
        off: lower_bound(start - @max_len, @intervals),
        last: @intervals.size,
        start: start,
        stop: stop
      )
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
    #   lapper.seek(i.start, i.stop, pointerof(cursor)).size == 1
    # end
    # ```
    def seek(start : Int32, stop : Int32, cursor : Int32*)
      if cursor.value == 0 || (cursor.value < @intervals.size && @intervals[cursor.value].start > start)
        cursor.value = lower_bound(start - @max_len, @intervals)
      end
      while cursor.value + 1 < @intervals.size && @intervals[cursor.value + 1].start < start - @max_len
        cursor.value += 1
      end
      IterFind.new(
        inner: self,
        off: cursor.value,
        last: @intervals.size,
        start: start,
        stop: stop
      )
    end
  end
end
