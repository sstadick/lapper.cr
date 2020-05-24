require "./spec_helper"

alias Iv = Lapper::Interval(Int32)
alias Lp = Lapper::Lapper(Int32)

def setup_nonoverlapping : Lp
  data = (0..100).step(20).map { |x| Iv.new(x, x + 10, 0) }.to_a
  Lp.new(data)
end

def setup_overlapping : Lp
  data = (0..100).step(10).map { |x| Iv.new(x, x + 15, 0) }.to_a
  Lp.new(data)
end

def setup_badlapper : Lp
  data = [
    Iv.new(start: 70, stop: 120, val: 0), # max_len = 50
    Iv.new(start: 10, stop: 15, val: 0),
    Iv.new(start: 10, stop: 15, val: 0), # exact overlap
    Iv.new(start: 12, stop: 15, val: 0), # inner overlap
    Iv.new(start: 14, stop: 16, val: 0), # overlap end
    Iv.new(start: 40, stop: 45, val: 0),
    Iv.new(start: 50, stop: 55, val: 0),
    Iv.new(start: 60, stop: 65, val: 0),
    Iv.new(start: 68, stop: 71, val: 0), # overlap start
    Iv.new(start: 70, stop: 75, val: 0),
  ]
  Lp.new(data)
end

def setup_single : Lp
  data = [Iv.new(10, 35, 0)]
  Lp.new(data)
end

def test_all(lapper : Lp, query : Tuple(Int32, Int32), expected : Array(Iv))
  # array return
  lapper.find(*query).should eq(expected)
  lapper.seek(*query).should eq(expected)

  # block
  result = [] of Iv
  lapper.find(*query) { |iv| result << iv }
  result.should eq(expected)
  result.clear
  lapper.seek(*query) { |iv| result << iv }
  result.should eq(expected)

  # reused array
  ivs = [] of Iv
  lapper.find(*query, ivs)
  ivs.should eq(expected)
  lapper.seek(*query, ivs)
  ivs.should eq(expected)
end

def test_all(lapper : Lp, query : Tuple(Int32, Int32), expected : Iv)
  # array return
  lapper.find(*query)[0]?.should eq(expected)
  lapper.seek(*query)[0]?.should eq(expected)

  # block
  result = [] of Iv
  lapper.find(*query) { |iv| result << iv }
  result[0]?.should eq(expected)
  result.clear
  lapper.seek(*query) { |iv| result << iv }
  result[0]?.should eq(expected)

  # reused array
  ivs = [] of Iv
  lapper.find(*query, ivs)
  ivs[0]?.should eq(expected)
  lapper.seek(*query, ivs)
  ivs[0]?.should eq(expected)
end

