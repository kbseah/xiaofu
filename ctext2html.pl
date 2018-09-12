#!/usr/bin/env perl

=head1 NAME

ctext2html.pl - Convert extended Ctext wiki markup to HTML

=head1 SYNOPSIS

perl ctext2html.pl -i <file.markup> -o <file.html>

=head1 DESCRIPTION

Convert marked-up text to HTML file with contents and index.

=head1 EXTENDED CTEXT WIKI MARKUP

The basic wiki markup used by the Ctext project is described on their website
http://ctext.org/instructions/wiki-formatting

Extended with a number of additional tags:

=over 8

=item `

(at beginning of line) Translation

=item `*

(At beginning of line) Translation header 1

=item `**

(At beginning of line) Translation header 2

=item ``

(At beginning of line) Whole-line editorial comment

=item {nn/ ... /nn}

Personal name

=item {gg/ ... /gg}

Geographical name

=item {dd/ ... /dd}

Calendrical date

=item {pg/ ... /pg}

Page number in source text

=item {ed/ ... /ed}

In-line editorial comment (i.e. not in source text)

=item {l/ ... /l <URL>}

Hyperlink; note space before the URL begins

=back

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2016, Brandon Seah (kb.seah@gmail.com)

=cut


# To do:
# Index names of literary works too
# Sort index and duplicate entries
# Tooltip editorial comments or show-hide them
# For extended tags - allow two versions - display text and indexed text (e.g. variant names, abbreviations)

# Draft specification for extended Ctext markup

# Basic ctext markup:
# * (at start of line) - level 1 header
# ** (at start of line) - level 2 header
# {} - characters printed in larger text
# {{}} - characters in smaller text
# {{{}}} - marginal notes
# \n - New paragraph (i.e. each line that is not a header is a paragraph)
# | - non-paragraph line break (e.g. poetry)
# ● - Missing character
# ●=...= Missing char, with description of missing character between the = signs

# Extended markup:
# ` (at start of line) - translation
# `* - Translation header 1
# `** - Translation header 2
# `` - Editorial comment (whole line)
# [] - Enclose a variant character
# {xyz/ ... /xyz} - Semantic markup; xyz is a code for the semantic category, should be ASCII word char.
# They may not span a linebreak!
# Suggested values for semantic markups:
# nn - personal names
# gg - geographical names
# dd - dates
# pg - page number in source text
# v - graphical variant character
# ed - inline editorial comment

use strict;
use warnings;
use utf8;
use Encode;
use Getopt::Long;
use List::MoreUtils qw(zip);
use Pod::Usage;

my $filein;
my $fileout;
my $ctext_scan_url;

if (! @ARGV) {
    pod2usage(-exitstatus=>2,-verbose=>2);
}

GetOptions (
    "input|i=s" => \$filein,
    "output|o=s" => \$fileout,
    "ctext_scan_url=s" => \$ctext_scan_url,
    "help|h" => sub { pod2usage(-existatus=>2, verbose=>2); },
    "man|m" => sub { pod2usage(-existatus=>0, verbose=>2); }
) or pod2usage(-message=>"Incorrect input options",-existatus=>2, verbose=>2);

=head1 ARGUMENTS

=over 8

=item --input|-i I<FILE>

=item --output|-o I<FILE>

=item --ctext_scan_url I<URL>

URL prefix for digital base text, used to convert embedded page numbers to hyperlinks.

E.g. "https://ctext.org/library.pl?if=en&file=92728&page="

=item --help|-h

=item --man|-m

=back

=cut

# Hashes for header lines
my %h1hash;
my %h2hash;
my %xtag_hash; # Hash for tags
my %tagid; # Counter for tagids

my %xtags_toindex = (
    nn => 'Personal names',
    gg => 'Geographical names',
    dd => 'Dates',
);
my @xtags = qw(nn gg dd pg v ed l); # List of extended tags
my @content_xtags = qw(ed l); # Tags with content fields
my @output; # array to store lines for HTML body
my %current_header;

# Set output coding to UTF-8
binmode (STDOUT, ":utf8");

