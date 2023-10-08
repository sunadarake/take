#!/usr/bin/env perl

#
# Perlで作られた簡易コードジェネレーター
#

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin/../local/lib/perl5";
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

sub tk_echo {
    my ( $color, $title, $msg ) = @_;
    say $color . "[${title}]" . RESET . " $msg";
}

sub green_echo { tk_echo( GREEN, $_[0], $_[1] ); }

sub red_echo { tk_echo( RED, $_[0], $_[1] ); }

sub blue_echo { tk_echo( BRIGHT_BLUE, $_[0], $_[1] ); }

sub cyan_echo { tk_echo( BRIGHT_CYAN, $_[0], $_[1] ); }

sub magenta_echo { tk_echo( BRIGHT_MAGENTA, $_[0], $_[1] ); }

sub parse_yaml_file { return YAML::Tiny->read(shift)->[0]; }

#
# 文字列を複数形にする song → songs
#
sub plural {
    my $word = shift;

    if ( $word =~ /([^aeiou])y$/i ) {
        return $1 . "ies";
    }
    elsif ( $word =~ /s$/i ) {
        return $word . "es";
    }
    else {
        return $word . "s";
    }
}

#
# 文字列をcamelからsnakeに変換する
# myVarTime → my_var_time
#
sub camel2snake {
    my $text = shift;

    $text =~ s/([a-z])([A-Z])/$1_$2/g;
    $text = lc($text);

    return $text;
}

#
# 文字列をsnakeからcamelに変換する
# my_var_time → myVarTime
#
sub sname2camel {
    my $text = shift;

    my @words = split /_/, $text;
    my $camel = join '', map( { ucfirst($_) } @words );

    return $camel;
}

sub render_view {
    my ( $tk_file, $tk_params ) = @_;

    my $tk_content = file_get_contents($tk_file);
    return render_content( $tk_content, $tk_params );
}

sub render_content {
    my ( $tk_content, $tk_params ) = @_;

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

sub file_write_and_mkdir {
    my ( $file, $content, $mode ) = @_;

    my $dir = dirname($file);
    mkpath $dir unless -d $dir;

    file_put_contents( $file, $content, $mode );
}

sub str_trim {
    my $str = shift;
    $str =~ s/^\s*(.*?)\s*$/$1/;
    return $str;
}

sub tk_cwd { getcwd(); }

sub search_tk_dirs {
    my $tk_dir_list = [];

    my $curr_dir = tk_cwd();

    # / linux C:/ windows
    while ( $curr_dir ne "/" and $curr_dir ne "C:/" ) {
        if ( -d $curr_dir . "/.take" ) {
            push( @$tk_dir_list, $curr_dir . "/.take" );
        }

        $curr_dir = dirname($curr_dir);
    }

    if ( scalar(@$tk_dir_list) >= 1 ) {
        return $tk_dir_list;
    }
    else {
        die "/.takeはカレントディレクトリ、親ディレクトリに存在しません。";
    }
}

#
# {{ sample }}_model.phpなどのファイル名を
#　パースして文字列として返す。
#
sub parse_filename {
    my ( $text, $vars_table ) = @_;

    my $code = "";

    # コマンドラインなどの変数を展開する。
    for my $key ( keys(%$vars_table) ) {
        my $val = $vars_table->{$key};

        if ( ref($val) eq "ARRAY" ) {

            # ref ARRAYの場合は特に何もしない。
        }
        elsif ( $key =~ /([^\|]+)\|([^\|]+)/ ) {

            # {{ class|uc }} の様に関数が使えるので、最初のclassの部分を変数として使える様にしておく。
            my $mvar = str_trim($1);
            $code .= qq{ my \$$mvar = "$val"; };
        }
        else {
            $code .= qq{ my \$$key = "$val"; };
        }
    }

    $code .= qq{ my \$result = ""; };

    while ( $text =~ /(\{\{[^}]+\}\}|[^{}]+)/g ) {
        my $token = $1;

        if ( $token =~ /\{\{([^}]+)\}\}/ ) {
            my $val = str_trim($1);
            if ( $val =~ /([^\|]+)\|([^\|]+)/ ) {

                # {{ class|uc }} の様にtwigっぽく関数を使える様にする。
                my $func = str_trim($2);
                my $mvar = str_trim($1);

                $code .= qq{ \$result .= $func("\$$mvar"); };
            }
            else {
                $code .= qq{ \$result .= \$$val ; };
            }
        }
        else {
            $code .= qq{ \$result .= "$token" ; };
        }
    }

    $code .= qq{ return \$result; };

    my $ret = eval $code;

    return $ret;
}

