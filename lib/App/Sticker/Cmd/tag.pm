package App::Sticker::Cmd::tag;
use strict;
use warnings;
use Moo;
use MooX::Options
  usage_string => 'USAGE: %c %o URL...',
  flavour      => [qw( pass_through )],
  protect_argv => 0;
use Mojo::Collection 'c';
extends 'App::Sticker::Cmd';
with( 'App::Sticker::Util', 'App::Sticker::Modifier' );

for (qw(add_tags remove_tags)) {
    ( my $doc = $_ ) =~ s/_/ /g;
    option $_ => (
        is        => 'ro',
        format    => 's@',
        default   => sub { [] },
        autosplit => ',',
        doc       => $doc,
        short     => substr( $_, 0, 1 ),
    );
}

sub execute {
    my $self = shift;
    my @urls = $self->to_url(@ARGV);
    die "No urls for @urls\n"
      if !@urls;
    for my $url (@urls) {
        my $doc         = $self->base->db->get($url);
        my $tags        = c( @{ $doc->{tags} }, @{ $self->add_tags } )->uniq;
        my %remove_tags = map { $_ => 1 } @{ $self->remove_tags };
        $tags = $tags->grep( sub { not exists $remove_tags{$_} } )->to_array;
        $doc->{tags} = $tags;
        return $self->base->db->set($doc);
    }
    return;
}

1;
