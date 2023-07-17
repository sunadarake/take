use warnings;
use strict;
use feature qw/ say /;
use utf8;
use Data::Dumper;
use Test::More;

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin/../scripts";
    use lib "$FindBin::Bin/../local/lib/perl5";
}

require "take.pl";

subtest "cmd usage" => sub {
    my $exit;

    $exit = main("usage");
    ok( $exit eq 0 );

    $exit = main("help");
    ok( $exit eq 0 );
};

done_testing;
