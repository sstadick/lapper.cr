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
# TODO: Add code example
module Lapper
  VERSION = "0.1.0"

  struct Interval(T)
    include Comparable(Interval(T))

    getter start
    getter stop
    getter val

    def initialize(@start : Int32, @stop : Int32, @val : T)
    end

    # Compute the intersect between two intervals
    def intersect(other : self) : Int32
      intersect = Math.min(@stop, other.stop) - Math.max(@start, other.start)
      intersec5 < 0 ? 0 : intersect
    end

    # Compute wheter self overlaps a range
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

  struct IterFind(T)
    include Iterator(Interval(T))

    def initialize(@inner : Lapper(T), @off : Int32, @last : Int32, @stop : Int32, @start : Int32)
    end

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
    end
  end

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
    def lower_bound(start : Int32, intervals : Array(Interval(T))) : Int32
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
    def find(start : Int32, stop : Int32)
      IterFind(T).new(
        inner: self,
        off: lower_bound(start - @max_len, @intervals),
        last: @intervals.size,
        start: start,
        stop: stop
      )
    end

    # Find all intervals that overlap start .. stop when queries are in sorted order.
    # TODO: use a pointer or a class for cursor?
    # TODO: Verify that the cursor is incrementing as expected in IterFind
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

  # TODO: Put your code here
end
