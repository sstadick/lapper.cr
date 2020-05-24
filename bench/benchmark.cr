require "benchmark"
require "../src/lapper.cr"
include Lapper

if ARGV.size < 2
  puts "Usage: bench <loaded.bed> <streamed.bed>"
  exit(0)
end

# build up lists of intervals
bed = Hash(String, Array(Interval(Bool))).new
i = 0
File.each_line ARGV[0] do |line|
  t = line.split
  if !bed.has_key?(t[0])
    bed[t[0]] = Array(Interval(Bool)).new
  end
  i += 1
  bed[t[0]].push(Interval.new(t[1].to_i, t[2].to_i, false))
end

# Create a lapper for each contig
lappers = Hash(String, Lapper::Lapper(Bool)).new
bed.each do |ctg, a|
  lappers[ctg] = Lapper::Lapper.new(a)
end

lines = File.read_lines(ARGV[1])[0..10_000]
# Test speed of getting coverage using different methods on first 10_000 lines
Benchmark.ips do |x|
  x.report("find") {
    lines.each do |line|
      t = line.split
      if lappers.has_key?(t[0])
        st0, en0 = t[1].to_i, t[2].to_i
        cov_st, cov_en, cov, n = 0, 0, 0, 0
        lappers[t[0]].find(st0, en0).each do |iv|
          n += 1
          st1 = iv.start > st0 ? iv.start : st0
          en1 = iv.stop < en0 ? iv.stop : en0
          if st1 > cov_en
            cov += cov_en - cov_st
            cov_st, cov_en = st1, en1
          else
            cov_en = en1 if cov_en < en1
          end
        end
        cov += cov_en - cov_st
      end
    end
  }

  x.report("seek") {
    lines.each do |line|
      t = line.split
      if lappers.has_key?(t[0])
        st0, en0 = t[1].to_i, t[2].to_i
        cov_st, cov_en, cov, n = 0, 0, 0, 0
        lappers[t[0]].find(st0, en0).each do |iv|
          n += 1
          st1 = iv.start > st0 ? iv.start : st0
          en1 = iv.stop < en0 ? iv.stop : en0
          if st1 > cov_en
            cov += cov_en - cov_st
            cov_st, cov_en = st1, en1
          else
            cov_en = en1 if cov_en < en1
          end
        end
        cov += cov_en - cov_st
      end
    end
  }

  x.report("find_yield") {
    lines.each do |line|
      t = line.split
      if lappers.has_key?(t[0])
        st0, en0 = t[1].to_i, t[2].to_i
        cov_st, cov_en, cov, n = 0, 0, 0, 0
        lappers[t[0]].find(st0, en0) do |iv|
          n += 1
          st1 = iv.start > st0 ? iv.start : st0
          en1 = iv.stop < en0 ? iv.stop : en0
          if st1 > cov_en
            cov += cov_en - cov_st
            cov_st, cov_en = st1, en1
          else
            cov_en = en1 if cov_en < en1
          end
        end
        cov += cov_en - cov_st
      end
    end
  }
  x.report("seek_yield") {
    lines.each do |line|
      t = line.split
      if lappers.has_key?(t[0])
        st0, en0 = t[1].to_i, t[2].to_i
        cov_st, cov_en, cov, n = 0, 0, 0, 0
        lappers[t[0]].seek(st0, en0) do |iv|
          n += 1
          st1 = iv.start > st0 ? iv.start : st0
          en1 = iv.stop < en0 ? iv.stop : en0
          if st1 > cov_en
            cov += cov_en - cov_st
            cov_st, cov_en = st1, en1
          else
            cov_en = en1 if cov_en < en1
          end
        end
        cov += cov_en - cov_st
      end
    end
  }

  x.report("find_share") {
    lines.each do |line|
      t = line.split
      ivs = [] of Interval(Bool)
      if lappers.has_key?(t[0])
        st0, en0 = t[1].to_i, t[2].to_i
        cov_st, cov_en, cov, n = 0, 0, 0, 0
        lappers[t[0]].find(st0, en0, ivs)
        ivs.each do |iv|
          n += 1
          st1 = iv.start > st0 ? iv.start : st0
          en1 = iv.stop < en0 ? iv.stop : en0
          if st1 > cov_en
            cov += cov_en - cov_st
            cov_st, cov_en = st1, en1
          else
            cov_en = en1 if cov_en < en1
          end
        end
        cov += cov_en - cov_st
      end
    end
  }
  x.report("seek_share") {
    lines.each do |line|
      t = line.split
      ivs = [] of Interval(Bool)
      if lappers.has_key?(t[0])
        st0, en0 = t[1].to_i, t[2].to_i
        cov_st, cov_en, cov, n = 0, 0, 0, 0
        lappers[t[0]].seek(st0, en0, ivs)
        ivs.each do |iv|
          n += 1
          st1 = iv.start > st0 ? iv.start : st0
          en1 = iv.stop < en0 ? iv.stop : en0
          if st1 > cov_en
            cov += cov_en - cov_st
            cov_st, cov_en = st1, en1
          else
            cov_en = en1 if cov_en < en1
          end
        end
        cov += cov_en - cov_st
      end
    end
  }
end