#
# コマンドライン引数をコンパイルして、
# テンプレートエンジン内で変数として使える様にする。
#
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
    my ( $code, $tk_dir, $vars_table ) = @_;

    my $abs_src  = catfile( $tk_dir,  $code->{"src"} );
    my $abs_dist = catfile( tk_cwd(), $code->{"dist"} );

    if ( defined $code->{"with_items"} ) {
        for my $item ( @{ $code->{"with_items"} } ) {
            ( my $temp_src  = $abs_src )  =~ s/\{\{\s*item\s*\}\}/$item/g;
            ( my $temp_dist = $abs_dist ) =~ s/\{\{\s*item\s*\}\}/$item/g;

            $temp_dist = parse_filename( $temp_dist, $vars_table );

            my $content = render_view( $temp_src, $vars_table );
            file_write_and_mkdir( $temp_dist, $content );
            green_echo( "Create", $temp_dist );
        }
    }
    else {
        $abs_dist = parse_filename( $abs_dist, $vars_table );

        my $content = render_view( $abs_src, $vars_table );
        file_write_and_mkdir( $abs_dist, $content );
        green_echo( "Create", $abs_dist );
    }
}

sub execute_insert {
    my ( $code, $tk_dir, $vars_table ) = @_;

    my $abs_dist =
      catfile( tk_cwd(), parse_filename( $code->{"dist"}, $vars_table ) );
    my $content = file_get_contents($abs_dist);

    my $insert_content = render_content( $code->{"content"}, $vars_table );

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

    file_write_and_mkdir( $abs_dist, $result );
    cyan_echo( "Insert", $abs_dist );
}

sub execute_command {
    my ( $command, $tk_dir, $vars_table ) = @_;

    if ( ref($command) eq "ARRAY" ) {
        my $exit;
        for my $cmd (@$command) {
            $cmd  = eval_vars_table( $cmd, $vars_table );
            $exit = `$cmd`;
            magenta_echo( "Execute", $cmd );
        }

        return $exit;
    }
    else {
        $command = eval_vars_table( $command, $vars_table );
        my $exit = `$command`;
        magenta_echo( "Execute", $command );
        return $exit;
    }
}

sub execute_perl {
    my ( $command, $tk_dir, $vars_table ) = @_;

    if ( ref($command) eq "ARRAY" ) {
        my $exit;
        for my $cmd (@$command) {
            $cmd = eval_vars_table( $cmd, $vars_table );
            eval $cmd;
            blue_echo( "Perl", $cmd );

        }
    }
    else {
        $command = eval_vars_table( $command, $vars_table );
        eval $command;
        blue_echo( "Perl", $command );
    }
}

sub cmd_execute {
    my ( $class, @argv ) = @_;

    my $tk_setting_dirs     = search_tk_dirs();
    my $is_command_executed = 0;

    for my $tk_setting_dir (@$tk_setting_dirs) {
        my $yaml_file = lc($class) . ".yml";
        my $tk_file   = $tk_setting_dir . "/" . $yaml_file;

        next unless -f $tk_file;

        my $code_list  = parse_yaml_file($tk_file);
        my $vars_table = parse_vars( $class, @argv );

        for my $code (@$code_list) {
            if ( defined $code->{"copy"} ) {
                execute_copy( $code->{"copy"}, $tk_setting_dir, $vars_table );
            }
            elsif ( defined $code->{"insert"} ) {
                execute_insert( $code->{"insert"}, $tk_setting_dir,
                    $vars_table );
            }
            elsif ( defined $code->{"command"} ) {
                execute_command( $code->{"command"}, $tk_setting_dir,
                    $vars_table );
            }
            elsif ( defined $code->{"perl"} ) {
                execute_perl( $code->{"perl"}, $tk_setting_dir, $vars_table );
            }
            else {
            }
        }

        $is_command_executed = 1;
        last;
    }

    if ( $is_command_executed == 0 ) {
        say "$class コマンドは存在しませんでした。";
        return $status_fail;
    }
    else {
        return $status_ok;
    }
}

sub cmd_version { say "tk version: $version"; return $status_ok; }

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
        my $exit_code = cmd_execute( $class, @argv );

        if ( $exit_code == $status_fail ) {
            say "$class コマンドは存在しませんでした。";
            cmd_usage();
        }

        return $exit_code;
    }
}

main(@ARGV) unless caller;

__DATA__
