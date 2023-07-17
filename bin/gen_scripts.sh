#!/bin/bash

cd `dirname $0`/..

export PERL5LIB=$PWD/local/lib/perl5

perl ./local/bin/fatpack pack scripts/take.pl > take

chmod 0755 take

perl ./local/bin/pl2bat.pl take
