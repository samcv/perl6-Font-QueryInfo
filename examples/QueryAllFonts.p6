#!/usr/bin/env perl6
use lib 'lib';
use Font::QueryInfo;
sub test-it {
    say font-query-all($_) for dir.grep(/:i otf|ttf $ /);
}
test-it;