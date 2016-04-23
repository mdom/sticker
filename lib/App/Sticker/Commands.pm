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

subcmd
  cmd     => 'add',
  comment => 'Add urls.';

arg urls => (
    isa     => 'ArrayRef',
    comment => 'URLs to add.',
    greedy  => 1,
);

subcmd
  cmd     => 'search',
  comment => 'Search database.';

arg queries => (
    isa     => 'ArrayRef',
    comment => 'Search terms.',
    greedy  => 1,
);

subcmd
  cmd     => 'delete',
  comment => 'Delete bookmars.';

arg ids => (
    isa     => 'ArrayRef',
    comment => 'Bookmark ids to delete.',
    greedy  => 1,
);

1;