describe Lapper do
  describe Lapper::Lapper do
    it "should return nil for a query.stop that hits an interval.start" do
      lapper = setup_nonoverlapping
      query = {15, 20}
      expected = [] of Iv
      test_all(lapper, query, expected)
    end

    it "should return nil for a query.start that hits and interval.stop" do
      lapper = setup_nonoverlapping
      query = {30, 35}
      expected = [] of Iv
      test_all(lapper, query, expected)
    end

    it "should return an interval for a query overlaps the start of the interval" do
      lapper = setup_nonoverlapping
      query = {15, 25}
      expected = Iv.new(20, 30, 0)
      test_all(lapper, query, expected)
    end

    it "should return an iterval if a query overlaps the stop of the interval" do
      lapper = setup_nonoverlapping
      query = {25, 35}
      expected = Iv.new(20, 30, 0)
      test_all(lapper, query, expected)

    end

    it "should reuturn an interval if the query is enveloped by the interval" do
      lapper = setup_nonoverlapping
      expected = Iv.new(20, 30, 0)
      query = {22, 27}
      test_all(lapper, query, expected)

    end

    it "should return an interval if the query envelops the interval" do
      lapper = setup_nonoverlapping
      expected = Iv.new(20, 30, 0)
      query = {20, 30}
      test_all(lapper, query, expected)

    end

    it "should return mulitiple intervals if a query overlaps multiple intervals" do
      lapper = setup_overlapping
      expected = [Iv.new(0, 15, 0), Iv.new(10, 25, 0)]
      query = {8, 20}
      test_all(lapper, query, expected)

    end

    it "should find overlaps in large intervals" do
      data1 = [
        Iv.new(start: 0, stop: 8, val: 0),
        Iv.new(start: 1, stop: 10, val: 0),
        Iv.new(start: 2, stop: 5, val: 0),
        Iv.new(start: 3, stop: 8, val: 0),
        Iv.new(start: 4, stop: 7, val: 0),
        Iv.new(start: 5, stop: 8, val: 0),
        Iv.new(start: 8, stop: 8, val: 0),
        Iv.new(start: 9, stop: 11, val: 0),
        Iv.new(start: 10, stop: 13, val: 0),
        Iv.new(start: 100, stop: 200, val: 0),
        Iv.new(start: 110, stop: 120, val: 0),
        Iv.new(start: 110, stop: 124, val: 0),
        Iv.new(start: 111, stop: 160, val: 0),
        Iv.new(start: 150, stop: 200, val: 0),
      ]
      lapper = Lp.new(data1)
      query = {8, 11}
      expected = [Iv.new(1, 10, 0), Iv.new(9, 11, 0), Iv.new(10, 13, 0)]
      test_all(lapper, query, expected)

      query = {145, 151}
      expected = [

        Iv.new(start: 100, stop: 200, val: 0),
        Iv.new(start: 111, stop: 160, val: 0),
        Iv.new(start: 150, stop: 200, val: 0),
      ]
      test_all(lapper, query, expected)
    end

    # Bug tests from real life bugs
    it "should not induce index out of bound by pushing cursor past end of lapper" do
      lapper = setup_nonoverlapping
      single = setup_single
      cursor = 0
      lapper.intervals.each do |interval|
        single.seek(interval.start, interval.stop).each do |o_interval|
          o_interval.to_s
        end
      end
    end

    it "should return first match if lower_bound puts us before first match" do
      lapper = setup_badlapper
      expected = Iv.new(50, 55, 0)
      query = {50, 55}
      test_all(lapper, query, expected)

    end

    it "should handle long intervals that span many little intervals" do
      data = [
        Iv.new(start: 25264912, stop: 25264986, val: 0),
        Iv.new(start: 27273024, stop: 27273065, val: 0),
        Iv.new(start: 27440273, stop: 27440318, val: 0),
        Iv.new(start: 27488033, stop: 27488125, val: 0),
        Iv.new(start: 27938410, stop: 27938470, val: 0),
        Iv.new(start: 27959118, stop: 27959171, val: 0),
        Iv.new(start: 28866309, stop: 33141404, val: 0),
      ]
      lapper = Lp.new(data)

      query = {28974798, 33141355}
      expected = [Iv.new(start: 28866309, stop: 33141404, val: 0)]
      test_all(lapper, query, expected)

    end
  end

  describe Lapper::Interval do
    it "should intersect an identical interval" do
      iv1 = Iv.new(10, 15, 0)
      iv2 = Iv.new(10, 15, 0)
      iv1.intersect(iv2).should eq 5
    end

    it "should intersect an inner interval" do
      iv1 = Iv.new(10, 15, 0)
      iv2 = Iv.new(12, 15, 0)
      iv1.intersect(iv2).should eq 3
    end
    it "should intersect an interval overlapping endpoint" do
      iv1 = Iv.new(10, 15, 0)
      iv2 = Iv.new(14, 15, 0)
      iv1.intersect(iv2).should eq 1
    end
    it "should intersect an interval overlapping startpoint" do
      iv1 = Iv.new(68, 71, 0)
      iv2 = Iv.new(70, 75, 0)
      iv1.intersect(iv2).should eq 1
    end
    it "should not intersect an interval that doesn't overlap" do
      iv1 = Iv.new(50, 55, 0)
      iv2 = Iv.new(60, 65, 0)
      iv1.intersect(iv2).should eq 0
    end
    it "should not intersect an interval where iv1.stop == iv2.start" do
      iv1 = Iv.new(40, 50, 0)
      iv2 = Iv.new(50, 55, 0)
      iv1.intersect(iv2).should eq 0
    end
    it "should intersect an interval where iv1.start == iv2.start" do
      iv1 = Iv.new(70, 120, 0)
      iv2 = Iv.new(70, 75, 0)
      iv1.intersect(iv2).should eq 5
    end
  end
end
