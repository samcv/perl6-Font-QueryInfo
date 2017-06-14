#!/usr/bin/env perl6
my $data = Q:to/🌟/;
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
  🌟
my @rows = $data.lines».split(/\s+/, 3);
my @fields2     = @rows»[0];
my @type        = @rows»[1];
my @description = @rows»[2];
my %data;
for ^@rows {
    %data{@rows[$_][0]} = %( 'type' => @rows[$_][1], 'description' => @rows[$_][2] );
}
my @fields = %data.keys;
my @formats = @fields.map({'%{' ~ $_ ~ '}'});
#my $format = Q<FullName: '%{fullname}' Foundry: '%{foundry}' Family: '%{family}' Style: '%{style}'>;
my $file = dir[0];
for @formats -> $format {
    last;
    say $format;
    my $cmd = run 'fc-scan', '--format', $format, $file, :out, :err;
    my $out = $cmd.out.slurp(:close);
    my $err = $cmd.err.slurp(:close);
    die $err if $cmd.exitcode != 0 or $err;
    $out.perl.say;
}
say font-query($_, @fields) for dir.grep(/:i otf|ttf $ /);
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
    my @wrong-fields = @list.grep({@fields.any ne $_});
    die "Didn't get any queries" if !@list;
    die "These are not correct queries: {@wrong-fields.join(' ')}" if @wrong-fields;
    my $cmd = run 'fc-scan', '--format', @list.map({'%{' ~ $_ ~ '}'}).join('␤'), $file.absolute, :out, :err;
    my $out = $cmd.out.slurp(:close);
    my $err = $cmd.err.slurp(:close);
    if !$supress-errors and ($cmd.exitcode != 0 or $err) {
        if $no-fatal {
            warn "fc-scan error:\n$err";
        }
        else {
            die "fc-scan error:\n$err";
        }
    }
    my @results = $out.split('␤');
    my %hash;
    die if @results != @list;
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
sub make-data (Str:D $property, Str $value) {
    given %data{$property}<type> {
        when 'Bool' {
            if $value {
                $value eq 'True' ?? True !! $value eq 'False' ?? False !! do {
                    warn "Property $property, expected True or False but got '$value' Leaving as a string";
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