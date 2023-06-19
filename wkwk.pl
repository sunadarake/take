#!/usr/bin/env perl

#
# Perlで作られた簡易コードジェネレーター
#

use warnings;
use strict;
use feature qw/say/;

use Cwd;
use File::Basename;
use File::Spec::Functions;
use Data::Dumper;
use Pod::Usage 'pod2usage';
use File::Path 'mkpath';

use Carp 'verbose';
$SIG{__DIE__} = sub { Carp::confess(@_) };

our $version = 0.1;

our $status_ok   = 0;
our $status_fail = 1;

sub file_get_contents {
    my $file = shift;
    open my $fh, "<", $file or die "cannot open $file";
    return do { local $/; <$fh> };
}

sub file_put_contents {
    my ( $file, $content, $mode ) = @_;

    $mode = ">" unless $mode;
    open( my $fh, $mode, $file ) or die "Can't open $file: $!";
    print $fh $content;
}

sub rmkdir { mkpath $_[0] if not -d $_[0]; }

sub str_trim {
    my $str = shift;
    $str =~ s/^\s*(.*?)\s*$/$1/;
    return $str;
}

sub search_wkwk_dirs {
    my $wkwk_dir_list = [];

    my $curr_dir = getcwd();

    while ( $curr_dir ne "/" ) {
        if ( -d $curr_dir . "/.wkwk" ) {
            push( @$wkwk_dir_list, $curr_dir . "/.wkwk" );
        }

        $curr_dir = dirname($curr_dir);
    }

    if ( scalar(@$wkwk_dir_list) >= 1 ) {
        return $wkwk_dir_list;
    }
    else {
        die
"/.wkwkはカレントディレクトリ、親ディレクトリに存在しません。";
    }
}

sub parse_help_code {
    my ( $code, $fh ) = @_;

    my $content = "";

    while ( my $line = <$fh> ) {
        last if $line =~ /^\s*end_help:/;

        $content = $content . $line;
    }

    push(
        @$code,
        +{
            type    => "help",
            content => $content,
        }
    );

    return $code;
}

sub parse_generate_code {
    my ( $code, $fh ) = @_;

    my $dist    = [];
    my $src     = "";
    my $content = "";

    while ( my $line = <$fh> ) {
        last if $line =~ /^\s*end_generate:/;

        if ( $line =~ /^\s*dist:/ ) {
            while ( my $temp_line = <$fh> ) {
                last if $temp_line =~ /^\s*end_dist:/;

                push( @$dist, str_trim($temp_line) );
            }

        }
        elsif ( $line =~ /^\s*src:/ ) {
            $src = "";

            while ( my $temp_line = <$fh> ) {
                last if $temp_line =~ /^\s*end_src:/;
                next if $temp_line =~ /^\s*$/;
                $src = str_trim($temp_line);
            }
        }
        elsif ( $line =~ /^\s*content:/ ) {
            $content = "";

            while ( my $temp_line = <$fh> ) {
                last if $temp_line =~ /^\s*end_content:/;

                $content = $content . $temp_line;
            }
        }
    }

    push(
        @$code,
        +{
            type    => "generate",
            dist    => $dist,
            src     => $src,
            content => $content,
        }
    );

    return $code;
}

sub parse_append_code {
    my ( $code, $fh ) = @_;

    my $dist    = [];
    my $src     = "";
    my $content = "";

    while ( my $line = <$fh> ) {
        last if $line =~ /^\s*end_generate:/;

        if ( $line =~ /^\s*dist:/ ) {
            while ( my $temp_line = <$fh> ) {
                last if $temp_line =~ /^\s*end_dist:/;

                push( @$dist, str_trim($temp_line) );
            }

        }
        elsif ( $line =~ /^\s*src:/ ) {
            $src = "";

            while ( my $temp_line = <$fh> ) {
                last if $temp_line =~ /^\s*end_src:/;
                next if $temp_line =~ /^\s*$/;
                $src = str_trim($temp_line);
            }
        }
        elsif ( $line =~ /^\s*content:/ ) {
            $content = "";

            while ( my $temp_line = <$fh> ) {
                last if $temp_line =~ /^\s*end_content:/;

                $content = $content . $temp_line;
            }
        }
    }

    push(
        @$code,
        +{
            type    => "append",
            dist    => $dist,
            src     => $src,
            content => $content,
        }
    );

    return $code;
}

