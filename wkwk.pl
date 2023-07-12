#!/usr/bin/env perl

#
# Perlで作られた簡易コードジェネレーター
#

use warnings;
use strict;
use feature qw/say/;
use utf8;

use Cwd;
use File::Basename;
use File::Spec::Functions;
use Data::Dumper;
use File::Path 'mkpath';
use Term::ANSIColor qw/ :constants /;

if ( $^O eq "MSWin32" ) {

    # Shift JIS
    binmode STDIN,  ":encoding(cp932)";
    binmode STDOUT, ":encoding(cp932)";
    binmode STDERR, ":encoding(cp932)";
}
else {
    binmode STDIN,  ":utf8";
    binmode STDOUT, ":utf8";
    binmode STDERR, ":utf8";
}

use Carp 'verbose';
$SIG{__DIE__} = sub { Carp::confess(@_) };

our $version = 0.1;

our $status_ok   = 0;
our $status_fail = 1;

sub file_get_contents {
    my $file = shift;
    open my $fh, "<:utf8", $file or die "cannot open $file";
    return do { local $/; <$fh> };
}

sub file_put_contents {
    my ( $file, $content, $mode ) = @_;

    $mode = ">" unless $mode;
    $mode .= ":utf8";

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

    # / linux C:/ windows
    while ( $curr_dir ne "/" and $curr_dir ne "C:/" ) {
        if ( -d $curr_dir . "/.wkwk" ) {
            push( @$wkwk_dir_list, $curr_dir . "/.wkwk" );
        }

        $curr_dir = dirname($curr_dir);
    }

    if ( scalar(@$wkwk_dir_list) >= 1 ) {
        return $wkwk_dir_list;
    }
    else {
        die "/.wkwkはカレントディレクトリ、親ディレクトリに存在しません。";
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

sub cmd_execute {
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
        say "$class コマンドは存在しませんでした。";
    }
}

sub cmd_version { say "Wkwk version: $version"; return $status_ok; }

sub cmd_usage {
    while (<DATA>) {
        chomp;

        if (/=head\d *(.+)/) {
            say "===== " . GREEN . $1 . RESET . " =====";
        }
        else {
            say "\t" . $_;
        }
    }

    return $status_ok;
}

sub main {
    my @argv = @_;

    if ( scalar(@argv) < 1 ) {
        say "引数が１つも存在しません。";
        return $status_fail;
    }

    my $class = shift @argv;

    if ( $class eq "--version" || $class eq "-v" ) {
        return cmd_version();
    }
    elsif ( $class eq "usage" || $class eq "help" ) {
        return cmd_usage();
    }
    else {
        my $ret = cmd_execute( $class, @argv );

        if ( $ret == $status_fail ) {
            say "$class コマンドは存在しませんでした。";
            cmd_usage();
        }
    }
}

main(@ARGV) unless caller;

__DATA__

wkwk Perl製の簡易コードジェネレーター

=head2 How to use

=head3 .wkwk ディレクトリを作成する。

カレントディレクトリまたは、親ディレクトリ等に.wkwk ディレクトリを作成する。

=head3 設定ファイルを作成する。

設定ファイルは以下の様に記述していく。

dist 出力するpath。pwdを基準にpathを書く。
src 出力する元になるファイル。
content 出力する文字列。
もし、srcとcontentが両方記述されている場合は、srcの方が優先される。

また、generateディレクティブの他に、appendディレクティブも用意されている。 generateはファイルを上書きするのに対し、appendはファイルに追加する。

generate:
    dist: 
        director.php
    end_dist:

    src:
        generate/sample.php
    end_src:

    content: 
<?php
class @@class@@
{
    public function __construct()
    {
        $this->sample = $sample;
        parent::__construct();
    }

    public function index()
    {

    }
}

    end_content:

end_generate:

また、generate appendは複数用意することができる。

=head3 実行

例えば、上記の設定ファイルを.wkwk/admin というファイル名で作成した場合は、 wkwk admin とコマンドを実行すると、 カレントディレクトリに director.phpが作成される。

./wkwk admin foo=13 bar=index

等の様に実行することで、変数を定義することができる。
また、デフォルト変数として、 class=adminが定義されており、設定ファイル内で @@class@@ 等と定義することで、変数を置換することができる。

=cut