# Read input and convert
open(IN, "<", $filein) or die ($!);
while (<IN>) {
    chomp;
    if (m/^#/) { # Skip comment lines
        next;
    }
    my $line = $_;
    $line = decode_utf8($line);
    $line = ConvertPunc($line) unless $line =~ m/^`/;

    # Catch missing text - has to be done first because HTML tags have "=" sign
    $line = ConvertMissingText($line) unless $line =~ m/^`/;

    # Catch headers
    if ($line =~ m/^\*\*(.*)/) {
        my $id = scalar (keys %h2hash);
        $h2hash{"h2_$id"}{"name"} = $1; # hash the h2 level headings
        $h2hash{"h2_$id"}{"above"} = $current_header{"h1"}; # record which h1 header this h2 header falls under
        $line = "<h2 id=\"h2_$id\">".$1."<a class=\"superscript\" href=\"\#".$current_header{"h1"}."\">^</a></h2>";
        $current_header{"h2"} = "h2_$id"; # update current h2 header
        #print $current_header{"h1"}."\n";
    } elsif ($line =~ m/^\*(.*)/) {
        my $id = scalar (keys %h1hash);
        $h1hash{"h1_$id"}{"name"} = $1;
        $line = "<h1 id=\"h1_$id\">".$1."</h1>";
        $current_header{"h1"} = "h1_$id"; # update current h1 header
        #print $current_header{"h1"}."\n";
    } elsif ($line =~ m/^`(.*)/) {
        if ($line =~ m/^``(.*)/) { # Whole-line editorial commentary
            my $content = $1;
            $line = "<div class=\"comment\"><p>".$content."</p></div>";
        } else { # Translation lines
            my $content = $1;
            if ($line =~ m/^`\*\*([^`]*)/) {
                $line = "<div class=\"translation\"><h2>".$1."</h2></div>";
            } elsif ($line =~ m/^`\*([^`]*)/) {
                $line = "<div class=\"translation\"><h1>".$1."</h1></div>";
            } else {
                $line = "<div class=\"translation\"><p>".$content."</p></div>";
            }
        }
    } else {
        $line = "<p>".$line."</p>";
    }

    # The following not bracketed in else condition - headers can also be semantically tagged

    # Convert semantic tags (which are indexed)
    foreach my $tag (@xtags) {
        # Hash the tagged values
        my @list = ($line =~ m/\{$tag\/(.*?)\/$tag\}/g);
        foreach my $tagname (@list) {
            my $id = scalar (keys %{$xtag_hash{$tag}});
            $xtag_hash{$tag}{"$tag\_$id"} = $tagname;
        }
        # Now convert line from markup to HTML
        my $p1 = "<span class=\"$tag\" id=\"$tag\_";
        my $p2 = "\">";
        my $p3 = "</span>";
        # Replace the markup tags with html span tags in an evaluated regex
        $line =~ s/\{$tag\/(.*?)\/$tag\}/$p1.$tagid{$tag}++.$p2.$1.$p3/ge;
    }

    # Convert hyperlinks
    my $p1 = "<a href=\"";
    my $p2 = "\">";
    my $p3 = "</a>";
    $line =~ s/\{l\/(.*?)\/l\s+(.*?)\}/$p1.$2.$p2.$1.$p3/ge;

    # Convert page numbers to hyperlinks if defined
    $line = ConvertPageLinks($line, $ctext_scan_url) if defined $ctext_scan_url;

    # Convert remaining tag types (must be done in order, but not indexed)
    $line = ConvertMarginalNotes($line);
    $line = ConvertSmallerText($line);
    $line = ConvertLargerText($line);


    # Store line
    push @output, $line;
}

close(IN);

# Print report
open(OUT, ">", $fileout) or die ($!);
binmode (OUT, ":utf8");

print OUT <<ENDHTML;
<!DOCTYPE html>
<html>

<head>
    <meta charset="UTF-8">
    <link rel="stylesheet" type="text/css" href="stylesheet.css">
</head>

<body>
ENDHTML

print OUT<<ENDHTML;
<ul class="navbar">
<li class="navbar"><a href="#divfrontmatter">Contents</a></li>
<li class="navbar"><a href="#divmainmatter">Text</a></li>
<li class="navbar"><a href="#divendmatter">Index</a></li>
<li class="navbarhome"><a href="index.html">Home</a></li>
</ul>
<div class="frontmatter" id="divfrontmatter">
<h1>Contents</h1>
ENDHTML

print OUT "<ul class=\"contents\">\n";
foreach my $key (sort {$a cmp $b} keys %h1hash) {
    print OUT "<li class=\"contents\"><a href=\"\#".$key."\">".$h1hash{$key}{"name"}."</a>\n";
    print OUT "<ul class=\"contents\">\n";
    foreach my $key2 (sort {$a cmp $b} keys %h2hash) {
        if (defined $h2hash{$key2}{"above"} && $h2hash{$key2}{"above"} eq $key) {
            print OUT "<li class=\"contents\"><a href=\"\#".$key2."\">".$h2hash{$key2}{"name"}."</a>\n";
        }
    }
    print OUT "</ul>\n";
}
print OUT "</ul>\n";

print OUT<<ENDHTML;
</div>
ENDHTML

print OUT <<ENDHTML;
<div class="mainmatter" id="divmainmatter">
ENDHTML

foreach my $theline (@output) {
    print OUT $theline."\n";
}

print OUT <<ENDHTML;
</div>
ENDHTML

if (%xtag_hash) {
print OUT <<ENDHTML;
<div class="endmatter" id="divendmatter">
<h1>Index</h1>
ENDHTML

foreach my $tag (keys %xtags_toindex) {
    if (defined $xtag_hash{$tag}) {
        print OUT "<p>";
        print OUT $xtags_toindex{$tag}."\t";
        print OUT join "\t", printEndmatter($tag);
        print OUT "</p>\n";
    }
}

print OUT <<ENDHTML;
</div>
ENDHTML
}

print OUT <<ENDHTML;
<p class="credit">Translations copyright (c) 2016-2018 Brandon Seah.</p>
</body>
</html>
ENDHTML

close (OUT);

## SUBS #######################################################################

sub printEndmatter {
    my ($tag) = @_;
    my @out;
    foreach my $id (sort {$a cmp $b} keys %{$xtag_hash{$tag}}) {
        push @out, "<a href=\"\#".$id."\">".$xtag_hash{$tag}{$id}."</a>";
    }
    return @out;
}

sub ConvertPunc {
    # Convert European punctuation to Chinese
    my ($theline) = @_;
    #$line =~ s/[.,;"'?!#()“”‘’。，、！？﹔；：「」『』【】（）()\d\s]//g
    $theline =~ s/\./。/g;
    $theline =~ s/,/，/g;
    $theline =~ s/!/！/g;
    $theline =~ s/\?/？/g;
    $theline =~ s/“/「/g;
    $theline =~ s/”/」/g;
    $theline =~ s/‘/『/g;
    $theline =~ s/’/』/g;
    $theline =~ s/＊/\*/g;
    $theline =~ s/\[/［/g;
    $theline =~ s/\]/］/g;
    # convert semantic tags to European
    $theline =~ s/｛/{/g;
    $theline =~ s/｝/}/g;
    return $theline;
}

sub ConvertMarginalNotes {
    my ($inline) = @_;
    my @list = ($inline =~ m/\{\{\{(.*?)\}\}\}/g);
    # Now convert line from markup to HTML
    my $p1 = "<span class=\"marginal\">";
    my $p2 = "</span>";
    # Replace the markup tags with html span tags in an evaluated regex
    $inline =~ s/\{\{\{(.*?)\}\}\}/$p1.$1.$p2/ge;
    return ($inline);
}

sub ConvertSmallerText {
    my ($inline) = @_;
    my @list = ($inline =~ m/\{\{(.*?)\}\}/g);
    # Now convert line from markup to HTML
    my $p1 = "<span class=\"smallerText\">";
    my $p2 = "</span>";
    # Replace the markup tags with html span tags in an evaluated regex
    $inline =~ s/\{\{(.*?)\}\}/$p1.$1.$p2/ge;
    return ($inline);
}

sub ConvertLargerText {
    my ($inline) = @_;
    my @list = ($inline =~ m/\{(.*?)\}/g);
    # Now convert line from markup to HTML
    my $p1 = "<span class=\"largerText\">";
    my $p2 = "</span>";
    # Replace the markup tags with html span tags in an evaluated regex
    $inline =~ s/\{(.*?)\}/$p1.$1.$p2/ge;
    return ($inline);
}

sub ConvertMissingText {
    my ($inline) = @_;
    my @list = ($inline =~ m/=(.*?)=/g);
    # Now convert line from markup to HTML
    my $p1 = "<span class=\"missingText\">缺字：";
    my $p2 = "</span>";
    # Replace the markup tags with html span tags in an evaluated regex
    $inline =~ s/=(.*?)=/$p1.$1.$p2/ge;
    return ($inline);
}

sub ConvertPageLinks {
    my ($inline, $urlprefix) = @_;
    my $p1 = '<a class="superscript" href="'.$urlprefix;
    my $p2 = '">';
    my $p3 = '</a>';
    $inline =~ s/\{pp\/(\d+)\/pp\}/$p1.$1.$p2.$1.$p3/ge;
    return ($inline);
}