sub parse_code {
    my $file = shift;

    my $code = [];

    open my $fh, "<", $file or die "Can't open $file: $!";

    while ( my $line = <$fh> ) {
        if ( $line =~ /^\s*help:/ ) {
            $code = parse_help_code( $code, $fh );
        }
        elsif ( $line =~ /^\s*generate:/ ) {
            $code = parse_generate_code( $code, $fh );
        }
        elsif ( $line =~ /^\s*append:/ ) {
            $code = parse_append_code( $code, $fh );
        }
    }

    return $code;
}

sub execute_generate {
    my ( $code, $wktk_dir, $vars_table ) = @_;

    my $root_dir = getcwd();

    my $dist_list = $code->{"dist"};
    my ( $val, $abs_src, $content, $abs_dist );

    for my $dist (@$dist_list) {

        for my $var ( keys(%$vars_table) ) {
            $val = $vars_table->{$var};
            $dist =~ s/$var/$val/g;
        }

        if ( $code->{"src"} ) {
            $abs_src = catfile( $wktk_dir, $code->{"src"} );
            $content = file_get_contents($abs_src);

            for my $var ( keys(%$vars_table) ) {
                $val = $vars_table->{$var};
                $content =~ s/$var/$val/g;
            }

            $abs_dist = catfile( $root_dir, $dist );
            rmkdir( dirname($abs_dist) );
            file_put_contents( $abs_dist, $content );
            say "$abs_dist のファイルを生成しました。";
            next;
        }

        if ( $code->{"content"} ) {
            $content = $code->{"content"};

            for my $var ( keys(%$vars_table) ) {
                $val = $vars_table->{$var};
                $content =~ s/$var/$val/g;
            }

            $abs_dist = catfile( $root_dir, $dist );
            rmkdir( dirname($abs_dist) );
            file_put_contents( $abs_dist, $content );
            say "$abs_dist のファイルを生成しました。";
            next;
        }
    }
}

sub execute_append {
    my ( $code, $wktk_dir, $vars_table ) = @_;

    my $root_dir = getcwd();

    my $dist_list = $code->{"dist"};
    my ( $val, $abs_src, $content, $abs_dist );

    for my $dist (@$dist_list) {
        if ( $code->{"src"} ) {
            $abs_src = catfile( $wktk_dir, $code->{"src"} );
            $content = file_get_contents($abs_src);

            for my $var ( keys(%$vars_table) ) {
                $val = $vars_table->{$var};
                $content =~ s/$var/$val/g;
            }

            $abs_dist = catfile( $root_dir, $dist );
            rmkdir( dirname($abs_dist) );
            file_put_contents( $abs_dist, $content, ">>" );
            next;
        }

        if ( $code->{"content"} ) {
            $content = $code->{"content"};

            for my $var ( keys(%$vars_table) ) {
                $val = $vars_table->{$var};
                $content =~ s/$var/$val/g;
            }

            $abs_dist = catfile( $root_dir, $dist );
            rmkdir( dirname($abs_dist) );
            file_put_contents( $abs_dist, $content, ">>" );
            next;
        }
    }
}

sub parse_vars {
    my ( $class, @vars ) = @_;

    my ( $key, $val );

    my $vars_table = +{ '@@class@@' => $class, };

    for my $var (@vars) {
        if ( $var =~ /(.+)=(.+)/ ) {
            $key                = "@@" . $1 . "@@";
            $val                = $2;
            $vars_table->{$key} = $val;
        }
    }

    return $vars_table;
}

sub execute_command {
    my ( $class, @argv ) = @_;

    my $wkwk_setting_dirs   = search_wkwk_dirs();
    my $is_command_executed = 0;

    for my $wkwk_setting_dir (@$wkwk_setting_dirs) {
        my $wkwk_file = $wkwk_setting_dir . "/" . $class;

        next if !-f $wkwk_file;

        my $code_list  = parse_code($wkwk_file);
        my $vars_table = parse_vars( $class, @argv );

        for my $code (@$code_list) {
            if ( $code->{"type"} eq "generate" ) {
                execute_generate( $code, $wkwk_setting_dir, $vars_table );
            }

            if ( $code->{"type"} eq "append" ) {
                execute_append( $code, $wkwk_setting_dir, $vars_table );
            }
        }

        $is_command_executed = 1;
        last;
    }

    if ( $is_command_executed == 0 ) {
        die "$class コマンドは存在しませんでした。";
    }
}

sub echo_version {
    say "Wkwk version: $version";
    return $status_ok;
}

sub main {
    if ( scalar(@ARGV) < 1 ) {
        say "引数が１つも存在しません。";
        return $status_fail;
    }

    my $class = shift @ARGV;

    if ( $class eq "--version" || $class eq "-v" ) {
        return echo_version();
    }
    else {
        return execute_command( $class, @ARGV );
    }
}

exit main();
