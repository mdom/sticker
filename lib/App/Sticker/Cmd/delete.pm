package App::Sticker::Cmd::delete;
use strict;
use warnings;
use Moo;
extends 'App::Sticker::Cmd';
with('App::Sticker::Util','App::Sticker::Modifier');

sub execute {
    my ( $self ) = @_;
    my @urls = $self->to_url(@ARGV);
    die "No urls for @urls\n"
      if !@urls;
    return $self->base->db->delete(@urls);
}

1;
