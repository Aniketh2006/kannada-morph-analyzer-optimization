#!/usr/bin/perl
# time_analyzers.pl  --  END-TO-END timing of the two real analyzers.
#
# Closes the gap that the loader benchmarks leave open: the original
# (morph_kan_original.pl) and the optimized (morph_kan.pl) analyzer are
# timed on the same 100 words, as complete programs.
#
# Design (fixed before looking at any data):
#   * order alternates every run (A,B / B,A / ...) so neither analyzer
#     always benefits from a warm file cache or allocator state
#   * run 1 is a warm-up: recorded in the CSV but excluded from the summary
#   * two conditions:
#       quiet   : STDERR of BOTH analyzers goes to the null device
#                 -> isolates computation from debug-print cost
#       shipped : original keeps its debug STDERR (written to a file),
#                 optimized prints none -> as the two files are distributed
#   * output equality (CR stripped) is verified before timing
#
# Usage (repository root):  perl scripts/time_analyzers.pl [runs=31] [tag=linux]
use strict;
use warnings;
use File::Spec;
use Time::HiRes qw(gettimeofday tv_interval);

my $runs = shift(@ARGV) || 31;
my $tag  = shift(@ARGV) || 'run';
my $null = File::Spec->devnull();
my $words = 'random_words_100.txt';
my $perl  = $^X;
my %prog  = (original => 'morph_kan_original.pl', optimized => 'morph_kan.pl');
for my $f (values %prog, $words, 'dict_all.txt') {
    die "missing $f (run from the repository root)\n" unless -e $f;
}

sub run_once {
    my ($which, $cond) = @_;
    my $err = ($cond eq 'shipped' && $which eq 'original') ? 'analyzer_stderr.tmp' : $null;
    my $t0 = [gettimeofday];
    my $rc = system(qq{"$perl" $prog{$which} < $words > $null 2> $err});
    my $ms = tv_interval($t0) * 1000;
    die "$prog{$which} failed (exit $rc)\n" if $rc != 0;
    return $ms;
}

sub slurp_nocr {
    my ($f) = @_;
    open(my $h, '<', $f) or die "$f: $!";
    binmode($h);
    local $/;
    my $s = <$h>;
    $s =~ s/\r//g;
    return $s;
}

# 1. correctness: identical output
for my $w (qw(original optimized)) {
    system(qq{"$perl" $prog{$w} < $words > out_$w.tmp 2> $null}) == 0 or die "$w failed\n";
}
my ($out_o, $out_p) = (slurp_nocr('out_original.tmp'), slurp_nocr('out_optimized.tmp'));
die "OUTPUT DIFFERS between analyzers - stop and investigate\n" if $out_o ne $out_p || length($out_o) == 0;
printf "output check: IDENTICAL and non-empty (%d bytes)\n\n", length($out_o);

# 2. timing
my $csv = "result_analyzer_endtoend_$tag.csv";
open(my $out, '>', $csv) or die $!;
print $out "condition,run,warmup,first,original_ms,optimized_ms\n";
my %sum;
for my $cond (qw(quiet shipped)) {
    for my $run (1 .. $runs) {
        my @order = $run % 2 ? qw(original optimized) : qw(optimized original);
        my %ms;
        $ms{$_} = run_once($_, $cond) for @order;
        my $warm = $run == 1 ? 1 : 0;
        printf $out "%s,%d,%d,%s,%.3f,%.3f\n", $cond, $run, $warm, $order[0],
               $ms{original}, $ms{optimized};
        unless ($warm) { push @{$sum{$cond}{original}}, $ms{original};
                         push @{$sum{$cond}{optimized}}, $ms{optimized}; }
    }
}
close $out;
unlink 'out_original.tmp', 'out_optimized.tmp', 'analyzer_stderr.tmp';

sub mean   { my $s = 0; $s += $_ for @_; return $s / @_ }
sub median { my @s = sort { $a <=> $b } @_; my $n = @s;
             return $n % 2 ? $s[$n/2] : ($s[$n/2-1] + $s[$n/2]) / 2 }
for my $cond (qw(quiet shipped)) {
    my ($o, $p) = @{$sum{$cond}}{qw(original optimized)};
    printf "%-8s original mean %.1f ms (median %.1f) | optimized mean %.1f ms (median %.1f) | speedup %.3fx  [n=%d, warm-up excluded]\n",
        $cond, mean(@$o), median(@$o), mean(@$p), median(@$p), mean(@$o) / mean(@$p), scalar @$o;
}
print "\nsaved: $csv\n";
