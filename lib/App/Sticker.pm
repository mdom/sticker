package App::Sticker;

# ABSTRACT: Bookmark manager for the command line

use strict;
use warnings;

use Moo;
use MooX::Cmd;
use MooX::Options flavour => [qw( pass_through )], protect_argv => 0;

use App::Sticker::DB;
use Path::Tiny;

use Mojo::JSON::MaybeXS;
use Mojo::JSON qw(encode_json decode_json);

our $VERSION = '0.01';

has db => ( is => 'lazy' );

option base_dir => (
    is     => 'lazy',
    coerce => sub { path( $_[0] ) },
    format => 's',
    doc    => 'Basedir for config and db'
);

option db_file =>
  ( is => 'lazy', format => 's', doc => 'Database file to use' );

option db_backup => (
    is          => 'ro',
    negativable => 1,
    default     => sub { 1 },
    doc         => 'Backup database before changing it'
);

option worker =>
  ( is => 'ro', format => 'i', doc => 'Number of workers for downloading' );
option url_viewer => (
    is     => 'ro',
    format => 's',
    doc    => 'Command to view urls',
);
option stopwords => (
    is     => 'ro',
    format => 's@',
    doc    => 'Words to ignore for content search',
);

sub BUILDARGS {
    my ( $class, @args ) = @_;
    my $args = ref $args[0] ? $args[0] : {@args};
    my %default_config = (
        url_viewer => 'iceweasel -new-tab %s',
        worker     => 5,
        base_dir   => '~/.sticker',
    );

    ## TODO combine command line args and configuration file
    my $config = { %default_config, %$args };

    my $file_options = {};
    my $config_file  = path( $config->{base_dir} )->child('config');
    if ( $config_file->exists ) {
        $file_options = eval { decode_json( $config_file->slurp_utf8 ) };
        if ($@) {
            die "$0: Error reading configuration file: $@\n";
        }
    }
    my @stopwords;
    for my $ref ( \%default_config, $args, $file_options ) {
        if ( exists $ref->{stopwords} and ref( $ref->{stopwords} ) eq 'ARRAY' )
        {
            push @stopwords, @{ $ref->{stopwords} };
        }
    }

    $config =
      { %default_config, %$file_options, %$args, stopwords => \@stopwords };

    return $config;
}

sub _build_db_file {
    my $self = shift;
    return $self->base_dir->child('sticker.db');
}

sub _build_db {
    my $self = shift;
    return App::Sticker::DB->new(
        db_file => $self->db_file,
        backup  => $self->db_backup
    );
}

sub _build_base_dir {
    my $self     = shift;
    my $base_dir = path('~/.sticker/');
    $base_dir->mkpath();
    return $base_dir;
}

sub execute {
    return;
}

1;
