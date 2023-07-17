#!/usr/bin/env perl

#
# Perlで作られた簡易コードジェネレーター
#

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin/local/lib/perl5";
}

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

use YAML::Tiny;
use Text::MicroTemplate qw/ :all /;

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

sub read_yaml_file { return YAML::Tiny->read(shift)->[0]; }

sub render_view {
    my ( $tk_file, $tk_params ) = @_;

    my $tk_content = file_get_contents($tk_file);

    my $tk_mt = Text::MicroTemplate->new(
        template   => $tk_content,
        tag_start  => '<@',
        tag_end    => '@>',
        line_start => '@',
    );
    my $tk_code = $tk_mt->code;

    my $tk_renderer = eval << "..." or die $@;
sub {
    no strict;
    my \$params = shift;

    for my \$var ( keys(%\$params) ) {
        \$\$var = \$params->{\$var};
    }

    $tk_code->();
}
...

    return $tk_renderer->($tk_params);
}

sub parse_vars {
    my ( $class, @vars ) = @_;

    my $vars_table = +{ 'class' => $class, };

    for my $var (@vars) {
        if ( $var =~ /(.+)=(.+)/ ) {
            my $key = $1;
            my $val = $2;

            if ( $val =~ /,/ ) {
                $val = [ split( /,/, $val ) ];
            }

            $vars_table->{$key} = $val;
        }
    }

    return $vars_table;
}

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

sub wkwk_cwd { getcwd(); }

sub search_wkwk_dirs {
    my $wkwk_dir_list = [];

    my $curr_dir = wkwk_cwd();

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

sub eval_vars_table {
    my ( $text, $vars_table ) = @_;

    for my $var ( keys(%$vars_table) ) {
        my $val = $vars_table->{$var};
        next if ref($val) eq "ARRAY";
        $text =~ s/\{\{\s*$var\s*\}\}/$val/g;
    }

    return $text;
}

sub execute_copy {
    #
    # code:
    #  src: "src/oreore.php"
    #  dist: "/path/dist/sample.php"
    #
    # code:
    #  src: "src/{{ item }}.php"
    #  dist: "/path/dist/{{ item }}.php"
    #  with_items:
    #    - oreore
    #    - thanks
    #
    my ( $code, $wkwk_dir, $vars_table ) = @_;

    my $abs_src  = catfile( $wkwk_dir,  $code->{"src"} );
    my $abs_dist = catfile( wkwk_cwd(), $code->{"dist"} );

    if ( defined $code->{"with_items"} ) {
        for my $item ( @{ $code->{"with_items"} } ) {
            ( my $temp_src  = $abs_src )  =~ s/\{\{\s*item\s*\}\}/$item/g;
            ( my $temp_dist = $abs_dist ) =~ s/\{\{\s*item\s*\}\}/$item/g;

            $temp_dist = eval_vars_table( $temp_dist, $vars_table );

            my $content = render_view( $temp_src, $vars_table );
            file_put_contents( $temp_dist, $content );
        }
    }
    else {
        $abs_dist = eval_vars_table( $abs_dist, $vars_table );

        my $content = render_view( $abs_src, $vars_table );
        file_put_contents( $abs_dist, $content );
    }
}

sub execute_insert {
    my ( $code, $wkwk_dir, $vars_table ) = @_;

    my $abs_dist = catfile( wkwk_cwd(), $code->{"dist"} );
    my $content  = file_get_contents($abs_dist);

    my $insert_content = eval_vars_table( $code->{"content"}, $vars_table );

    say Dumper $insert_content;

    my $result = "";
    for my $line ( split( /\n/, $content ) ) {
        if ( defined( $code->{"after"} ) ) {
            my $after = $code->{"after"};
            if ( $line =~ /(\s*)$after/ ) {
                $result .= $line . "\n" . $1 . $insert_content . "\n";
                next;
            }
        }

        if ( defined( $code->{"before"} ) ) {
            my $before = $code->{"before"};
            if ( $line =~ /(\s*)$before/ ) {
                $result .= $1 . $insert_content . "\n" . $line . "\n";
                next;
            }
        }

        $result .= $line . "\n";
    }

    file_put_contents( $abs_dist, $result );
}

sub execute_command {
    #
    # command: git clone sample.git
    #
    my ( $command, $wkwk_dir, $vars_table ) = @_;

    if ( ref($command) eq "ARRAY" ) {
        my $exit;
        for my $cmd (@$command) {
            $cmd  = eval_vars_table( $cmd, $vars_table );
            $exit = `$cmd`;
        }

        return $exit;
    }
    else {
        $command = eval_vars_table( $command, $vars_table );
        my $exit = `$command`;
        return $exit;
    }
}

sub execute_perl {
    #
    # command: git clone sample.git
    #
    my ( $command, $wkwk_dir, $vars_table ) = @_;

    if ( ref($command) eq "ARRAY" ) {
        my $exit;
        for my $cmd (@$command) {
            $cmd = eval_vars_table( $cmd, $vars_table );
            eval $cmd;
        }
    }
    else {
        $command = eval_vars_table( $command, $vars_table );
        eval $command;
    }
}

sub cmd_execute {
    my ( $class, @argv ) = @_;

    my $wkwk_setting_dirs   = search_wkwk_dirs();
    my $is_command_executed = 0;

    for my $wkwk_setting_dir (@$wkwk_setting_dirs) {
        my $yaml_file = lc($class) . ".yml";
        my $wkwk_file = $wkwk_setting_dir . "/" . $yaml_file;

        next unless -f $wkwk_file;

        my $code_list  = read_yaml_file($wkwk_file);
        my $vars_table = parse_vars( $class, @argv );

        for my $code (@$code_list) {
            if ( defined $code->{"copy"} ) {
                execute_copy( $code->{"copy"}, $wkwk_setting_dir, $vars_table );
            }

            if ( defined $code->{"insert"} ) {
                execute_insert( $code->{"insert"}, $wkwk_setting_dir,
                    $vars_table );
            }

            if ( defined $code->{"command"} ) {
                execute_command( $code->{"command"}, $wkwk_setting_dir,
                    $vars_table );
            }

            if ( defined $code->{"perl"} ) {
                execute_perl( $code->{"perl"}, $wkwk_setting_dir, $vars_table );
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
