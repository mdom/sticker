use strict;
use warnings;
use Test::PerlTidy;

run_tests(
    exclude => [
        qr{Makefile.PL}, qr{blib/}, qr{App-sticker-.*/}, qr{.build/},
        qr{.git/}
    ]
);
