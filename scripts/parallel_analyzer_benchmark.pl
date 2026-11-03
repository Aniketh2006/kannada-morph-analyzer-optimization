#!/usr/bin/perl
# parallel_analyzer_benchmark.pl -- the multicore test on the REAL analyzer.
#
# The dictionary-lookup MCE test never touches the analyzer's analysis loop.
# This script does what the analyzer itself cannot: it partitions a batch of
# words into contiguous chunks, runs one complete analyzer PROCESS per chunk
# (MCE manages the workers), then joins the chunk outputs in the original
# order. Each process has its own interpreter, so the analyzer's global
# variables and its dictionary hashes are never shared and need no refactoring.
# Cost: every process re-loads the dictionary (this is part of the measurement).
#
# Correctness gate: joined parallel output must equal the serial output
# (CR stripped) for every configuration, otherwise the script stops.
#
# Usage (repository root):  perl scripts/parallel_analyzer_benchmark.pl [tag=run]
# Workload sizes are formed by cycling random_words_100.txt (a limitation:
# repeated words; use a larger real corpus for the final paper if available).
use strict;
use warnings;
use File::Spec;
use Time::HiRes qw(gettimeofday tv_interval);
use MCE;

my $tag  = shift(@ARGV) || 'run';
my $null = File::Spec->devnull();
my $perl = $^X;
my $prog = 'morph_kan.pl';
my @sizes   = $ENV{PA_SIZES} ? split(/,/, $ENV{PA_SIZES}) : (100, 1000, 5000);
my @workers = (1, 2, 4, 8);
my $runs    = $ENV{PA_RUNS} || 5;

open(my $wf, '<', 'random_words_100.txt') or die "random_words_100.txt: $!";
my @base = grep { length } map { s/[\r\n]+//gr } <$wf>;
close $wf;

sub write_lines { my ($f, @l) = @_; open(my $h, '>', $f) or die $!; print $h "$_\n" for @l; close $h }
sub slurp_nocr  { my ($f) = @_; open(my $h, '<', $f) or die $!; binmode $h; local $/; my $s = <$h>; $s =~ s/\r//g; $s }

sub run_parallel {
    my ($k, @words) = @_;
    my $per = int(@words / $k) + (@words % $k ? 1 : 0);
    my @chunks;
    for my $i (0 .. $k - 1) {
        my $s = $i * $per;
        last if $s > $#words;
        my $e = ($i + 1) * $per - 1;
        $e = $#words if $e > $#words;
        write_lines("pa_in_$i.tmp", @words[$s .. $e]);
        push @chunks, $i;
    }
    my $t0 = [gettimeofday];
    if (@chunks == 1) {
        system(qq{"$perl" $prog < pa_in_0.tmp > pa_out_0.tmp 2> $null}) == 0 or die "analyzer failed\n";
    } else {
        my $mce = MCE->new(max_workers => scalar(@chunks), chunk_size => 1,
            user_func => sub {
                my ($m, $ref) = @_;
                my $i = $ref->[0];
                system(qq{"$perl" $prog < pa_in_$i.tmp > pa_out_$i.tmp 2> $null}) == 0
                    or die "analyzer failed on chunk $i\n";
            });
        $mce->process(\@chunks);
        $mce->shutdown;
    }
    my $ms = tv_interval($t0) * 1000;
    my $joined = join('', map { slurp_nocr("pa_out_$_.tmp") } @chunks);   # original order
    unlink glob('pa_in_*.tmp pa_out_*.tmp');
    return ($ms, $joined);
}

open(my $csv, '>', "result_parallel_analyzer_$tag.csv") or die $!;
print $csv "words,workers,run,wall_ms\n";
printf "%7s %8s %12s %9s\n", 'words', 'workers', 'mean wall ms', 'speedup';
for my $n (@sizes) {
    my @words = map { $base[$_ % @base] } 0 .. $n - 1;
    my ($ref_ms, $serial_out);
    my $t0 = [gettimeofday];
    write_lines('pa_serial.tmp', @words);
    system(qq{"$perl" $prog < pa_serial.tmp > pa_serial_out.tmp 2> $null}) == 0 or die "serial failed\n";
    $serial_out = slurp_nocr('pa_serial_out.tmp'); unlink 'pa_serial.tmp', 'pa_serial_out.tmp';
    die "serial output empty\n" unless length $serial_out;
    my %mean;
    for my $k (@workers) {
        my @t;
        for my $run (1 .. $runs) {
            my ($ms, $out) = run_parallel($k, @words);
            die "ORDER/CONTENT MISMATCH at $n words, $k workers\n" if $out ne $serial_out;
            push @t, $ms;
            printf $csv "%d,%d,%d,%.3f\n", $n, $k, $run, $ms;
        }
        my $s = 0; $s += $_ for @t; $mean{$k} = $s / @t;
        printf "%7d %8d %12.1f %9.2fx\n", $n, $k, $mean{$k}, $mean{1} / $mean{$k};
    }
}
close $csv;
print "\nall parallel outputs matched the serial output.\nsaved: result_parallel_analyzer_$tag.csv\n";
