use warnings;
use strict;
use feature qw/ say /;
use utf8;
use Data::Dumper;

use Test::More;
use Test::MockModule;

use File::Path;
use File::Basename;
use File::Spec::Functions;
use File::Temp qw/ tempdir /;
use File::Copy;

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin/../scripts";
    use lib "$FindBin::Bin/../local/lib/perl5";
}

require "take.pl";

sub tk_test_write {
    my ( $file, $content ) = @_;

    my $dir = dirname($file);
    mkpath $dir unless -d $dir;

    open( my $fh, ">", $file ) or die "can not open $file in __file_write";
    print $fh $content;
}

subtest "execute command oneliner" => sub {

    #
    # Setup
    #
    my $root_dir = tempdir( CLEANUP => 1 );

    my $module =
      Test::MockModule->new("main")->mock( 'tk_cwd', sub { $root_dir; } );

    tk_test_write( catfile( $root_dir, ".take/admin.yml" ), <<'...');
- name: copy single file
  command: 'echo "hello"'

...

    #
    # Execute
    #

    my $exit = main("admin");

    #
    # Teardown
    #

    ok( $exit eq 0 );
};

subtest "execute command for loop" => sub {

    #
    # Setup
    #
    my $root_dir = tempdir( CLEANUP => 1 );

    my $module =
      Test::MockModule->new("main")->mock( 'tk_cwd', sub { $root_dir; } );

    tk_test_write( catfile( $root_dir, ".take/admin.yml" ), <<'...');
- name: copy single file
  command:
    - 'echo "hello"'
    - 'echo "take easy"'

...

    #
    # Execute
    #

    my $exit = main("admin");

    #
    # Teardown
    #

    ok( $exit eq 0 );
};

subtest "execute command oneliner with variables." => sub {

    #
    # Setup
    #
    my $root_dir = tempdir( CLEANUP => 1 );

    my $module =
      Test::MockModule->new("main")->mock( 'tk_cwd', sub { $root_dir; } );

    tk_test_write( catfile( $root_dir, ".take/admin.yml" ), <<'...');
- name: copy single file
  command: 'echo "hello, {{ name }}"'

...

    #
    # Execute
    #

    my $exit = main( "admin", "name=Tom" );

    #
    # Teardown
    #

    ok( $exit eq 0 );
};

done_testing;
