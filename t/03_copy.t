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

subtest "copy single" => sub {

    #
    # Setup
    #
    my $root_dir = tempdir( CLEANUP => 1 );

    my $module =
      Test::MockModule->new("main")->mock( 'tk_cwd', sub { $root_dir; } );

    tk_test_write( catfile( $root_dir, ".take/sample.yml" ), <<'...');
- name: copy single file
  copy:
    src: "src/sample.php"
    dist: "bar.php"

...

    tk_test_write( catfile( $root_dir, ".take/src/sample.php" ), <<'...');
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

    ok( -f catfile( $root_dir, "bar.php" ) );

    my $result = tk_test_read( catfile( $root_dir, "bar.php" ) );
    ok( $result =~ /class Sample/ );
};

subtest "copy multiples" => sub {

    #
    # Setup
    #
    my $root_dir = tempdir( CLEANUP => 1 );

    my $module =
      Test::MockModule->new("main")->mock( 'tk_cwd', sub { $root_dir; } );

    tk_test_write( catfile( $root_dir, ".take/sample.yml" ), <<'...');
- name: copy multiples
  copy:
    src: "src/sample.php"
    dist: "{{ item }}.php"
    with_items:
      - foo
      - bar

...

    tk_test_write( catfile( $root_dir, ".take/src/sample.php" ), <<'...');
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

    ok( -f catfile( $root_dir, "bar.php" ) );

    my $result001 = tk_test_read( catfile( $root_dir, "bar.php" ) );
    ok( $result001 =~ /class Sample/ );

    ok( -f catfile( $root_dir, "foo.php" ) );

    my $result002 = tk_test_read( catfile( $root_dir, "foo.php" ) );
    ok( $result002 =~ /class Sample/ );
};

subtest "copy single with args" => sub {

    #
    # Setup
    #
    my $root_dir = tempdir( CLEANUP => 1 );

    my $module =
      Test::MockModule->new("main")->mock( 'tk_cwd', sub { $root_dir; } );

    tk_test_write( catfile( $root_dir, ".take/sample.yml" ), <<'...');
- name: copy single file
  copy:
    src: "src/sample.php"
    dist: "bar.php"

...

   # You can define variables within the template. <@= $class @>
   # By adding the argument "class=Sample,"
   # you can perform variable expansion within the template using <@= $class @>.

    tk_test_write( catfile( $root_dir, ".take/src/sample.php" ), <<'...');
<?php
    class <@= $class @>
    {
@ for $meth (@$methods) {
    public function <@= $meth @>
@ }
    }

...

    #
    # Execute
    #

    # use <@= $class @> in templates.
    # Comma-separated arguments can be used as an array within the template.
    main( "sample", "class=Sample", "methods=index,show,create" );

    #
    # Teardown
    #

    # create bar.php
    ok( -f catfile( $root_dir, "bar.php" ) );

    my $content = tk_test_read( catfile( $root_dir, "bar.php" ) );
    ok( $content =~ /class Sample/ );

    ok( $content =~ /public function index/ );
    ok( $content =~ /public function show/ );
    ok( $content =~ /public function create/ );
};

done_testing;
