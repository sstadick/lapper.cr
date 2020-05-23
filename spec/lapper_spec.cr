require "./spec_helper"

alias Iv = Lapper::Interval(Int32)
alias Lp = Lapper::Lapper(Int32)

def setup_nonoverlapping : Lp
  data = (0..100).step(20).map { |x| Iv.new(x, x + 10, 0) }
  Lp.new(data.to_a)
end

def setup_overlapping : Lp
  data = (0..100).step(10).map { |x| Iv.new(x, x + 15, 0) }
  Lp.new(data.to_a)
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

describe Lapper do
  describe Lapper::Lapper do
    it "should return nil for a query.stop that hits an interval.start" do
      lapper = setup_nonoverlapping
      cursor = 0
      lapper.find(15, 20).next.should be_a(Iterator::Stop)
      lapper.find_fast(15, 20)[0]?.should eq(nil)
      lapper.seek(15, 20, pointerof(cursor)).next.should be_a(Iterator::Stop)
    end

    it "should return nil for a query.start that hits and interval.stop" do
      lapper = setup_nonoverlapping
      cursor = 0
      lapper.find(30, 35).next.should be_a(Iterator::Stop)
      lapper.find_fast(30, 35)[0]?.should eq(nil)
      lapper.seek(30, 35, pointerof(cursor)).next.should be_a(Iterator::Stop)
    end

    it "should return an interval for a query overlaps the start of the interval" do
      lapper = setup_nonoverlapping
      cursor = 0
      expected = Iv.new(20, 30, 0)
      lapper.find(15, 25).next.should eq(expected)
      lapper.find_fast(15, 25)[0]?.should eq(expected)
      lapper.seek(15, 25, pointerof(cursor)).next.should eq(expected)
    end

    it "should return an iterval if a query overlaps the stop of the interval" do
      lapper = setup_nonoverlapping
      cursor = 0
      expected = Iv.new(20, 30, 0)
      lapper.find(25, 35).next.should eq(expected)
      lapper.find_fast(25, 35)[0]?.should eq(expected)
      lapper.seek(25, 35, pointerof(cursor)).next.should eq(expected)
    end

    it "should reuturn an interval if the query is enveloped by the interval" do
      lapper = setup_nonoverlapping
      cursor = 0
      expected = Iv.new(20, 30, 0)
      lapper.find(22, 27).next.should eq expected
      lapper.find_fast(22, 27)[0]?.should eq expected
)
      lapper.seek(22, 27, pointerof(cursor)).next.should eq expected
    end

    it "should return an interval if the query envelops the interval" do
      lapper = setup_nonoverlapping
      cursor = 0
      expected = Iv.new(20, 30, 0)
      lapper.find(15, 35).next.should eq expected
      lapper.find_fast(15, 35)[0]?.should eq expected
      lapper.seek(15, 35, pointerof(cursor)).next.should eq expected
    end

    it "should return mulitiple intervals if a query overlaps multiple intervals" do
      lapper = setup_overlapping
      cursor = 0
      expected = [Iv.new(0, 15, 0), Iv.new(10, 25, 0)]
      lapper.find(8, 20).to_a.should eq expected
      lapper.find_fast(8, 20).should eq expected
      lapper.seek(8, 20, pointerof(cursor)).to_a.should eq expected
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
      found = lapper.find(8, 11).to_a
      found.should eq [Iv.new(1, 10, 0), Iv.new(9, 11, 0), Iv.new(10, 13, 0)]
      found = lapper.find(145, 151).to_a
      found.should eq [
        Iv.new(start: 100, stop: 200, val: 0),
        Iv.new(start: 111, stop: 160, val: 0),
        Iv.new(start: 150, stop: 200, val: 0),
      ]
    end

    # Bug tests from real life bugs
    it "should not induce index out of bound by pushing cursor past end of lapper" do
      lapper = setup_nonoverlapping
      single = setup_single
      cursor = 0
      lapper.intervals.each do |interval|
        single.intervals.each do |o_interval|
          o_interval.to_s
        end
      end
    end

    it "should return first match if lower_bound puts us before first match" do
      lapper = setup_badlapper
      e1 = Iv.new(50, 55, 0)
      found = lapper.find(50, 55).next
      found.should eq e1
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
      lapper.find(28974798, 33141355).to_a.should eq [Iv.new(start: 28866309, stop: 33141404, val: 0)]
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
