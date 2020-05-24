require "lapper"
include Lapper

# Run in hyperfine with hyperfine --show-output --warmup 3 --runs 10 --export-markdown results.bedcov.md './bedcov_c1_cgr -c ../biofast-data-v1/ex-rna.bed ../biofast-data-v1/ex-anno.bed > bedcov_c1_cgr.out' './bedcov_cr1_klib ../biofast-data-v1/ex-rna.bed ../biofast-data-v1/ex-anno.bed > bedcov_cr1_klib.out' 'bedcov_cr1_lapper/bin/bedcov_cr1_lapper ../biofast-data-v1/ex-rna.bed ../biofast-data-v1/ex-anno.bed > bedcov_cr1_lapper.out'
if ARGV.size < 2
  puts "Usage: bedcov <loaded.bed> <streamed.bed>"
  exit(0)
end

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

lappers = Hash(String, Lapper::Lapper(Bool)).new
bed.each do |ctg, a|
  lappers[ctg] = Lapper::Lapper.new(a)
end

File.each_line ARGV[1] do |line|
  t = line.split
  if !lappers.has_key?(t[0])
    puts "#{t[0]}\t#{t[1]}\t#{t[2]}\t0\t0"
  else
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
    puts "#{t[0]}\t#{t[1]}\t#{t[2]}\t#{n}\t#{cov}"
  end
end
