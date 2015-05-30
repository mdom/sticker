package App::Sticker::Cmd::tag;
use strict;
use warnings;
use Moo;
use MooX::Cmd;
use Mojo::Collection 'c';
extends 'App::Sticker::Cmd';
with('App::Sticker::Util','App::Sticker::Modifier');

sub execute {
    my $self = shift;
    my ( $arg, @new_tags ) = @ARGV;
    my ($url) = $self->to_url($arg);
    die "No url for $arg\n"
      if !$url;
    my $doc = $self->base->db->get( $url );
    ## TODO way to remove tags
    my $tags = c( @{$doc->{tags}}, @new_tags )->uniq->to_array;
    $doc->{tags} = $tags;
    return $self->base->db->set( $doc );
}

1;
