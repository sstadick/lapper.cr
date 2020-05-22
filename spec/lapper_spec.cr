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
  it "Query stop that hits an interval start returns nil" do
    lapper = setup_nonoverlapping
    cursor = 0
    lapper.find(15, 20).next.should eq(nil)
    lapper.seek(15, 20, pointerof(cursor)).next.should eq(nil)
  end

  it "Query start that hits an interval end returns nil" do
    lapper = setup_nonoverlapping
    cursor = 0
    lapper.find(30, 35).next.should eq(nil)
    lapper.seek(30, 35, pointerof(cursor)).next.should eq(nil)
  end

  it "Query that overlaps start of Iv returns that Iv" do
    lapper = setup_nonoverlapping
    cursor = 0
    expected = Iv.new(20, 30, 0)
    lapper.find(15, 25).next.should eq(expected)
    lapper.seek(15, 25, pointerof(cursor)).next.should eq(expected)
  end
end
