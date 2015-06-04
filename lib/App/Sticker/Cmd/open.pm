package App::Sticker::Cmd::open;
use strict;
use warnings;
use Moo;
extends 'App::Sticker::Cmd';
with('App::Sticker::Util');

sub execute {
    my $self = shift;
    my @urls = $self->to_url(@ARGV);
    die "No urls for @urls\n"
      if !@urls;
    for my $url (@urls) {
        system( @{ $self->base->config->{handler} }, $url ) == 0
          or warn "Error calling @{ $self->base->config->{handler} } $url: $!\n";
    }
    return;
}

1;
