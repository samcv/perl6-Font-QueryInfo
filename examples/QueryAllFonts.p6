#!/usr/bin/env perl6
use lib 'lib';
use Font::QueryInfo;
sub MAIN (Str:D $folder = '.') {
    my @fonts = dir($folder).grep(/:i otf|ttf $ /);
    die "Couldn't find any fonts in {$folder.IO.absolute} specify a correct one as an argument" if !@fonts;
    say font-query-all($_) for @fonts;
}