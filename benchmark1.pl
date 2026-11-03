
#!/usr/bin/perl
#
# benchmark1.pl
#
# Dictionary Lookup Performance Benchmark
#
# Compares:
# 1. Normal Hash
# 2. Storable Binary Cache
# 3. Sorted Dictionary + Binary Search
# 4. MCE Multiprocessing (4 workers)
#
# Each timed run includes loading the dictionary
# representation and searching all test words.
#
# Requirements:
# Perl 5.36+
# MCE module
#

use strict;
use warnings;

use Storable qw(nstore retrieve);
use Time::HiRes qw(gettimeofday tv_interval);
use MCE;
use builtin qw(trim);

no warnings 'experimental::builtin';

# ================= CONFIG =================

my $dict_file    = 'dict_all.txt';
my $words_file   = 'random_words_100.txt';

my $cache_file   = 'dict_cache.bin';
my $sorted_file  = 'dict_sorted.txt';

my $csv_file     = 'result_mce.csv';

my $runs         = 10;
my $fork_workers = 4;
my $chunk_size   = 25;

# ==========================================


# ============================================================
# Load test words
# ============================================================

sub load_words {

    open(my $fh, '<', $words_file)
        or die "Cannot open $words_file: $!\n";

    my @words;

    while (my $line = <$fh>) {

        $line =~ tr/\r//d;
        chomp $line;

        next unless length $line;

        push @words, $line;
    }

    close($fh);

    return \@words;
}


# ============================================================
# Calculate average execution time
# ============================================================

sub avg {

    my $sum = 0;

    $sum += $_ for @_;

    return $sum / scalar(@_);
}


# ============================================================
# Load dictionary roots from text file
#
# Optimizations:
# - tr/// for carriage-return removal
# - trim() for whitespace
# - substr() for comment detection
# ============================================================

sub load_dict_roots_from_txt {

    open(my $fh, '<', $dict_file)
        or die "Cannot open $dict_file: $!\n";

    my %roots;

    while (my $line = <$fh>) {

        $line =~ tr/\r//d;
        chomp $line;

        $line = trim($line);

        next if $line eq '';
        next if substr($line, 0, 1) eq '#';

        my @fields = split(/,/, $line);

        next unless defined $fields[0]
            && length $fields[0];

        $roots{$fields[0]} = 1;
    }

    close($fh);

    return \%roots;
}


# ============================================================
# Prepare dictionary representations
#
# These files are built before benchmarking.
# Their creation time is excluded from the timed runs.
# ============================================================

print "=" x 65, "\n";
print "DICTIONARY LOOKUP PERFORMANCE BENCHMARK\n";
print "=" x 65, "\n";

print "\nPreparing dictionary representations...\n";

my $prep_dict = load_dict_roots_from_txt();

my $dict_count = scalar keys %$prep_dict;

print "Dictionary contains $dict_count unique root words.\n";


# ------------------------------------------------------------
# Build Storable Binary Cache
# ------------------------------------------------------------

nstore($prep_dict, $cache_file)
    or die "Failed to write $cache_file: $!\n";

print "Created $cache_file\n";


# ------------------------------------------------------------
# Build Sorted Dictionary
# ------------------------------------------------------------

open(my $sfh, '>', $sorted_file)
    or die "Cannot write $sorted_file: $!\n";

for my $word (sort keys %$prep_dict) {
    print $sfh "$word\n";
}

close($sfh)
    or die "Cannot close $sorted_file: $!\n";

print "Created $sorted_file\n";


# ============================================================
# Load test words
# ============================================================

my $words_ref = load_words();

my $num_words = scalar @$words_ref;

die "No test words loaded!\n"
    if $num_words == 0;

print "\nLoaded $num_words test words from '$words_file'\n";
print "Runs per method: $runs\n";
print "MCE workers: $fork_workers\n";
print "MCE chunk size: $chunk_size\n\n";


# ============================================================
# Results storage
# ============================================================

