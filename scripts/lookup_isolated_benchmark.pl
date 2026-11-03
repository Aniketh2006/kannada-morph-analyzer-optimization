#!/usr/bin/perl
# lookup_isolated_benchmark.pl -- hash lookup vs binary search, LOADING EXCLUDED.
#
# Why this exists: in the loader benchmarks the sorted-file/binary-search
# workflow wins mainly because the sorted file is pre-processed (no per-line
# parsing, no hash construction). That says nothing about whether the search
# itself is faster. Here both structures are built once, outside the timer,
# and only the lookups are timed.
#
# Both loops are written inline (no sub-call overhead on either side).
# Queries: 90% dictionary roots, 10% guaranteed misses; fixed seed.
#
# Usage (repository root):  perl scripts/lookup_isolated_benchmark.pl [tag=run]
use strict;
use warnings;
use Time::HiRes qw(gettimeofday tv_interval);

my $tag = shift(@ARGV) || 'run';
open(my $fh, '<', 'dict_all.txt') or die "dict_all.txt: $!";
my %h;
while (my $line = <$fh>) {
    $line =~ tr/\r\n//d;
    next if $line eq '' || substr($line, 0, 1) eq '#';
    my ($w, $pos, $para) = split(/,/, $line, 4);
    next unless defined $w && $w =~ /\S/;
    my $v = (defined $pos ? $pos : '') . (defined $para ? $para : '');
    $h{$w} = exists $h{$w} ? "$h{$w},$v" : $v;
}
close $fh;
my @keys = sort keys %h;
my @vals = @h{@keys};
my $n_dict = @keys;
printf "dictionary: %d unique roots (built once, excluded from timing)\n\n", $n_dict;

srand(20261016);
my %plan = (100 => 10, 10_000 => 10, 1_000_000 => 5);   # queries => runs
open(my $csv, '>', "result_lookup_isolated_$tag.csv") or die $!;
print $csv "queries,run,first,hash_ms,binary_ms,hits_hash,hits_binary\n";
printf "%10s %5s %12s %12s %10s %10s\n", 'queries', 'runs', 'hash ms', 'binary ms', 'ns/q hash', 'ns/q bin';

for my $n (sort { $a <=> $b } keys %plan) {
    my @q = map { rand() < 0.9 ? $keys[int(rand($n_dict))] : $keys[int(rand($n_dict))] . 'zz' } 1 .. $n;
    my (@th, @tb);
    for my $run (1 .. $plan{$n}) {
        my %ms; my %hits;
        for my $m ($run % 2 ? qw(hash binary) : qw(binary hash)) {
            my $found = 0;
            my $t0 = [gettimeofday];
            if ($m eq 'hash') {
                for my $w (@q) { $found++ if exists $h{$w}; }
            } else {
                for my $w (@q) {
                    my ($lo, $hi) = (0, $#keys);
                    while ($lo <= $hi) {
                        my $mid = int(($lo + $hi) / 2);
                        my $c = $keys[$mid] cmp $w;
                        if    ($c == 0) { $found++; last }
                        elsif ($c > 0)  { $hi = $mid - 1 }
                        else            { $lo = $mid + 1 }
                    }
                }
            }
            $ms{$m} = tv_interval($t0) * 1000; $hits{$m} = $found;
        }
        die "hit counts differ ($hits{hash} vs $hits{binary})\n" if $hits{hash} != $hits{binary};
        printf $csv "%d,%d,%s,%.4f,%.4f,%d,%d\n", $n, $run, ($run % 2 ? 'hash' : 'binary'),
                    $ms{hash}, $ms{binary}, $hits{hash}, $hits{binary};
        push @th, $ms{hash}; push @tb, $ms{binary};
    }
    my ($mh, $mb) = (0, 0); $mh += $_ for @th; $mb += $_ for @tb; $mh /= @th; $mb /= @tb;
    printf "%10d %5d %12.4f %12.4f %10.1f %10.1f\n", $n, scalar @th, $mh, $mb, 1e6 * $mh / $n, 1e6 * $mb / $n;
}
close $csv;
print "\nsaved: result_lookup_isolated_$tag.csv\n";
