package App::Sticker;

# ABSTRACT: Bookmark manager for the command line

use strict;
use warnings;

use Moo;
use MooX::Cmd;
use MooX::Options flavour => [qw( pass_through )], protect_argv => 0;

use App::Sticker::DB;
use Path::Tiny;

our $VERSION = '0.01';

has db       => ( is => 'lazy' );
has config   => ( is => 'lazy' );
has base_dir => ( is => 'lazy' );

option db_file => ( is => 'lazy', format => 's', doc => 'Database file to use' );

sub _build_config {
    my $self           = shift;
    my %default_config = (
        stopwords => [
            qw(a about above after again against all am an and any are aren't as at
              be because been before being below between both but by can can't cannot
              could couldn't did didn't do does doesn't doing don't down during each
              few for from further had hadn't has hasn't have haven't having he he'd
              he'll he's her here here's hers herself him himself his how how's i i'd
              i'll i'm i've if in into is isn't it it's its itself let's me more most
              mustn't my myself no nor not of off on once only or other ought our
              ours ourselves out over own same shan't she she'd she'll she's should
              shouldn't so some such than that that's the their theirs them
              themselves then there there's these they they'd they'll they're they've
              this those through to too under until up use very was wasn't we we'd
              we'll we're we've were weren't what what's when when's where where's
              which while who who's whom why why's will with won't would wouldn't you
              you'd you'll you're you've your yours yourself yourselves)
        ],
        url_viewer => 'iceweasel -new-tab %s',
        worker  => 5,
    );

    my $config_file = $self->base_dir->child('config');
    my $config      = \%default_config;
    if ( $config_file->exists ) {
        my $json = eval { decode_json( $config_file->slurp_utf8 ) };
        if ($json) {
            $config = { %default_config, %$json };
        }
    }
    return $config;
}

sub _build_db_file {
	my $self = shift;
	return $self->base_dir->child('sticker.db');
}

sub _build_db {
    my $self = shift;
    return App::Sticker::DB->new( db_file => $self->db_file );
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
