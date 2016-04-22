package App::Sticker::Commands;
use Mojo::Base -base;
use OptArgs;

arg command => (
    isa      => 'SubCmd',
    comment  => 'sub command to run',
    required => 1,
);

opt help => (
    isa     => 'Bool',
    comment => 'Print a help message and exit.',
    ishelp  => 1,
    alias   => 'h',
);

opt config => (
    isa     => 'Str',
    comment => 'Specify a custom config file location.',
    alias   => 'c',
);

subcmd
  cmd     => 'import',
  comment => 'Import bookmarks.';

arg files => (
    isa     => 'ArrayRef',
    comment => 'Files to import.',
    greedy  => 1,
);

1;
