requires 'perl', '5.008005';
requires 'Moo';
requires 'Path::Tiny';
requires 'Mojolicious';

# requires 'Some::Module', 'VERSION';

on test => sub {
    requires 'Test::More', '0.96';
};