my %results;


# ============================================================
# METHOD 1: Normal Hash
#
# Reload full dictionary from text on every run.
# Search all test words using hash lookup.
# ============================================================

print "=" x 65, "\n";
print "METHOD 1: NORMAL HASH\n";
print "=" x 65, "\n";

{
    my (@times, $found);

    for my $run (1 .. $runs) {

        my $t0 = [gettimeofday];

        my $dict = load_dict_roots_from_txt();

        $found = 0;

        for my $word (@$words_ref) {

            $found++
                if exists $dict->{$word};
        }

        my $ms = tv_interval($t0) * 1000;

        push @times, $ms;

        printf "  [Normal Hash] run %2d: %9.3f ms (%d/%d found)\n",
            $run, $ms, $found, $num_words;
    }

    $results{'Normal Hash'} = {
        times => \@times,
        found => $found
    };
}

print "\n";


# ============================================================
# METHOD 2: Storable Binary Cache
#
# Reload binary cache on every run.
# Search all words using hash lookup.
# ============================================================

print "=" x 65, "\n";
print "METHOD 2: STORABLE BINARY CACHE\n";
print "=" x 65, "\n";

{
    my (@times, $found);

    for my $run (1 .. $runs) {

        my $t0 = [gettimeofday];

        my $dict = retrieve($cache_file);

        $found = 0;

        for my $word (@$words_ref) {

            $found++
                if exists $dict->{$word};
        }

        my $ms = tv_interval($t0) * 1000;

        push @times, $ms;

        printf "  [Storable Cache] run %2d: %9.3f ms (%d/%d found)\n",
            $run, $ms, $found, $num_words;
    }

    $results{'Storable Binary Cache'} = {
        times => \@times,
        found => $found
    };
}

print "\n";


# ============================================================
# METHOD 3: Sorted Dictionary + Binary Search
#
# Reload sorted dictionary on every run.
# Use binary search to find test words.
# ============================================================

print "=" x 65, "\n";
print "METHOD 3: SORTED DICTIONARY + BINARY SEARCH\n";
print "=" x 65, "\n";

{
    # --------------------------------------------------------
    # Binary Search Function
    # --------------------------------------------------------

    my $binary_search = sub {

        my ($sorted_ref, $target) = @_;

        my $low  = 0;
        my $high = $#$sorted_ref;

        while ($low <= $high) {

            my $mid = int(($low + $high) / 2);

            my $cmp = $sorted_ref->[$mid] cmp $target;

            if ($cmp == 0) {
                return 1;
            }
            elsif ($cmp > 0) {
                $high = $mid - 1;
            }
            else {
                $low = $mid + 1;
            }
        }

        return 0;
    };


    # --------------------------------------------------------
    # Benchmark Binary Search
    # --------------------------------------------------------

    my (@times, $found);

    for my $run (1 .. $runs) {

        my $t0 = [gettimeofday];

        open(my $sfh, '<', $sorted_file)
            or die "Cannot open $sorted_file: $!\n";

        my @sorted = <$sfh>;

        chomp @sorted;

        close($sfh);

        $found = 0;

        for my $word (@$words_ref) {

            $found++
                if $binary_search->(\@sorted, $word);
        }

        my $ms = tv_interval($t0) * 1000;

        push @times, $ms;

        printf "  [Binary Search] run %2d: %9.3f ms (%d/%d found)\n",
            $run, $ms, $found, $num_words;
    }

    $results{'Sorted + Binary Search'} = {
        times => \@times,
        found => $found
    };
}

print "\n";


# ============================================================
# METHOD 4: MCE MULTIPROCESSING
#
# Reload full dictionary from text.
# Distribute test words across four worker processes.
# Each worker performs dictionary lookups.
# Gather the results in the parent process.
# ============================================================

print "=" x 65, "\n";
print "METHOD 4: MCE MULTIPROCESSING\n";
print "=" x 65, "\n";

