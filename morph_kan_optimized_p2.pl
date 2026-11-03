
#!/usr/bin/perl
# ============================================================
# PERSON 2 WORK: morph_kan_optimized_p2.pl
#
# Guideline 2: Binary Search for dictionary lookup
#
# Compare:
#   1. Original Normal Hash lookup
#   2. Sorted Dictionary + Binary Search
#
# Both methods load dictionary data and search the same
# 100 words in every run.
#
# Original hash lookup is preserved.
# ============================================================

use strict;
use warnings;
use Time::HiRes qw(gettimeofday tv_interval);

# ---------------- CONFIG ----------------
my $dict_file   = 'dict_all.txt';
my $words_file  = 'random_words_100.txt';
my $sorted_file = 'dict_sorted_p2.txt';
my $csv_file    = 'result_person2_bsearch.csv';
my $runs        = 5;
# ----------------------------------------


# ============================================================
# STEP 1: Load original dictionary using Normal Hash
# ============================================================

sub load_normal_hash {

    my %h;

    open(my $f, '<', $dict_file)
        or die "Cannot open $dict_file: $!\n";

    while (my $line = <$f>) {

        $line =~ tr/\r\n//d;

        next if length($line) == 0;
        next if index($line, '#') == 0;

        my ($word, $pos, $para) = split(/,/, $line, 4);

        next unless defined $word && $word =~ /\S/;

        my $val = ($pos // '') . ($para // '');

        if (exists $h{$word}) {
            $h{$word} .= ",$val";
        }
        else {
            $h{$word} = $val;
        }
    }

    close($f);

    return %h;
}


# ============================================================
# STEP 2: Build sorted dictionary
#
# Uses the same loader as Normal Hash to ensure identical
# dictionary values and duplicate-root handling.
#
# The sorted file is prepared once before benchmarking.
# ============================================================

sub build_sorted_dict {

    print "Building sorted dictionary file...\n";

    my %h = load_normal_hash();

    my @sorted_words = sort keys %h;

    open(my $out, '>', $sorted_file)
        or die "Cannot write $sorted_file: $!\n";

    for my $word (@sorted_words) {
        print $out "$word|$h{$word}\n";
    }

    close($out)
        or die "Cannot close $sorted_file: $!\n";

    printf "Sorted dictionary built: %d unique words\n",
        scalar(@sorted_words);
}


# ============================================================
# STEP 3: Load sorted dictionary into memory
# ============================================================

sub load_sorted_array {

    my @arr;

    open(my $fh, '<', $sorted_file)
        or die "Cannot open $sorted_file: $!\n";

    while (my $line = <$fh>) {

        chomp($line);

        my ($word, $val) = split(/\|/, $line, 2);

        push @arr, [$word, $val // ''];
    }

    close($fh);

    return @arr;
}


# ============================================================
# STEP 4: Binary Search
#
# low = 0
# high = n - 1
#
# Compare target against middle element.
# Search the left or right half.
#
# Returns dictionary value if found.
# Returns undef if not found.
#
# Uses <= so the final remaining element is also checked.
# ============================================================

sub binary_search {

    my ($arr_ref, $target) = @_;

    my $low  = 0;
    my $high = $#$arr_ref;

    while ($low <= $high) {

        my $mid = int(($low + $high) / 2);

        my $cmp = $arr_ref->[$mid][0] cmp $target;

        if ($cmp == 0) {
            return $arr_ref->[$mid][1];
        }
        elsif ($cmp > 0) {
            $high = $mid - 1;
        }
        else {
            $low = $mid + 1;
        }
    }

    return undef;
}


# ============================================================
# STEP 5: Load 100 test words
# ============================================================

sub load_test_words {

    open(my $wf, '<', $words_file)
        or die "Cannot open $words_file: $!\n";

    my @words;

    while (my $line = <$wf>) {

        $line =~ tr/\r//d;
        chomp($line);

        next if $line eq '';

        push @words, $line;
    }

    close($wf);

    return @words;
}


# ============================================================
# STEP 6: Correctness verification
#
# Check that Normal Hash and Binary Search return:
#   - Same number of matching words
#   - Same dictionary values
#
# Verification is outside the timed benchmark.
# ============================================================

sub verify_results {

    my ($hash_ref, $sorted_ref, $words_ref) = @_;

    my $found_hash = 0;
    my $found_bs   = 0;

    for my $word (@$words_ref) {

        my $hash_value = $hash_ref->{$word};

        my $binary_value =
            binary_search($sorted_ref, $word);

        my $hash_exists = exists $hash_ref->{$word};
        my $bs_exists   = defined $binary_value;

        $found_hash++ if $hash_exists;
        $found_bs++   if $bs_exists;

        die "Lookup mismatch for word: $word\n"
            if $hash_exists != $bs_exists;

        if ($hash_exists) {

            die "Value mismatch for word: $word\n"
                if $hash_value ne $binary_value;
        }
    }

    die "Found count mismatch: Hash=$found_hash, Binary=$found_bs\n"
        if $found_hash != $found_bs;

    print "Correctness verification PASSED\n";
    print "Both methods found $found_hash words.\n\n";
}


# ============================================================
# STEP 7: Prepare benchmark
# ============================================================

print "=" x 60, "\n";
print "PERSON 2: Binary Search vs Normal Hash\n";
print "Input file: $words_file\n";
print "Dictionary: $dict_file\n";
print "=" x 60, "\n\n";

# Build sorted dictionary once, outside timed runs.
build_sorted_dict();

my @words = load_test_words();

my $n = scalar(@words);

die "No test words loaded!\n" if $n == 0;

print "Loaded $n test words.\n\n";


# ============================================================
# STEP 8: Verify dictionary equivalence
# ============================================================

my %verify_hash = load_normal_hash();
my @verify_sorted = load_sorted_array();

die "Dictionary size mismatch!\n"
    unless scalar(keys %verify_hash) == scalar(@verify_sorted);

for my $entry (@verify_sorted) {

    my ($word, $value) = @$entry;

    die "Missing hash key: $word\n"
        unless exists $verify_hash{$word};

    die "Dictionary value mismatch: $word\n"
        unless $verify_hash{$word} eq $value;
}

verify_results(
    \%verify_hash,
    \@verify_sorted,
    \@words
);


# ============================================================
# STEP 9: Benchmark
#
# Method 1:
#   Reload dictionary from text into hash + search.
#
# Method 2:
#   Reload sorted dictionary from text + binary search.
#
# Each method runs 5 times.
# ============================================================

my (@hash_times, @bsearch_times);

my $last_hash_found = 0;
my $last_bs_found   = 0;

for my $run (1 .. $runs) {

    print "--- Run $run ---\n";

    # --------------------------------------------------------
    # METHOD 1: Normal Hash
    # --------------------------------------------------------

    my $t1 = [gettimeofday];

    my %dict = load_normal_hash();

    my $found_hash = 0;

    for my $word (@words) {
        $found_hash++ if exists $dict{$word};
    }

    my $hash_ms = tv_interval($t1) * 1000;

    push @hash_times, $hash_ms;

    $last_hash_found = $found_hash;

    printf "  Normal Hash:    %.3f ms (%d/%d found)\n",
        $hash_ms, $found_hash, $n;


    # --------------------------------------------------------
    # METHOD 2: Binary Search
    # --------------------------------------------------------

    my $t2 = [gettimeofday];

    my @sorted = load_sorted_array();

    my $found_bs = 0;

    for my $word (@words) {

        $found_bs++
            if defined binary_search(\@sorted, $word);
    }

    my $bs_ms = tv_interval($t2) * 1000;

    push @bsearch_times, $bs_ms;

    $last_bs_found = $found_bs;

    printf "  Binary Search:  %.3f ms (%d/%d found)\n",
        $bs_ms, $found_bs, $n;


    # Check matching counts outside timed operations.
    die "Mismatch in run $run!\n"
        if $found_hash != $found_bs;

    print "\n";
}


# ============================================================
# STEP 10: Calculate averages
# ============================================================

sub average {

    my ($arr_ref) = @_;

    my $sum = 0;

    $sum += $_ for @$arr_ref;

    return $sum / scalar(@$arr_ref);
}

my $avg_hash = average(\@hash_times);
my $avg_bs   = average(\@bsearch_times);

die "Binary Search average is zero!\n"
    if $avg_bs == 0;

my $speedup = $avg_hash / $avg_bs;


# ============================================================
# STEP 11: Print results
# ============================================================

print "=" x 60, "\n";
print "FINAL RESULTS\n";
print "=" x 60, "\n";

printf "Normal Hash average:    %.3f ms\n", $avg_hash;
printf "Binary Search average:  %.3f ms\n", $avg_bs;
printf "Speedup vs Normal Hash: %.3fx\n", $speedup;

printf "Words found: %d/%d\n",
    $last_hash_found, $n;

print "=" x 60, "\n\n";


# ============================================================
# STEP 12: Save CSV
# ============================================================

open(my $csv, '>', $csv_file)
    or die "Cannot create $csv_file: $!\n";

print $csv
    "Method,Run1,Run2,Run3,Run4,Run5,Average_ms\n";

print $csv "Normal_Hash,"
    . join(",", map { sprintf("%.3f", $_) } @hash_times)
    . ","
    . sprintf("%.3f", $avg_hash)
    . "\n";

print $csv "Binary_Search,"
    . join(",", map { sprintf("%.3f", $_) } @bsearch_times)
    . ","
    . sprintf("%.3f", $avg_bs)
    . "\n";

close($csv);

print "Results saved to: $csv_file\n";
