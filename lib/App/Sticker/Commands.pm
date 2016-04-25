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

opt config_file => (
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
  cmd     => 'tag',
  comment => 'Manage tags.';

arg command => (
    isa      => 'SubCmd',
    comment  => 'sub command to run',
    required => 1,
);

subcmd
  cmd     => [qw(tag add)],
  comment => 'Add tag to urls.';

arg tag => (
    isa     => 'Str',
    comment => 'Tag to add.',
);

arg bookmarks => (
    isa     => 'ArrayRef',
    comment => 'Which bookmarks to tag.',
    greedy  => 1,
);

subcmd
  cmd     => [qw(tag delete)],
  comment => 'Add tag to urls.';

arg tag => (
    isa     => 'Str',
    comment => 'Tag to delete.',
);

arg bookmarks => (
    isa     => 'ArrayRef',
    comment => 'Bookmarks to untag.',
    greedy  => 1,
);

subcmd
  cmd     => [qw(tag merge)],
  comment => 'Add tag to urls.';

arg from_tag => (
    isa     => 'Str',
    comment => 'Source tag.',
);

arg to_tag => (
    isa     => 'Str',
    comment => 'Taget tag.',
);

arg bookmarks => (
    isa     => 'ArrayRef',
    comment => 'Which bookmarks to untag.',
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
  comment => 'Delete bookmarks.';

arg ids => (
    isa     => 'ArrayRef',
    comment => 'Bookmark ids to delete.',
    greedy  => 1,
);

subcmd
  cmd     => 'open',
  comment => 'Open bookmarks.';

arg id => (
    isa     => 'Int',
    comment => 'Bookmark to open.',
);

1;