{
    my (@times, $found);

    for my $run (1 .. $runs) {

        my $t0 = [gettimeofday];

        # Full dictionary reload on every run
        my $dict = load_dict_roots_from_txt();

        my $total_found = 0;

        # ----------------------------------------------------
        # Create MCE worker pool
        # ----------------------------------------------------

        my $mce = MCE->new(

            max_workers => $fork_workers,

            chunk_size => $chunk_size,

            user_func => sub {

                my ($mce, $chunk_ref, $chunk_id) = @_;

                my $count = 0;

                for my $word (@$chunk_ref) {

                    $count++
                        if exists $dict->{$word};
                }

                # Send worker result to parent
                MCE->gather($count);
            },

            gather => sub {

                $total_found += $_ for @_;
            },
        );


        # ----------------------------------------------------
        # Execute multiprocessing
        # ----------------------------------------------------

        $mce->process($words_ref);

        $mce->shutdown;

        $found = $total_found;

        my $ms = tv_interval($t0) * 1000;

        push @times, $ms;

        printf "  [MCE %d workers] run %2d: %9.3f ms (%d/%d found)\n",
            $fork_workers,
            $run,
            $ms,
            $found,
            $num_words;
    }

    $results{'MCE (4 workers)'} = {
        times => \@times,
        found => $found
    };
}

print "\n";


# ============================================================
# VERIFY RESULTS
#
# All four methods must find the same number of words.
# ============================================================

print "=" x 65, "\n";
print "CORRECTNESS VERIFICATION\n";
print "=" x 65, "\n";

my $expected_found = $results{'Normal Hash'}{found};

for my $method (
    'Normal Hash',
    'Storable Binary Cache',
    'Sorted + Binary Search',
    'MCE (4 workers)'
) {

    my $found = $results{$method}{found};

    die "ERROR: $method found $found words, expected $expected_found\n"
        if $found != $expected_found;

    print "PASSED: $method found $found/$num_words words\n";
}

print "\nAll methods returned matching counts.\n\n";


# ============================================================
# CALCULATE AVERAGES
# ============================================================

my $baseline = avg(
    @{ $results{'Normal Hash'}{times} }
);


# ============================================================
# PRINT FINAL RESULTS
# ============================================================

print "=" x 65, "\n";
print "FINAL RESULTS (LOAD + SEARCH TIME)\n";
print "=" x 65, "\n";

printf "%-28s %12s %12s %10s\n",
    'Method',
    'Avg (ms)',
    'Speedup',
    'Found';

for my $method (
    'Normal Hash',
    'Storable Binary Cache',
    'Sorted + Binary Search',
    'MCE (4 workers)'
) {

    my $average = avg(
        @{ $results{$method}{times} }
    );

    my $speedup = $baseline / $average;

    printf "%-28s %12.3f %11.3fx %6d/%d\n",
        $method,
        $average,
        $speedup,
        $results{$method}{found},
        $num_words;
}


# ============================================================
# WRITE RESULTS TO CSV
# ============================================================

open(my $out, '>', $csv_file)
    or die "Cannot write $csv_file: $!\n";

print $out "Method,"
    . join(",", map { "Run$_" } (1 .. $runs))
    . ",Average_ms,Words_Found,Speedup_vs_Normal\n";


for my $method (
    'Normal Hash',
    'Storable Binary Cache',
    'Sorted + Binary Search',
    'MCE (4 workers)'
) {

    my @times = @{
        $results{$method}{times}
    };

    my $average = avg(@times);

    my $speedup = $baseline / $average;

    print $out join(
        ",",
        $method,
        (map { sprintf("%.3f", $_) } @times),
        sprintf("%.3f", $average),
        "$results{$method}{found}/$num_words",
        sprintf("%.3f", $speedup)
    ) . "\n";
}

close($out);

print "\nResults saved to: $csv_file\n";

print "=" x 65, "\n";
print "BENCHMARK COMPLETED\n";
print "=" x 65, "\n";
