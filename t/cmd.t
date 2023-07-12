use warnings;
use strict;
use feature qw/ say /;
use utf8;
use Data::Dumper;
use Test::More;

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin/../";
}

require "wkwk.pl";

subtest "cmd version" => sub {
    my $exit;

    $exit = main("--version");
    ok( $exit eq 0 );

    $exit = main("-v");
    ok( $exit eq 0 );
};

subtest "cmd usage" => sub {
    my $exit;

    $exit = main("usage");
    ok( $exit eq 0 );

    $exit = main("help");
    ok( $exit eq 0 );
};

done_testing;
