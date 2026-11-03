#!/usr/bin/perl
# ============================================================
# PERSON 1 WORK: morph_kan_optimized_p1.pl
# Change: Removed unnecessary regex in readrootDict and 
# replaced with faster direct string operations
# Sir's instruction: remove non-essential regular expressions
# for simple string matching
# ============================================================

# WHAT WE CHANGED vs original readrootDict:
# BEFORE (slow - 5 regex operations per line):
#   $lined8 =~ s/\cM//;          <- regex to remove carriage return
#   next if($lined8 =~ m/^\s*$/); <- regex to skip blank lines
#   next if $lined8 =~ m/^\#+/;   <- regex to skip comment lines
#   $lined8 =~ s/^\s+//;          <- regex to trim left spaces
#   $lined8 =~ s/\s+$//;          <- regex to trim right spaces
#
# AFTER (fast - direct string operations):
#   $lined8 =~ tr/\cM//d;         <- tr is faster than s// for single char removal
#   next if length($lined8) == 0; <- direct length check, no regex
#   next if index($lined8,'#')==0; <- index() is much faster than regex for fixed string
#   $lined8 = _trim($lined8);      <- custom trim using substr/index, no regex

use strict;
use warnings;
use Time::HiRes qw(gettimeofday tv_interval);
use Storable qw(freeze);
use builtin qw(trim);
no warnings 'experimental::builtin';

# fast trim function using index and substr - no regex at all
sub _trim {
    my $s = $_[0];
    my $l = length($s);
    return $s if $l == 0;
    my $start = 0;
    my $end   = $l - 1;
    $start++ while $start <= $end && substr($s, $start, 1) le ' ';
    $end--   while $end >= $start && substr($s, $end,   1) le ' ';
    return $start > $end ? '' : substr($s, $start, $end - $start + 1);
}

our %rootDictHash8;
our %genderHash;

# ---------------------------------------------------------------
# OPTIMIZED readrootDict - no unnecessary regex
# ---------------------------------------------------------------
sub readrootDict_optimized {
    my $t0 = [gettimeofday];

    open(my $fh, '<', 'dict_all.txt')
        or die "Cannot open dict_all.txt: $!\n";

    my (%roots, %genders);

    while (my $line = <$fh>) {
        $line =~ tr/\r//d;
        chomp $line;

        next if $line eq '';

        $line = trim($line);

        next if $line eq '';
        next if substr($line, 0, 1) eq '#';

        my @f = split(/,/, $line);

        my $word = $f[0];
        my $value = ($f[1] // '') . ($f[2] // '');

        if (exists $roots{$word}) {
            $roots{$word} .= ',' . $value;
        }
        else {
            $roots{$word} = $value;
        }

        my $key = $word . '_' . ($f[1] // '');

        if (defined $f[4] && $f[4] =~ /^\w+$/) {
            $genders{$key} = lc($f[4]);
        }
    }

    close($fh);

    my $elapsed = tv_interval($t0) * 1000;

    return (\%roots, \%genders, $elapsed);
}
# ---------------------------------------------------------------
# ORIGINAL readrootDict for comparison
# ---------------------------------------------------------------
sub readrootDict_original {
    my $t0 = [gettimeofday];

    open(my $fh, '<', 'dict_all.txt')
        or die "Cannot open dict_all.txt: $!\n";

    my (%roots, %genders);

    while (my $line = <$fh>) {
        $line =~ s/\cM//;
        chomp($line);

        next if ($line =~ m/^\s*$/);
        next if $line =~ m/^\#+/;

        $line =~ s/^\s+//;
        $line =~ s/\s+$//;

        my @f = split(/,/, $line);

        my $word = $f[0];
        my $value = ($f[1] // '') . ($f[2] // '');
        my $key = $word . '_' . ($f[1] // '');

        if (exists $roots{$word}) {
            $roots{$word} .= ',' . $value;
        }
        else {
            $roots{$word} = $value;
        }

        if (defined $f[4] && $f[4] =~ /^\w+$/) {
            $genders{$key} = lc($f[4]);
        }
    }

    close($fh);

    my $elapsed = tv_interval($t0) * 1000;

    return (\%roots, \%genders, $elapsed);
}

# ---------------------------------------------------------------
# Run comparison - 5 times each and average
# ---------------------------------------------------------------
print "="x55 . "\n";
print "PERSON 1: Regex Optimization Benchmark\n";
print "="x55 . "\n\n";

my (@orig_times, @opt_times);

for my $run (1 .. 5) {
    print "Run $run:\n";

    my ($original_roots, $original_gender, $orig_ms)
        = readrootDict_original();

    my ($optimized_roots, $optimized_gender, $opt_ms)
        = readrootDict_optimized();

    # Verify identical dictionary contents
    for my $key (keys %$original_roots) {
        die "Missing root in optimized: $key\n"
            unless exists $optimized_roots->{$key};

        die "Root value mismatch: $key\n"
            unless $original_roots->{$key} eq $optimized_roots->{$key};
    }

    die "Root count mismatch\n"
        unless keys(%$original_roots) == keys(%$optimized_roots);

    for my $key (keys %$original_gender) {
        die "Missing gender key: $key\n"
            unless exists $optimized_gender->{$key};

        die "Gender mismatch: $key\n"
            unless $original_gender->{$key} eq $optimized_gender->{$key};
    }

    die "Gender count mismatch\n"
        unless keys(%$original_gender) == keys(%$optimized_gender);

    push @orig_times, $orig_ms;
    push @opt_times, $opt_ms;

    printf "Original: %.3f ms | Optimized: %.3f ms\n\n",
        $orig_ms, $opt_ms;
}

my $avg_orig = 0;
$avg_orig += $_ for @orig_times;
$avg_orig /= @orig_times;

my $avg_opt = 0;
$avg_opt += $_ for @opt_times;
$avg_opt /= @opt_times;

printf "Original average: %.3f ms\n", $avg_orig;
printf "Optimized average: %.3f ms\n", $avg_opt;
printf "Speedup: %.3fx\n", $avg_orig / $avg_opt;

open(my $csv, '>', 'result_person1_regex.csv') or die $!;

print $csv "Method,Run1,Run2,Run3,Run4,Run5,Average_ms\n";

print $csv join(
    ",",
    "Original_Regex",
    (map { sprintf("%.3f", $_) } @orig_times),
    sprintf("%.3f", $avg_orig)
) . "\n";

print $csv join(
    ",",
    "Optimized_NoRegex",
    (map { sprintf("%.3f", $_) } @opt_times),
    sprintf("%.3f", $avg_opt)
) . "\n";

close($csv);

print "Saved result_person1_regex.csv\n";