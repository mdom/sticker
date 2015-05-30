package App::Sticker::Cmd::delete;
use strict;
use warnings;
use Moo;
use MooX::Cmd;
extends 'App::Sticker::Cmd';
with('App::Sticker::Util','App::Sticker::Modifier');

sub execute {
    my ( $self, @urls ) = @_;
    @urls = $self->to_url(@urls);
    die "No urls for @urls\n"
      if !@urls;
    return $self->base->db->delete(@urls);
}

1;
