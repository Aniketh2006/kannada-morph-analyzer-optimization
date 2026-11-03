#!/usr/bin/perl
#

# Read the associated files from their respective DBM hashes

use utf8;
use Encode qw(decode encode);
binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

# Read the associated files from their respective DBM hashes

readrootDict();
#readNEdict();
readFsa();
#readOntology();
readAlloMorphMappingInfo();


while(<>) {
	chomp;
	$orig_input = $_;
	$_ = kannada_to_wx($_);
	morphML($_);
	print  "\n";
}

# strips the suffix from orig_input to get just the root
# needed so Kannada script input like ೫೦ stays ೫೦ in output, not 50
sub get_orig_root {
	my ($orig, $wx_full, $wx_root) = @_;
	my $suffix_len = length($wx_full) - length($wx_root);
	my @chars = split //, $orig;
	my @root_chars = @chars[0 .. $#chars - $suffix_len];
	return join("", @root_chars) if @root_chars;
	return $wx_root;
}

# converts Kannada Unicode input to WX notation
# so ೫೦ನೇ and 50ನೇ both work the same way as 50ne
sub kannada_to_wx {
    my $input = shift;

    # full Kannada Unicode -> WX single-char mapping
    # consonants: their WX equivalent (inherent 'a' vowel added by context)
    # matras (dependent vowel signs): override the inherent 'a'
    # virama (halant, U+0CCD): removes inherent 'a', we just skip it
    my %wx = (
        # Kannada digits
        "\x{0CE6}" => "0", "\x{0CE7}" => "1", "\x{0CE8}" => "2",
        "\x{0CE9}" => "3", "\x{0CEA}" => "4", "\x{0CEB}" => "5",
        "\x{0CEC}" => "6", "\x{0CED}" => "7", "\x{0CEE}" => "8",
        "\x{0CEF}" => "9",
        # independent vowels
        "\x{0C85}" => "a",  "\x{0C86}" => "A",  "\x{0C87}" => "i",
        "\x{0C88}" => "I",  "\x{0C89}" => "u",  "\x{0C8A}" => "U",
        "\x{0C8B}" => "q",  "\x{0C8E}" => "e",  "\x{0C8F}" => "E",
        "\x{0C90}" => "E",  "\x{0C92}" => "o",  "\x{0C93}" => "O",
        "\x{0C94}" => "O",
        # consonants (k group)
        "\x{0C95}" => "ka", "\x{0C96}" => "Ka", "\x{0C97}" => "ga",
        "\x{0C98}" => "Ga", "\x{0C99}" => "fa",
        # c group
        "\x{0C9A}" => "ca", "\x{0C9B}" => "Ca", "\x{0C9C}" => "ja",
        "\x{0C9D}" => "Ja", "\x{0C9E}" => "Fa",
        # T group (retroflex)
        "\x{0C9F}" => "Ta", "\x{0CA0}" => "Wa", "\x{0CA1}" => "Da",
        "\x{0CA2}" => "Qa", "\x{0CA3}" => "Na",
        # t group (dental)
        "\x{0CA4}" => "wa", "\x{0CA5}" => "xa", "\x{0CA6}" => "da",
        "\x{0CA7}" => "Xa", "\x{0CA8}" => "na",
        # p group
        "\x{0CAA}" => "pa", "\x{0CAB}" => "Pa", "\x{0CAC}" => "ba",
        "\x{0CAD}" => "Ba", "\x{0CAE}" => "ma",
        # semivowels and sibilants
        "\x{0CAF}" => "ya", "\x{0CB0}" => "ra", "\x{0CB2}" => "la",
        "\x{0CB5}" => "va", "\x{0CB6}" => "Sa", "\x{0CB7}" => "Ra",
        "\x{0CB8}" => "sa", "\x{0CB9}" => "ha", "\x{0CB3}" => "La",
        # dependent vowel signs (matras) - these override the 'a' added above
        # so we post-process: consonant adds "Xa", matra strips trailing 'a' and adds its vowel
        "\x{0CBE}" => "A",  "\x{0CBF}" => "i",  "\x{0CC0}" => "I",
        "\x{0CC1}" => "u",  "\x{0CC2}" => "U",  "\x{0CC3}" => "q",
        "\x{0CC6}" => "e",  "\x{0CC7}" => "E",  "\x{0CC8}" => "E",
        "\x{0CCA}" => "o",  "\x{0CCB}" => "O",  "\x{0CCC}" => "O",
        # anusvara and visarga
        "\x{0C82}" => "M",  "\x{0C83}" => "H",
        # virama (halant) - removes inherent a, skip it
        "\x{0CCD}" => "__VIRAMA__",
        # zero width non-joiner - just remove
        "\x{200C}" => "",
    );

    # matras that remove the preceding inherent 'a'
    my %is_matra = map { $_ => 1 } (
        "\x{0CBE}", "\x{0CBF}", "\x{0CC0}", "\x{0CC1}", "\x{0CC2}",
        "\x{0CC3}", "\x{0CC6}", "\x{0CC7}", "\x{0CC8}", "\x{0CCA}",
        "\x{0CCB}", "\x{0CCC}", "\x{0C82}", "\x{0C83}"
    );

    my $result = "";
    my @chars = split //, $input;
    for my $ch (@chars) {
        if (exists $wx{$ch}) {
            my $wxval = $wx{$ch};
            if ($wxval eq "__VIRAMA__") {
                # virama: remove the trailing 'a' we just added from the consonant
                $result =~ s/a$//;
            } elsif (exists $is_matra{$ch}) {
                # matra: remove trailing 'a' from consonant, then add matra vowel
                $result =~ s/a$//;
                $result .= $wxval;
            } else {
                $result .= $wxval;
            }
        } else {
            # not a Kannada char - keep as is (ASCII digits, spaces etc)
            $result .= $ch;
        }
    }
    return $result;
}


sub morphML { 
	$token = $_[0];
	print "$token\n";
	$morph_output = "";
	@perfect=();
 	@tokens = ($token);
 	$noOfTokens = @tokens;
 	foreach $token(@tokens) {
		#print STDERR "~~~~~~~~~ $token ~~~~~~~~~~~~~~~\n";
		@perfect=();
		$moditoken ="";
    		%finalout=();
		%possible_tags = ();
		$total++;
	#--------------------------------------
	# Handle numbered bullet points
	# Examples: 1) 2) 10) 1. 2. 10.
	#--------------------------------------
	if ($token =~ /^([0-9]+)[\)]$/) {
	    my $num = $1;
	    print "$token(NUM)\n";
	    next;
	}

	if ($token =~ /^([0-9]+)\.$/) {
	    my $num = $1;
	    print "$token(NUM)\n";
	    next;
	}
		#--------------------------------------
	# Handle punctuation
	#--------------------------------------
	if ($token =~ /^(?:\.|''|""|\?|:|;|,|!|:-)$/) {
	    print "$token(PUNC)\n";
	    next;
	}
	#--------------------------------------
	# Handle numeric words with noun suffixes
	# ralli, ra, rigeV, rimxa
	# Example: 2002ralli
	#--------------------------------------
	if ($token =~ /^([0-9]+)(ralli|ra|rigeV|riMxa|kkeV|raMweV|ne|neV|rallina|kkiMwa)$/) {

	    my $root   = $1;
	    my $suffix = $2;

	    print "$token(N)\n";
	    next;
	}

	#--------------------------------------
	# Handle symbols
	#--------------------------------------
	if ($token =~ /^(?:-|\\+|=|\(|\)|\{|\}|\[|\]|@|#|\$|%|\^|&|\*|\\|\|\||\||\/|<|>|•|●|‣|⁃|⁌|⁍|\.\.\.)$/)
	{
	    print "$token(SYM)\n";
	    next;
	}
	$token =~ s/\.$// if($token =~ /^rU/ and $token =~ /\.$/);
	$token =~ s/// if($token =~ //); #to remove junk char in degree celsius input # 23⁰
	#print STDERR "$token\n";

    	if($token =~ /^[0-9]+([.,-]?([0-9]+)?)*$/) { # check for number
			my $featureStr = {};
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "";

			print "$token(NUM)\n";
			next;
		}
    	elsif($token =~ /^[0-9]+([.,]?([0-9]+)?)\s*-?[⁰]/) { # check for degree celsius
			my $featureStr = {};
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "";

			printfs(\$featureStr);
			next;
		}
    	elsif($token =~ /^rU\.?[0-9]+([.,][0-9]+)?([.,][0-9]+)?\s*$/) { # check for currency
			my $featureStr = {};
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "";
			
			printfs(\$featureStr);
			next;
		}
    	elsif($token =~ /^rU\.?[0-9]+([.,][0-9]+)?([.,][0-9]+)?-?(m)\s*$/) { # check for inflected currency
			my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?m//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "m";
			if($matched2 =~ /m/) {
				#$featureStr->{SUFF}= "$2";
				$featureStr->{EXTD} = " inc=\"Y\" inc_marker=\"um\" inc_posn=\"2\""; 
			}
			printfs(\$featureStr);
			next;
		}
    	elsif($token =~ /^rU\.?[0-9]+([.,][0-9]+)?([.,][0-9]+)?-?(E)[ktcpw]?\s*$/) { # check for inflected currency
			my $featureStr = {};
			$matched3 = $3;
			$token =~ s/-?E[ktcpw]?//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "E";
			if($matched3 =~ /E/) {
				#$featureStr->{SUFF}= "$3";
				$featureStr->{EXTD} = " case_name=\"acc\""; 
			}
			printfs(\$featureStr);
			next;
		}
    	elsif($token =~ /^rU\.?[0-9]+([.,][0-9]+)?([.,][0-9]+)?-?(kku)[ktcpw]?\s*$/) { # check for inflected currency
			my $featureStr = {};
			$matched3 = $3;
			$token =~ s/-?kku[ktcpw]?//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "ku";
			if($matched3 =~ /kku/) {
				#$featureStr->{SUFF}= "$3";
				$featureStr->{EXTD} = " case_name=\"dat\""; 
			}
			printfs(\$featureStr);
			next;
		}
        elsif($token =~ /^rU\.?[0-9]+([.,][0-9]+)?([.,][0-9]+)?-?(ilirunwu)[ktcpw]?\s*$/) { # check for inflected currency
            my $featureStr = {};
            $matched3 = $3;
            $token =~ s/-?ilirunwu[ktcpw]?//;
            $featureStr->{ROOT}= $token;
            $featureStr->{LCAT}= "num";
            $featureStr->{GEND}= "";
            $featureStr->{NUM}= "sg";
            $featureStr->{PERS}= "";
            $featureStr->{CASE}= "d";
            $featureStr->{CM}= "";
            $featureStr->{SUFF}= "ilirunwu";
            if($matched3 =~ /ilirunwu/) {
                #$featureStr->{SUFF}= "$3";
                $featureStr->{EXTD} = " case_name=\"abl\"";
            }
            printfs(\$featureStr);
            next;
        }

    	elsif($token =~ /^rU\.?[0-9]+([.,][0-9]+)?([.,][0-9]+)?-?(kkum)\s*$/) { # check for inflected currency
			my $featureStr = {};
			$matched3 = $3;
			$token =~ s/-?kkum//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "ku_um";
			if($matched3 =~ /kkum/) {
				#$featureStr->{SUFF}= "$3";
				$featureStr->{EXTD} = " case_name=\"dat\" inc=\"Y\" inc_marker=\"um\" inc_posn=\"2\""; 
			}
			printfs(\$featureStr);
			next;
		}
    	elsif($token =~ /^rU\.?[0-9]+([.,][0-9]+)?([.,][0-9]+)?-?(kkulY)\s*$/) { # check for inflected currency
			my $featureStr = {};
			$matched3 = $3;
			$token =~ s/-?kkulY//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "ku_ulY";
			if($matched3 =~ /kkulY/) {
				#$featureStr->{SUFF}= "$3";
				$featureStr->{EXTD} = " case_name=\"dat\" psp=\"Y\" psp_marker=\"ulY\""; 
			}
			printfs(\$featureStr);
			next;
		}
    	elsif($token =~ /^[0-9]+([.,][0-9]+)?([.,][0-9]+)?-?(kkulY)\s*$/) { # check for inflected numbers
			my $featureStr = {};
			$matched3 = $3;
			$token =~ s/-?kkulY//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "ku_ulY";
			if($matched3 =~ /kkulY/) {
				#$featureStr->{SUFF}= "$3";
				$featureStr->{EXTD} = " case_name=\"dat\" psp=\"Y\" psp_marker=\"ulY\""; 
			}
			printfs(\$featureStr);
			next;
		}
    	elsif($token =~ /^[0-9]+(\.[0-9]+)?-?(Am)\s*$/) { # check for inflected numbers
			my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?Am//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "Am";
			if($matched2 =~ /Am/) {
				#$featureStr->{SUFF}= "$2";
				$featureStr->{EXTD} = " adj=\"Am\""; 
			}
			printfs(\$featureStr);
			next;
		}
    	elsif($token =~ /^[0-9]+(\.[0-9]+)?-?(m)\s*$/) { # check for inflected numbers
			my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?m//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "m";
			if($matched2 =~ /m/) {
				#$featureStr->{SUFF}= "$2";
				$featureStr->{EXTD} = " adj=\"m\""; 
			}
			printfs(\$featureStr);
			next;
		}
        elsif($token =~ /^[0-9]+(\.[0-9]+)?-?(ilirunwu)\s*$/) { # check for inflected numbers
            my $featureStr = {};
            $matched2 = $2;
            $token =~ s/-?ilirunwu//;
            $featureStr->{ROOT}= $token;
            $featureStr->{LCAT}= "num";
            $featureStr->{GEND}= "";
            $featureStr->{NUM}= "sg";
            $featureStr->{PERS}= "";
            $featureStr->{CASE}= "d";
            $featureStr->{CM}= "";
            $featureStr->{SUFF}= "ilirunwu";
            if($matched2 =~ /ilirunwu/) {
                #$featureStr->{SUFF}= "$2";
                $featureStr->{EXTD} = " case_name=\"abl\"";
            }
            printfs(\$featureStr);
            next;
        }

    	elsif($token =~ /[0-9]+(\.[0-9]+)?-?(vawu)\s*$/) { # check for inflected numbers
			my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?vawu//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "vawu";
			if($matched2 =~ /vawu/) {
				#$featureStr->{SUFF}= "$2";
				$featureStr->{EXTD} = " adj=\"vawu\""; 
			}
			printfs(\$featureStr);
                        next;
		}
    	elsif($token =~ /[0-9]+(\.[0-9]+)?-?(vawum)\s*$/) { # check for inflected numbers
			my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?vawum//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "vawu_um";
			if($matched2 =~ /vawum/) {
				#$featureStr->{SUFF}= "$2";
				$featureStr->{EXTD} = " adj=\"vawu\" inc=\"Y\" inc_marker=\"um\" inc_posn=\"2\""; 
			}
			printfs(\$featureStr);
                        next;
		}
    	elsif($token =~ /[0-9]+(\.[0-9]+)?-?(vawAka)[ktcpw]?\s*$/) { # check for inflected numbers
			my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?vawAka[ktcpw]?//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "vawAka";
			if($matched2 =~ /vawAka/) {
				#$featureStr->{SUFF}= "$2";
				$featureStr->{EXTD} = " adv=\"vawAka\""; 
			}
			printfs(\$featureStr);
                        next;
		}
    	elsif($token =~ /[0-9]+(\.[0-9]+)?-?(Aka)[ktcpw]?\s*$/) { # check for inflected numbers
			my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?Aka[ktcpw]?//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "Aka";
			if($matched2 =~ /Aka/) {
				#$featureStr->{SUFF}= "$2";
				$featureStr->{EXTD} = " adv=\"Aka\""; 
			}
			printfs(\$featureStr);
                        next;
		}
    	elsif($token =~ /[0-9]+(\.[0-9]+)?-?(nY)\s*$/) { # check for inflected numbers
			my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?nY//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "inY";
			$featureStr->{SUFF}= "inY";
			if($matched2 =~ /nY/) {
				#$featureStr->{SUFF}= "$2";
				$featureStr->{EXTD} = " case_name=\"gen\""; 
			}
			printfs(\$featureStr);
                        next;
		}
    	elsif($token =~ /[0-9]+(\.[0-9]+)?-?(E)[ktcpw]?\s*$/) { # check for inflected numbers
			my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?E[ktcpw]?//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "E";
			$featureStr->{SUFF}= "E";
			if($matched2 =~ /E/) {
				#$featureStr->{SUFF}= "$2";
				$featureStr->{EXTD} = " case_name=\"acc\""; 
			}
			printfs(\$featureStr);
                        next;
		}
    	elsif($token =~ /[0-9]+(\.[0-9]+)?-?(e)\s*$/) { # check for inflected numbers
			my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?e//;
			$featureStr->{ROOT}= $token; 
			$featureStr->{LCAT}= "num";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "sg";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "d";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "e";
			if($matched2 =~ /e/) {
				#$featureStr->{SUFF}= "$2";
				$featureStr->{EXTD} = " clt=\"e\""; 
			}
			printfs(\$featureStr);
                        next;
		}
        elsif($token =~ /[0-9]+(\.[0-9]+)?-?i?(l)\s*$/) { # check for inflected numbers
                        my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?i?l//;
                        $featureStr->{ROOT}= $token;
                        $featureStr->{LCAT}= "num";
                        $featureStr->{GEND}= "";
                        $featureStr->{NUM}= "sg";
                        $featureStr->{PERS}= "";
                        $featureStr->{CASE}= "d";
                        $featureStr->{CM}= "il";
                        $featureStr->{SUFF}= "il";
                        if($matched2 =~ /i?l/) {
                                #$featureStr->{SUFF}= "$2";
                                $featureStr->{EXTD} = " case_name=\"loc\"";
                        }
			printfs(\$featureStr);
                        next;
                }
        elsif($token =~ /[0-9]+(\.[0-9]+)?-?(kku)\s*$/) { # check for inflected numbers
                        my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?kku//;
                        $featureStr->{ROOT}= $token;
                        $featureStr->{LCAT}= "num";
                        $featureStr->{GEND}= "";
                        $featureStr->{NUM}= "sg";
                        $featureStr->{PERS}= "";
                        $featureStr->{CASE}= "d";
                        $featureStr->{CM}= "kku";
                        $featureStr->{SUFF}= "kku";
                        if($matched2 =~ /kku/) {
                                #$featureStr->{SUFF}= "$2";
                                $featureStr->{EXTD} = " case_name=\"dat\"";
                        }
			printfs(\$featureStr);
                        next;
                }
        elsif($token =~ /[0-9]+(\.[0-9]+)?-?(kalYil)\s*$/) { # check for inflected numbers
                        my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?kalYil//;
                        $featureStr->{ROOT}= $token;
                        $featureStr->{LCAT}= "num";
                        $featureStr->{GEND}= "";
                        $featureStr->{NUM}= "pl";
                        $featureStr->{PERS}= "";
                        $featureStr->{CASE}= "d";
                        $featureStr->{CM}= "il";
                        $featureStr->{SUFF}= "kalY_il";
                        if($matched2 =~ /kalYil/) {
                                #$featureStr->{SUFF}= "$2";
                                $featureStr->{EXTD} = " case_name=\"loc\"";
                        }
			printfs(\$featureStr);
                        next;
                }
        elsif($token =~ /[0-9]+(\.[0-9]+)?-?(kalYinY)\s*$/) { # check for inflected numbers
                        my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?kalYinY//;
                        $featureStr->{ROOT}= $token;
                        $featureStr->{LCAT}= "num";
                        $featureStr->{GEND}= "";
                        $featureStr->{NUM}= "pl";
                        $featureStr->{PERS}= "";
                        $featureStr->{CASE}= "d";
                        $featureStr->{CM}= "inY";
                        $featureStr->{SUFF}= "kalY_inY";
                        if($matched2 =~ /kalYinY/) {
                                #$featureStr->{SUFF}= "$2";
                                $featureStr->{EXTD} = " case_name=\"gen\"";
                        }
			printfs(\$featureStr);
                        next;
                }
        elsif($token =~ /[0-9]+(\.[0-9]+)?-?(lirunwu)\s*$/) { # check for inflected numbers
                        my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?lirunwu//;
                        $featureStr->{ROOT}= $token;
                        $featureStr->{LCAT}= "num";
                        $featureStr->{GEND}= "";
                        $featureStr->{NUM}= "sg";
                        $featureStr->{PERS}= "";
                        $featureStr->{CASE}= "d";
                        $featureStr->{CM}= "ilirunwu";
                        $featureStr->{SUFF}= "ilirunwu";
                        if($matched2 =~ /lirunwu/) {
                                #$featureStr->{SUFF}= "$2";
                                $featureStr->{EXTD} = " case_name=\"abl\"";
                        }
			printfs(\$featureStr);
                        next;
                }
        elsif($token =~ /[0-9]+(\.[0-9]+)?-?(kkum)\s*$/) { # check for inflected numbers
                        my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?kkum//;
                        $featureStr->{ROOT}= $token;
                        $featureStr->{LCAT}= "num";
                        $featureStr->{GEND}= "";
                        $featureStr->{NUM}= "sg";
                        $featureStr->{PERS}= "";
                        $featureStr->{CASE}= "d";
                        $featureStr->{CM}= "kku";
                        $featureStr->{SUFF}= "kku_um";
                        if($matched2 =~ /kkum/) {
                                #$featureStr->{SUFF}= "$2";
                        $featureStr->{EXTD} = " case_name=\"dat\" inc=\"Y\" inc_marker=\"um\" inc_posn=\"2\"";
                        }
			printfs(\$featureStr);
                        next;
                }
        elsif($token =~ /[0-9]+(\.[0-9]+)?-?(kkAnYa)\s*$/) { # check for inflected numbers
                        my $featureStr = {};
			$matched2 = $2;
			$token =~ s/-?kkAnYa//;
                        $featureStr->{ROOT}= $token;
                        $featureStr->{LCAT}= "num";
                        $featureStr->{GEND}= "";
                        $featureStr->{NUM}= "sg";
                        $featureStr->{PERS}= "any";
                        $featureStr->{CASE}= "d";
                        $featureStr->{CM}= "kku";
                        $featureStr->{SUFF}= "kku_AnYa";
                        if($matched2 =~ /kkAnYa/) {
                                #$featureStr->{SUFF}= "$2";
                                $featureStr->{EXTD} = " case_name=\"dat\" adj=\"AnYa\"";
                        }
			printfs(\$featureStr);
                        next;
	}
	
#to handle special characters such as punctuations.	
	if(exists $CER_hash{$token}) {
		#initialise featureStr
			my $featureStr = {};
			$featureStr->{ROOT}= $CER_hash{$token};  # the first eight entries of ILMT fs are initialised
			$featureStr->{LCAT}= "punc";
			$featureStr->{GEND}= "";
			$featureStr->{NUM}= "";
			$featureStr->{PERS}= "";
			$featureStr->{CASE}= "";
			$featureStr->{CM}= "";
			$featureStr->{SUFF}= "";
		printfs(\$featureStr);
		next;
	}
	# Single character followed by a period → unknown
	if ($token =~ /^.\.$/) {
	    print "$token(UNK)\n";
	    next;
	}
#print STDERR "$token\n";
	$token =~ s/[,?:#`'‘’“”";\-\–()@!<>\&\$\]\[~%\^\*]+//g; #removal of special characters like punctuation
	$token =~ s/\.+$//g if($token !~ /^[\w+.][\w+.][\w+]/); #remove only ending fullstops.
	$token =~ s/\.+$//g if($token =~ /^[\w+.]/); #remove only ending fullstops.
	$token =~ s/^\.+//g; #remove only beginning fullstops.
    	$modiToken  = $token;
#print STDERR "$modiToken = $token\n";

    	#$modiToken  =~ s/[.]//g;
    	#$modiToken =~ s/[kcwp]$//g;
    	#$modiToken =~ s/t$/lY/g;
    	#$modiToken =~ s/rY$/l/g;
    	#$modiToken =~ s/F$/m/g; 
    	#$modiToken =~ s/f$/m/g; 
    	#$modiToken =~ s/n$/m/g; 

		undef @perfect;
		undef $selectedlCat;

		morph($modiToken);

		#print STDERR join "~~", @perfect,"\n";
		#print join "~~", @perfect,"\n";

		if (@perfect) {
		print STDERR "\n===== PERFECT ARRAY =====\n";
		for(my $i=0;$i<@perfect;$i++){
		    print STDERR "$i : $perfect[$i]\n";
		}
		print STDERR "\n===== PERFECT ARRAY =====\n";
		for(my $i=0;$i<@perfect;$i++){
		    print STDERR "$i : $perfect[$i]\n";
		}
			finaloutput();

			# If finaloutput() produced nothing,
			# treat the token as unknown.
			if (!@finalResult) {
				print "$token(UNK)";
			}
		}
		else {
			# No analysis found
			print "$token(UNK)";
		}

		undef @finalResult;
		undef $selectedlCat;
		undef @perfect;
	
}

#dbmclose(%rootDict);
#dbmclose(%correct);
#dbmclose(%stateTableCategory);
#dbmclose(%suffixCategory);
#dbmclose(%CER_hash);
#dbmclose(%genderHash);

$endtime=(times)[0];

#print STDERR "456qazQAZqaz\n";
#&printstory_file($outputFile);

#print qq/Process started at $inittime\n/;
#print qq/Process ended at $endtime\n/;
#print ("Total number of words input : $total\n");
#print ("Number of words for which output is produced: $correct\n");

}
1;

###### new MA

#--------------------------------

sub morph {
	my $state8 = 0;
	my $inpWord8;
	@adjArr8 = ("m", "nY", "r","A");
	$bomChar = "﻿";
	$splChar200c = "‌";
	$splChar80 = "";
	$splChar99 = "";
	$splChar93 = "";

	$inpWord8 = shift @_; 
	$inpWord8 =~ s/^\s+//;
	$inpWord8 =~ s/\s+$//;
         	$inpWord8 =~ s/^[`'‘“"!@#$%^&*(),+-.:;_=?<>~â¦]+//;
         	$inpWord8 =~ s/[`'’”"!@#$%^&*(),+-.:;_=?<>~â¦]+$// if($inpWord8 !~ /^[\w+.][\w+.][\w+]/);
		$inpWord8 =~ s/$bomChar//; #removing the BOM-Byte Order Mark special(cntrl) char
		$inpWord8 =~ s/$splChar200c//; #removing the special char 200c #search pattern[Ctrl-v u200c]
                $inpWord8 =~ s/$splChar80//;  #hexcode 80
                $inpWord8 =~ s/$splChar99//;  #hexcode 99
                $inpWord8 =~ s/$splChar93//;  #hexcode 93
		#$inpWord8 =~ s/[‘’]//;
		#$inpWord8 =~ s/^\‘//;
		#$inpWord8 =~ s/\’$//;
	
	#print STDERR "$inpWord8 :: "; #------------Input Reads-------------------#	
		$input8 = $inpWord8;
		$splitMorpheme8 = "";
		$tagOut8 = "";

		#$starttime = (times)[0]; #to measure running time for each word
		#print "$starttime\n";
		morphanalysis($state8, $input8, $splitMorpheme8, $tagOut8);
		#print time(),"\n";
		#$endtime = (times)[0];
		#print "$endtime\n";
		#$timetaken = $endtime - $starttime; #to measure running time for each word
		#print (times)[0],"\n";
		#print "$inpWord time_taken=> $timetaken\n";	
}


sub morphanalysis{

    my ($mystate8, $word8, $newMorphOut8, $newTagOutput8) = @_;

    if(exists $rootDictHash8{$word8}){
        print STDERR "ROOT FOUND: $word8 => $rootDictHash8{$word8}\n";
    }

    #print STDERR "Inputs are $mystate8, $word8, $newMorphOut8, $newTagOutput8\n";

    #to check rootdictionary
    #my $morphOut  = $newMorphOut;
    #my $tagOutput = $newTagOutput;

    my (@paradigms8, $paradigmKey8, $fsakey8, $suffix8, $paradigm8,
        @nextStates8, $nextState8, $inpWord18, $modiWord8,
        $sandhiKey8, $sandhiCorr8, $remainW8);
	
	#print STDERR "Inputs are $mystate8, $word8, $newMorphOut8, $newTagOutput8\n";

	#to check rootdictionary
	#my $morphOut  = $newMorphOut;
	#my $tagOutput = $newTagOutput;

# to handle adjectives that endswith 'a'
	if($word8 =~ m/a$/ and $mystate8 eq "0" and !exists $rootDictHash8{$word8}){
		foreach $elem8 (@adjArr8){
			if($elem8 =~ /^A$/) {
				$inpWord18 = $word8;
				$inpWord18 =~ s/a$/$elem8/;
			}else{
				$inpWord18 = $word8.$elem8 if($rootDictHash8{$word8} !~ /ADV|WQ|PSP|PN/);
			}
		#	print STDERR "$inpWord18\n";
			$splitMorpheme8 = "";
			my $tagOutAdj8 = "ADJ";
			
			if($rootDictHash8{$inpWord18} =~ /,/){
			my @cmAdjArr = split(/,/, $rootDictHash8{$inpWord18});
				foreach my $cmAdjArrElem(@cmAdjArr){
					my $tagOutputAdj8 = $cmAdjArrElem."+".$tagOutAdj8;
					#my $morphOutputAdj8 = $word8.$elem8."+"."a";
					my $morphOutputAdj8 = $inpWord18."+"."a";
		#newlyadded
					if($newTagOutput8 ne undef) {
						$tagOutputAdj8 = "$newTagOutput8+$tagOutputAdj8";
						$morphOutputAdj8 = "$newMorphOut8+$morphOutputAdj8";
					}
		#newlyadded	
			#print STDERR "morphOut: $morphOutputAdj8 -- tagOut: $tagOutputAdj8\n" if(exists $rootDictHash8{$inpWord18});
					if(exists $rootDictHash8{$inpWord18}) {
						push(@perfect,$morphOutputAdj8, $tagOutputAdj8);
					}
				}
			}else{
				my $tagOutputAdj8 = $rootDictHash8{$inpWord18}."+".$tagOutAdj8;
				#my $morphOutputAdj8 = $word8.$elem8."+"."a";
				my $morphOutputAdj8 = $inpWord18."+"."a";
				
				if($newTagOutput8 ne undef) {
					$tagOutputAdj8 = "$newTagOutput8+$tagOutputAdj8";
					$morphOutputAdj8 = "$newMorphOut8+$morphOutputAdj8";
				}

				if(exists $rootDictHash8{$inpWord18}) {
					push(@perfect,$morphOutputAdj8, $tagOutputAdj8);
				}
			}
		}
	#to handle adjectives that ends with 'a' followed by [ktcpw]
	}

	if($word8 =~ m/a[kctwp]$/ and $mystate8 eq "0" and !exists $rootDictHash8{$word8}){
			$word8 =~ s/a[kctpw]$/a/;
			#print STDERR "I came here in adj ktcpw #### $word8\n";
			foreach $elem8 (@adjArr8){
	                       if($elem8 =~ /^A$/) {
        	                        $inpWord18 = $word8;
        	                        $inpWord18 =~ s/a$/$elem8/;
        	                }else{
					$inpWord18 = $word8.$elem8 if($rootDictHash8{$word8} !~ /ADV|WQ|PSP|PN/);
                 	       }
				
				$splitMorpheme8 = "";
				my $tagOutAdj8 = "ADJ";
			if($rootDictHash8{$inpWord18} =~ /,/){
				my @cmAdjArr = split(/,/, $rootDictHash8{$inpWord18});
				foreach my $cmAdjArrElem(@cmAdjArr){
					my $tagOutputAdj8 = $cmAdjArrElem."+".$tagOutAdj8;

					#my $tagOutputAdj8 = $rootDictHash8{$inpWord18}."+".$tagOutAdj8;
					#my $morphOutputAdj8 = $word8.$elem8."+"."a";
					my $morphOutputAdj8 = $inpWord18."+"."a";

					if($newTagOutput8 ne undef) {
						$tagOutputAdj8 = "$newTagOutput8+$tagOutputAdj8";
						$morphOutputAdj8 = "$newMorphOut8+$morphOutputAdj8";
					}
#print STDERR "morphOut: $morphOutputAdj8 -- tagOut: $tagOutputAdj8\n" if(exists $rootDictHash8{$inpWord18});
					if(exists $rootDictHash8{$inpWord18}) {
						push(@perfect,$morphOutputAdj8, $tagOutputAdj8);
                	        	}
			}
			}else{
				my $tagOutputAdj8 = $rootDictHash8{$inpWord18}."+".$tagOutAdj8;
				my $morphOutputAdj8 = $inpWord18."+"."a";

				if($newTagOutput8 ne undef) {
					$tagOutputAdj8 = "$newTagOutput8+$tagOutputAdj8";
					$morphOutputAdj8 = "$newMorphOut8+$morphOutputAdj8";
				}
#print STDERR "morphOut: $morphOutputAdj8 -- tagOut: $tagOutputAdj8\n" if(exists $rootDictHash8{$inpWord18});
                        	if(exists $rootDictHash8{$inpWord18}) {
					push(@perfect,$morphOutputAdj8, $tagOutputAdj8);
                        	}	
			}
                }
	}
#newlyadded	
#=cut

        if($word8 =~ /^((i)|(a)|(eV))(\w)\5/ and $mystate8 eq "0"){
	#print STDERR "$word8\n";
		$ivvDet = "ivv";
		$avvDet = "avv";
		$eVvvDet = "eVvv";
                $inpWord18 = $word8;
		my $splitMorpheme8;
		if($inpWord18 =~ /^((i)|(a)|(eV))(\w)/) {
			$splitMorpheme8 = $1;
		}
                my $tagOutDem8 = "DEM_DET";
		if($inpWord18 =~ /^(($ivvDet)|($avvDet)|($eVvvDet))/){
			my $inpWord18_tmp = $inpWord18;
			$inpWord18_tmp =~ s/^((i)|(a)|(eV))(\w)\5//;
			morphanalysis($mystate8, $inpWord18_tmp, $splitMorpheme8, $tagOutDem8);
		}
		$inpWord18 =~ s/^((i)|(a)|(eV))(\w)\5/\5/;
		#print STDERR "$mystate8, $inpWord18, $splitMorpheme8, $tagOutDem8\n";
		$inpWord18 =~ s/[kctpw]$// if($inpWord18 =~ m/[kctwp]$/ and $mystate8 eq "0" and !exists $rootDictHash8{$inpWord18}); #added by mario on 19-6 [to strip 'ktcpw' from inp word before calling morph#
		morphanalysis($mystate8, $inpWord18, $splitMorpheme8, $tagOutDem8);
        }

#--------------------

## actual morph analysis starts, here we check for root word
	#print STDERR "I am in the dict - $word8\n";
	print STDERR "WORD=<$word8>\n";
	if(exists $rootDictHash8{$word8}){
		print STDERR "ROOT FOUND: $word8 => $rootDictHash8{$word8}, state=$mystate8\n";
		#print STDERR "I am in the dict $word8\n";
		print STDERR "ROOT FOUND: $word8 => $rootDictHash8{$word8}\n";
		print STDERR "STATE = $mystate8\n";
		print STDERR "MORPH = $newMorphOut8\n";
		print STDERR "TAG = $newTagOutput8\n";
		if($mystate8 eq "0"){
			my $rootTag8 =  $rootDictHash8{$word8};
			$m_input =$word8;
			
			if($newTagOutput8 =~ /DEM_DET/) {
				#$rootTag8 = "DEM_DET+".$rootTag8;
				if($newMorphOut8 =~ /((i)|(a)|(eV))$/){
					$dem = $&;
					#print STDERR "$newMorphOut8\n";
					$m_input = "$dem+$m_input";
				}
			}

				#print STDERR "morphOut111: $word8 => $rootTag8\n";
			if($rootTag8 !~ m/,/){
				$rootTag8 = "DEM_DET+".$rootTag8 if($newTagOutput8 =~ /DEM_DET/);
				#push(@perfect,$m_input, $rootTag8) if($rootTag8 !~ /^DEM_DET\+V\d+/);
				#code modified by mario on 19-6 
				#to handle when i/p word of the categories, no need of determiner processing
				if(($rootTag8 !~/^DEM_DET/) && ($rootTag8 =~ /^((ADV)|(ADJ)|(WQ)|(PN)|(PSP))/i)){
					undef @perfect;
					push(@perfect,$m_input, $rootTag8);
					$selectedlCat = 1;
					#print STDERR "$selectedlCat\n qazxsw\n";
				}else{
					push(@perfect,$m_input, $rootTag8) if($rootTag8 !~ /^DEM_DET\+V\d+/);
				} #code modified by mario on 19-6
			}else{
				#print STDERR "morphOut112: $word8 => $rootTag8\n";
				undef @rootTagArr8;
				@rootTagArr8 = split(/,/, $rootTag8);
				#print STDERR "morphOut113: @rootTagArr8 = $newTagOutput8\n";
				foreach $newRootTag8 (@rootTagArr8){
					$newRootTag8 = "DEM_DET+".$newRootTag8 if($newTagOutput8 =~ /DEM_DET/);
					next if($newRootTag8 =~ /^DEM_DET\+V\d+/);

					if(($newRootTag8 !~/^DEM_DET/) && ($newRootTag8 =~ /^((ADV)|(WQ)|(PN)|(PSP))/i)){
						$selectedlCat = 1;
						#print STDERR "$selectedlCat\n qazxsw\n";
					}
				#print STDERR "morphOut113: $m_input = $newRootTag8\n";
					push(@perfect,$m_input, $newRootTag8);
				}
			}
		}else{
			#print STDERR  "$word8 -- $rootDictHash8{$word8}\n";
			if($rootDictHash8{$word8} =~ /\,/){
				@paradigms8 = split(/,/, $rootDictHash8{$word8});
			}else{
				push(@paradigms8, $rootDictHash8{$word8});
			}

			#print STDERR join "---", @paradigms8,"\n";
			foreach $paradigm8(@paradigms8){
				$paradigmKey8 = $mystate8."_".$paradigm8;
				print STDERR "PARAKEY = $paradigmKey8\n";
				print STDERR "FOUND PARAKEY\n";
				#print STDERR "para_key $paradigmKey8\n";
				if (exists $fsaHash8{$paradigmKey8}){
				print STDERR "PUSHED:\n";
				print STDERR "MORPHOUT = $morphOut8\n";
				print STDERR "TAGOUT   = $tagOutput8\n";
				print STDERR "FOUND PARAKEY\n";
					#print STDERR "$word8, $rootDictHash{$word8}\n";
					my $morphOut8 = $word8."+".$newMorphOut8;
					my $tagOutput8 = $paradigm8."+".$newTagOutput8;
					$morphOut8 =~ s/\+\s*$//;
					$tagOutput8 =~ s/\+\s*$//;
					
					if(($tagOutput8 =~ /\+DEM_DET$/) && ($morphOut8 =~ /\+((i)|(a)|(eV))$/)) {
						$tagOutput8 =~ s/\+DEM_DET$//;
						$tagOutput8 = "DEM_DET+".$tagOutput8;
						if($morphOut8 =~ /\+((i)|(a)|(eV))$/) {
							$det8 = $1;
							$morphOut8 =~ s/\+$det8$//;
							$morphOut8 = "$det8+".$morphOut8;
						}
					}
					#print STDERR "morphOut: $morphOut8 -- tagOut: $tagOutput8\n";
					if($tagOutput8 =~ /DEM_DET/) {
						push(@perfect, $morphOut8, $tagOutput8) if($tagOutput8 =~ /\+((N\d+)|(VN))/);
					}else{
						push(@perfect, $morphOut8, $tagOutput8);
					}
					#print "$morphOut -- $tagOutput\n";
				}
			}
		}
	}
	#else{
	#to strip ckptw from input words & check in rootDict
	if($mystate8 eq "0") {
		$tmp_word8 =$word8;
		if($tmp_word8 =~ /[kctpw]$/) {
			$tmp_word8 =~ s/[ckptw]$//;
			#print "morphOut: $tmp_word8 => $rootDictHash8{$tmp_word8}\n" if(exists $rootDictHash8{$tmp_word8});
			if(exists $rootDictHash8{$tmp_word8}) {
                        	if($newTagOutput8 =~ /DEM_DET/) {
                        	        $rootTag8 = "DEM_DET+".$rootTag8;
                        	        if($newMorphOut8 =~ /((i)|(a)|(eV))$/){
                        	                $dem = $&;
                        	                #print STDERR "$newMorphOut8\n";
                        	                $tmp_word8 = "$dem+$tmp_word8";
                        	        }
                       		 }

				my $rootTag8 =  $rootDictHash8{$tmp_word8};
				if($rootTag8 !~ m/,/){
					push(@perfect,$tmp_word8, $rootTag8);
				}else{
					undef @rootTagArr8;
					@rootTagArr8 = split(/,/, $rootTag8);
					foreach $newRootTag8 (@rootTagArr8){
						push(@perfect,$tmp_word8, $newRootTag8);
					}
				}
			}
		}
=c
	else{
			$nextState8 = 0;
			$modiWord8 = $tmp_word8;
			$morphOut8 = "";
			$tagOutput8 = "";
			morphanalysis($nextState8, $modiWord8, $morphOut8, $tagOutput8);
		}
=cut
	}
	#if($mystate8 eq "0") {			#to strip ckptw from input words & process the word
		#$word8 =~ s/[ckptw]$//;
		#print STDERR "~~~~~~~$word8\n";
	#}


##  morph analysis here we check for possible suffixes
	foreach $suffix8 (keys %suffixHash8) {
		if($word8 =~ /$suffix8$/){
		    print STDERR "MATCHED SUFFIX $suffix8 FOR $word8\n";
		}
		#print "$word8 ---- $suffix8\n";
		next if($suffix8 eq "");
		if($word8 =~ /$suffix8$/){
			#print "~~~~~~~$word8 ---- $suffix8\n";
			$remainW8 = $`;
			#to form fsa key for retrieving next state
			$fsakey8 = $mystate8."_".$suffix8;
			#print "FSA key $fsakey8--\n";

			#possible next states
			if($fsaHash8{$fsakey8} =~ /\,/){
				@nextStates8 = split(/,/, $fsaHash8{$fsakey8});
			}else{
				push(@nextStates8, $fsaHash8{$fsakey8});
			}
	
				
			foreach $nextState8 (@nextStates8){

				#to form sandhi key for sandhi correction
				$sandhiKey8 = $mystate8."_".$nextState8."_".$suffix8;
				#print "SANDHIKEY-$sandhiKey\n";
				if(exists $sandhiHash8{$sandhiKey8}){	
					$sandhiCorr8 = $sandhiHash8{$sandhiKey8};
					#print "SANDHICORR-$sandhiCorr\n";
					
					#sandhi replacement
					$modiWord8 = "$remainW8$sandhiCorr8";
				}else{
					$modiWord8 = "$remainW8";
					print STDERR "STATE=$nextState8 WORD=$modiWord8 MORPH=$morphOut8 TAG=$tagOutput8\n";
				}
				if(exists $tagHash8{$sandhiKey8}) {	
					#print "Modified word = $modiWord\n Next State = $nextState\n";
					my $morphOut8 = "$suffix8+$newMorphOut8";
					#print "MORPHOUT SUFF---$suffix---\n";
					#print "MORPHOUT---$morphOut--\n";
#########################################
					if($tagHash8{$sandhiKey8} =~ /\,/) {
						undef $possibletag8;
						#print "~~~ $tagHash{$sandhiKey}\n";
						foreach $possibletag8 (split(/\,/, $tagHash8{$sandhiKey8})) {
							my $tagOutput8 = "$possibletag8+$newTagOutput8";
							#print "NS-$nextState\tMW-$modiWord\tMOUT-$morphOut\tTAGOUT-$tagOutput\n";
							morphanalysis($nextState8, $modiWord8, $morphOut8, $tagOutput8);
						}
					}else{
						my $tagOutput8 = "$tagHash8{$sandhiKey8}+$newTagOutput8";
						#print "NS-$nextState\tMW-$modiWord\tMOUT-$morphOut\tTAGOUT-$tagOutput\n";
						morphanalysis($nextState8, $modiWord8, $morphOut8, $tagOutput8);
					}

########################################
				}
			}
		}
	}#foreach_suffix_ends_here
	#}#main_else_ends_here
}


###############

sub finaloutput()
{
	#orderOutput();
	undef @finalResult;
	#print join "\n", @perfect,"\n";
	#print "~~~~~~~\n";
	for($ijij = 0;$ijij < @perfect;$ijij++){
		@mList = split(/\+/,$perfect[$ijij]);
		@tList = split(/\+/,$perfect[$ijij+1]);
	
		$l1 = @mList;
		$l2 = @tList;
		undef $outL;
		if($l1 == $l2){
			for($i10 = 0;$i10 < @mList;$i10++) {
				$checkAllo = "$tList[$i10]\_$mList[$i10]";
				$morphE = $mList[$i10];
				#print "Allo check: $checkAllo\n";

				if(exists $alloMorphMappingHash8{$checkAllo}) {
					$morphE = $alloMorphMappingHash8{$checkAllo};
					#print "$morphE\n";
				
				}
				$outL = $outL."+"."$morphE($tList[$i10])";
			}
			$outL =~ s/^\+//;
			#print "~~~~~$outL\n";
			push(@finalResult, $outL);
		}else{
			$outL = "$perfect[$ijij]($perfect[$ijij+1])";
			push(@finalResult, $outL);
		}
		$ijij++;
	}
	if (@finalResult) {
    print join "|", @finalResult;
	}
	else {
	    print "$token(UNK)";
	}	
	#print "~~~~~~~\n";
	#print_result();
}

1;

sub isCorrect()
{
	my $tag = $_[0];
	foreach $ct (keys %correct) {
		$ct =~ s/\+/\\+/g;
		if($tag =~ /^$ct$/) {
			return 1;
		}
	}
	return 0;
}


sub printfs() #Print the feature Structure generated
{
	$refFS = shift;

	my $fsString = "";
	$fsString = "<fs af='".${$refFS}->{ROOT}.",";
	${$refFS}->{LCAT} =~ s/([a-z]+)\d+/$1/g;
	${$refFS}->{LCAT} =~ s/dem_det/pn/;	# for ilmt
	${$refFS}->{LCAT} =~ s/fw/any/;	# for ilmt
	#${$refFS}->{LCAT} =~ s/wq/pn/;	# for ilmt
	${$refFS}->{LCAT} =~ s/det/pn/;	# for ilmt
	${$refFS}->{GEND} =~ s/c/mf/;	# for ilmt
	$fsString .= ${$refFS}->{LCAT}.",";
	if(${$refFS}->{LCAT} !~ /^(unk|punc|num)$/ and ${$refFS}->{GEND} eq "") {
		${$refFS}->{GEND} = "any";
	}
	if(${$refFS}->{LCAT} !~ /^(unk|punc|num)$/ and ${$refFS}->{NUM} eq "") {
		${$refFS}->{NUM} = "any";
	}
	if(${$refFS}->{LCAT} !~ /^(unk|punc|num)$/ and ${$refFS}->{PERS} eq "") {
		${$refFS}->{PERS} = "any";
	}
	if(${$refFS}->{LCAT} =~ /^(n|pn)$/) {
		$fsString .= ${$refFS}->{GEND}; 
		$fsString =~ s/h$/mf/;
		$fsString .= ",".${$refFS}->{NUM}.",";
		$fsString .= ${$refFS}->{PERS}.",";
		$fsString .= ${$refFS}->{CASE}.",";
		$fsString .= ${$refFS}->{CM}.",";
		$fsString .= ${$refFS}->{SUFF}."'";
		if(${$refFS}->{EXTD}) {
			$fsString .= ${$refFS}->{EXTD};
		}
		$fsString .= ">";
	}
	elsif(${$refFS}->{LCAT} =~ /^v$/) {
		${$refFS}->{EXTD} =~ s/ case_name=\"nom\"//;
		$fsString .= ${$refFS}->{GEND}; 
		$fsString =~ s/h$/mf/;
		$fsString .= ",".${$refFS}->{NUM}.",";
		$fsString .= ${$refFS}->{PERS}.",";
		$fsString .= ${$refFS}->{CASE}.",";
		${$refFS}->{TAM} =~ s/^\_//;
		$fsString .= ${$refFS}->{TAM}.",";
		$fsString .= ${$refFS}->{SUFF}."'"; 
		if(${$refFS}->{EXTD}) {
			$fsString .= ${$refFS}->{EXTD};
			}
		$fsString .= ">";
	}
	elsif(${$refFS}->{LCAT} =~ /^punc$/) {
		$fsString .= ${$refFS}->{GEND}; 
		$fsString .= ",".${$refFS}->{NUM}.",";
		$fsString .= ${$refFS}->{PERS}.",";
		$fsString .= ${$refFS}->{CASE}.",";
		$fsString .= ${$refFS}->{CM}.",";
		$fsString .= ${$refFS}->{SUFF}."'>";
	}
	else {
		${$refFS}->{EXTD} =~ s/ case_name=\"nom\"//;
		$fsString .= ${$refFS}->{GEND}; 
		$fsString .= ",".${$refFS}->{NUM}.",";
		$fsString .= ${$refFS}->{PERS}.",";
		$fsString .= ${$refFS}->{CASE}.",";
		$fsString .= ${$refFS}->{CM}.",";
		$fsString .= ${$refFS}->{SUFF}."'";
		if(${$refFS}->{EXTD}) {
			$fsString .= ${$refFS}->{EXTD};
		}
		$fsString .= ">";
	}
	$fsString =~ s/,h,/,mf,/;
	#print STDERR "$fsString\n";

	if(${$refFS}->{LCAT}) {
	    print "$fsString\n";
	}
}
1;


sub readCopula
{
$Copula{"Akum"} = 1;
$Copula{"AnYawu"} = 1;
$Copula{"AyirYrYu"} = 1;
$Copula{"AvAnY"} = 1;
$Copula{"AvAlY"} = 1; 
$Copula{"AvAr"} = 1;
$Copula{"Avar"} = 1;
$Copula{"AvArkalY"} = 1;

}

sub readExistential
{
$Existential{"uNtu"}=1;
$Existential{"illE"}=1;
$Existential{"ulYlYawu"}=1;
$Existential{"ulYlYanYar"}=1;
$Existential{"ulYlYanYa"}=1;
}


############################### Resource Required & provided here 
sub readrootDict{
        my ($lined8, @dictarr8,$value8);
	#open(FHR8,"<","mal_dict/dictionary.txt") or die "what about the dictionary file!!\n";
        open(FHR8,"<","dict_all.txt") or die "what about the dictionary file!!\n";
        while($lined8 = <FHR8>){
		$lined8 =~ s/\cM//;
                chomp($lined8);
                next if($lined8 =~ m/^\s*$/);
		next if $lined8 =~ m/^\#+/;
                        $lined8 =~ s/^\s+//;
                        $lined8 =~ s/\s+$//;

                @dictarr8 = split(/,/, $lined8);
                $value8 = $dictarr8[1].$dictarr8[2];
                $key81 = "$dictarr8[0]\_$dictarr8[1]";

		if (exists $rootDictHash8{$dictarr8[0]}){
			$rootDictHash8{$dictarr8[0]} = $rootDictHash8{$dictarr8[0]}.",".$value8;
		}else{
			$rootDictHash8{$dictarr8[0]} = $value8;
		}

		# Debugging
		if($dictarr8[0] eq ""){
			print STDERR "EMPTY ROOT FOUND: $value8\n";
			print STDERR "BAD LINE: $lined8\n";
		}
		if($dictarr8[4] =~ /^\w+$/) {
			$genderHash{$key81} = lc($dictarr8[4]);
		}
        }
        close(FHR8);
}

sub readNEdict{
        my ($linen8, @nedictarr8,$nevalue8);
        open(FHN8,"<","$morph_data_bin/nedict.txt") or die "what about the NEdictionary file!!\n";
        while($linen8 = <FHN8>){
		$linen8 =~ s/\cM//;
                chomp($linen8);
                next if($linen8 =~ m/^\s*$/);
		next if $linen8 =~ m/^\#+/;
                        $linen8 =~ s/^\s+//;
                        $linen8 =~ s/\s+$//;

                @nedictarr8 = split(/,/, $linen8);
                $nevalue8 = $nedictarr8[1].$nedictarr8[2];

                if (exists $rootDictHash8{$nedictarr8[0]}){
                        $rootDictHash8{$nedictarr8[0]} = $rootDictHash8{$nedictarr8[0]}.",".$nevalue8;
                }else{
                        $rootDictHash8{$nedictarr8[0]} = $nevalue8;
                }
        }
        close(FHN8);
}

sub readFsa{
        my ($linef8, @fsaarr8,$value8, @symbol8, $key18, $key28);
	#open(FHF8,"<","dfsa_220126.txt") or die "what about the FSA file! $!\n";
        open(FHF8,"<","dfsa_270526.txt") or die "what about the FSA file! $!\n";
        while($linef8 = <FHF8>){
		$linef8 =~ s/\cM//;
		chomp($linef8);
		next if($linef8 =~ m/^\s*$/);
                	$linef8 =~ s/^\s+//;
                	$linef8 =~ s/\s+$//;

                @fsaarr8 = split(/\t/, $linef8);

		@symbol8 = split(/_/, $fsaarr8[2]);
		$key18 = $fsaarr8[0]."_".$symbol8[0];
		$key28 = $fsaarr8[0]."_".$fsaarr8[1]."_".$symbol8[0];

		if (exists $fsaHash8{$key18}){
                        $fsaHash8{$key18} = $fsaHash8{$key18}.",".$fsaarr8[1];
                }else{
                        $fsaHash8{$key18} = $fsaarr8[1];
                }

		if($symbol8[0] !~ /((PN)|(N)|(V))\d+/){ 
			if(exists $sandhiHash8{$key28}){
			$sandhiHash8{$key28} = $sandhiHash8{$key28}.",".$symbol8[1] if($symbol8[1] !~ /\#/);
				$tagHash8{$key28} = $tagHash8{$key28}.",".$symbol8[2];
			}else{
				$sandhiHash8{$key28} = $symbol8[1] if($symbol8[1] !~ /\#/);
				$tagHash8{$key28} = $symbol8[2];
			}
		}

		if($symbol8[0] !~ /((PN)|(N)|(V))\d+/){
			$suffixHash8{$symbol8[0]}++;
		}
        }
#added on 24-4-13
        foreach my $v8 (sort keys %sandhiHash8){
                if($sandhiHash8{$v8} =~ /\,/) {
                        #print "$v\n";
                        undef %uniqSandhiCorr8;
                        foreach $Corr8 (split(/\,/,$sandhiHash8{$v8})) {
                                $uniqSandhiCorr8{$Corr8}++;
                        }
                        $finalCorr8 = join ",", keys%uniqSandhiCorr8;
                        $finalCorr8 =~ s/^\,//;
                        $finalCorr8 =~ s/\,$//;

                        $sandhiHash8{$v8} = $finalCorr8;
                        #print "$v -- $finalCorr\n";
                }
        }

        foreach my $v8 (sort keys %fsaHash8){
                if($fsaHash8{$v8} =~ /\,/) {
                        #print "$v\n";
                        undef %uniqState8;
                        foreach $uniqS8 (split(/\,/,$fsaHash8{$v8})) {
                                $uniqState8{$uniqS8}++;
                        }
                        $finalS8 = join ",", keys%uniqState8;
                        $finalS8 =~ s/^\,//;
                        $finalS8 =~ s/\,$//;

                        $fsaHash8{$v8} = $finalS8;
                        #print "$v -- $finalCorr\n";
                }
        }
#added on 24-4-13
	close(FHF8);

	#foreach $kk (keys%fsaHash8) {
	#	print "$kk\n";
	#}
}



sub readAlloMorphMappingInfo {
        my ($alloLine8, @allomorpheme8);
	#open(FHAL8,"<","$morph_data_bin/alloMorphMappingFile.txt") or die "what about alloMorphMapping file!!\n";
        open(FHAL8,"<","alloMorphMappingFile.txt") or die "what about alloMorphMapping file!!\n";
        while($alloLine8 = <FHAL8>){
                chomp($alloLine8);
                next if($alloLine8 =~ /^\s*$/);

                $alloLine8 =~ s/^\s+//;
                $alloLine8 =~ s/\s+$//;
			
                @allomorpheme8 = split(/\t\-+>\t/, $alloLine8);
		if($allomorpheme8[1] =~ m/,/){
			@alloMorphs8 = split(/,/, $allomorpheme8[1]);
			foreach $alloMorphElem8 (@alloMorphs8){
				$alloMorphMappingHashKey8 = $allomorpheme8[0]."_".$alloMorphElem8;
				$alloMorphMappingHashVal8 = $allomorpheme8[2];
				$alloMorphMappingHash8{$alloMorphMappingHashKey8} = $alloMorphMappingHashVal8;
			}
		}else{	
				$alloMorphMappingHashKey8 = $allomorpheme8[0]."_".$allomorpheme8[1];
				$alloMorphMappingHashVal8 = $allomorpheme8[2];
				$alloMorphMappingHash8{$alloMorphMappingHashKey8} = $alloMorphMappingHashVal8;
		}
	}

	#foreach $jujuj (keys%alloMorphMappingHash8){
	#	print "$jujuj -- $alloMorphMappingHash8{$jujuj}\n";
	#}

}
1; #won't return anything

###########@###################### @@@@ ###########@###################### @@@ ###########@######################
