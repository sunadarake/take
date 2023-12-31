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

sub tk_test_read {
    my $file = shift;
    open( my $fd, "<", $file ) or die("$file does not open.");
    return do { local $/; <$fd>; };
}

subtest "insert before" => sub {

    #
    # Setup
    #
    my $root_dir = tempdir( CLEANUP => 1 );

    my $module =
      Test::MockModule->new("main")->mock( 'tk_cwd', sub { $root_dir; } );

    tk_test_write( catfile( $root_dir, ".take/sample.yml" ), <<'...');
- name: copy single file
  insert:
    dist: "src/sample.php"
    content: "# hello comment"
    before: "class Sample"

...

    tk_test_write( catfile( $root_dir, "src/sample.php" ), <<'...');
<?php
    class Sample
    {

    }

...

    #
    # Execute
    #

    main("sample");

    #
    # Teardown
    #

    ok( -f catfile( $root_dir, "src/sample.php" ) );

    my $result = tk_test_read( catfile( $root_dir, "src/sample.php" ) );

    # match:
    #
    #   # hello comment
    #   class Sample
    ok(
        $result =~ m{
            (\s*) \# [ ] hello [ ] comment 
            \r?\n
            \1 class [ ] Sample
        }mx
    );
};

subtest "insert before with command line args" => sub {

    #
    # Setup
    #
    my $root_dir = tempdir( CLEANUP => 1 );

    my $module =
      Test::MockModule->new("main")->mock( 'tk_cwd', sub { $root_dir; } );

    tk_test_write( catfile( $root_dir, ".take/sample.yml" ), <<'...');
- name: copy single file
  insert:
    dist: "src/sample.php"
    content: "<@= ucfirst($class) @> oreore"
    before: "# before content"

...

    tk_test_write( catfile( $root_dir, "src/sample.php" ), <<'...');
<?php
    class Sample
    {
        # before content
    }

...

    #
    # Execute
    #

    main("sample");

    #
    # Teardown
    #

    ok( -f catfile( $root_dir, "src/sample.php" ) );

    my $result = tk_test_read( catfile( $root_dir, "src/sample.php" ) );

    # match:
    #
    #   # hello comment
    #   class Sample
    ok(
        $result =~ m{
    (\s+) class [ ] Sample \r?\n
        \1 \{ \r?\n  
        (\s+) Sample [ ] oreore \r?\n  
        \2 \# [ ] before [ ] content \r?\n
    \1 \}
        }mx
    );
};

subtest "insert after" => sub {

    #
    # Setup
    #
    my $root_dir = tempdir( CLEANUP => 1 );

    my $module =
      Test::MockModule->new("main")->mock( 'tk_cwd', sub { $root_dir; } );

    tk_test_write( catfile( $root_dir, ".take/sample.yml" ), <<'...');
- name: copy single file
  insert:
    dist: "src/sample.php"
    content: "# hello comment"
    after: "class Sample"

...

    tk_test_write( catfile( $root_dir, "src/sample.php" ), <<'...');
<?php
    class Sample
    {

    }

...

    #
    # Execute
    #

    main("sample");

    #
    # Teardown
    #

    ok( -f catfile( $root_dir, "src/sample.php" ) );

    my $result = tk_test_read( catfile( $root_dir, "src/sample.php" ) );

    ok(
        $result =~ m{
            (\s*) class [ ] Sample
            \r?\n
            \1 \# [ ] hello [ ] comment 
        }mx
    );
};

subtest "insert after with args" => sub {

    #
    # Setup
    #
    my $root_dir = tempdir( CLEANUP => 1 );

    my $module =
      Test::MockModule->new("main")->mock( 'tk_cwd', sub { $root_dir; } );

    tk_test_write( catfile( $root_dir, ".take/sample.yml" ), <<'...');
- name: copy single file
  insert:
    dist: "src/sample.php"
    content: "<@= $class @> oreore <@= plural($foo) @>"
    after: "# content after"

...

    tk_test_write( catfile( $root_dir, "src/sample.php" ), <<'...');
<?php
    class Sample
    {
        # content after
    }

...

    #
    # Execute
    #

    main( "sample", "foo=bar" );

    #
    # Teardown
    #

    ok( -f catfile( $root_dir, "src/sample.php" ) );

    my $result = tk_test_read( catfile( $root_dir, "src/sample.php" ) );

    tk_test_write( "./sample", $result );

    ok(
        $result =~ m{
            (\s+) class [ ] Sample \r?\n
            \1 \{ \r?\n  
                (\s+) \# [ ] content [ ] after \r?\n
                \2 sample [ ] oreore [ ] bars \r?\n
            \1 \}
        }mx
    );
};

done_testing;
