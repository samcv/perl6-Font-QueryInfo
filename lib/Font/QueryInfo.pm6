#!/usr/bin/env perl6
=begin pod
=NAME Font::QueryInfo — Queries information about fonts, including name,
style, family, foundry, and the character set the font covers.
=DESCRIPTION Easy to use routine's font-query and font-query-all are available
which query information about the font and return it in a hash. The keys are
the names of the properties and the values are the property values.

These are the properties that are available:
=begin code
family          String  Font family names
familylang      String  Languages corresponding to each family
style           String  Font style. Overrides weight and slant
stylelang       String  Languages corresponding to each style
fullname        String  Font full names (often includes style)
fullnamelang    String  Languages corresponding to each fullname
slant           Int     Italic, oblique or roman
weight          Int     Light, medium, demibold, bold or black
size            Double  Point size
width           Int     Condensed, normal or expanded
aspect          Double  Stretches glyphs horizontally before hinting
pixelsize       Double  Pixel size
spacing         Int     Proportional, dual-width, monospace or charcell
foundry         String  Font foundry name
antialias       Bool    Whether glyphs can be antialiased
hinting         Bool    Whether the rasterizer should use hinting
hintstyle       Int     Automatic hinting style
verticallayout  Bool    Use vertical layout
autohint        Bool    Use autohinter instead of normal hinter
globaladvance   Bool    Use font global advance data (deprecated)
file            String  The filename holding the font
index           Int     The index of the font within the file
ftface          FT_Face Use the specified FreeType face object
rasterizer      String  Which rasterizer is in use (deprecated)
outline         Bool    Whether the glyphs are outlines
scalable        Bool    Whether glyphs can be scaled
scale           Double  Scale factor for point->pixel conversions
dpi             Double  Target dots per inch
rgba            Int     unknown, rgb, bgr, vrgb, vbgr, none - subpixel geometry
lcdfilter       Int     Type of LCD filter
minspace        Bool    Eliminate leading from line spacing
charset         CharSet Unicode chars encoded by the font
lang            String  List of RFC-3066-style languages this font supports
fontversion     Int     Version number of the font
capability      String  List of layout capabilities in the font
embolden        Bool    Rasterizer should synthetically embolden the font
fontfeatures    String  List of the feature tags in OpenType to be enabled
prgname         String  String  Name of the running program
=end code

Strings return Str, Bool returns Bool's, Int returns Int's, Double's listed
above return Rat's. CharSet returns a list of Range objects. The rest all
return Str.
=end pod
my @rows = $=pod[0].contents[3].contents.join.lines».split(/\s+/, 3);
my %data;
for ^@rows {
    %data{@rows[$_][0]} = %( 'type' => @rows[$_][1], 'description' => @rows[$_][2] );
}
my @fields = %data.keys;
#test-it;
#| Queries all of the font's properties. If supplied properties it will query all properties except for the ones
#| given.
multi sub font-query-all (IO::Path:D $file, *@except, Bool:D :$supress-errors = False, Bool:D :$no-fatal = False) is export {
    @except ?? font-query($file, @fields ⊖ @except, :$supress-errors, :$no-fatal) !! font-query($file, @fields, :$supress-errors, :$no-fatal);
}
#| Queries all of the font's properties and accepts a Str for the filename instead of an IO::Path
multi sub font-query-all (Str:D $file, *@except, Bool:D :$supress-errors = False, Bool:D :$no-fatal = False) is export {
    font-query($file, @except, :$supress-errors, :$no-fatal);
}
#| Queries the font for the specified list of properties. Use :supress-errors to hide all errors and never
#| die or warn (totally silent). Use :no-fatal to warn instead of dying.
#| Accepts an IO::Path object.
multi sub font-query (IO::Path:D $file, *@list, Bool:D :$supress-errors = False, Bool:D :$no-fatal = False) is export {
    my $error-routine = $no-fatal ?? &warn !! &die;
    my @wrong-fields = @list.grep({@fields.any ne $_});
    $error-routine("Didn't get any queries") if !@list;
    $error-routine("These are not correct queries: {@wrong-fields.join(' ')}") if @wrong-fields;
    my $cmd = run 'fc-scan', '--format', @list.map({'%{' ~ $_ ~ '}'}).join('␤'), $file.absolute, :out, :err;
    my $out = $cmd.out.slurp(:close);
    my $err = $cmd.err.slurp(:close);
    if !$supress-errors and ($cmd.exitcode != 0 or $err) {
        $error-routine("fc-scan error:\n$err");
    }
    my @results = $out.split('␤');
    my %hash;
    $error-routine("Malformed response. Got wrong number of elements back.") if @results != @list;
    for ^@results -> $elem {
        my $property = @list[$elem];
        %hash{@list[$elem]} = make-data $property, @results[$elem];
    }
    %hash;
}
#| Accepts an string of the font's path.
multi sub font-query (Str:D      $file, *@list, Bool:D :$supress-errors = False, Bool:D :$no-fatal = False) is export {
    font-query($file.IO, @list, :$supress-errors, :$no-fatal);
}
sub make-data (Str:D $property, Str $value, Bool:D :$supress-errors = False) {
    given %data{$property}<type> {
        when 'Bool' {
            if $value {
                $value eq 'True' ?? True !! $value eq 'False' ?? False !! do {
                    warn "Property $property, expected True or False but got '$value' Leaving as a string"
                        unless $supress-errors;
                    return $value;
                }
            }
            else {
                return Bool;
            }
        }
        when 'Int' {
            if $value.defined {
                return $value.Int;
            }
            else {
                return Int;
            }
        }
        when 'Double' {
            if $value.defined {
                return $value.Rat;
            }
            else {
                return Rat;
            }
        }
        when 'CharSet' {
            return $value.split(' ').map({my @t = .split('-')».parse-base(16); @t > 1 ?? Range.new(@t[0], @t[1]) !! Range.new(@t[0], @t[0]) })
        }
        default {
            return $value ?? $value !! Str;
        }
    }
    Nil;
}
sub test-it {
    say font-query-all($_) for dir.grep(/:i otf|ttf $ /);
}