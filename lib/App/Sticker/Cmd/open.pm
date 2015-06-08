package App::Sticker::Cmd::open;
use strict;
use warnings;
use Moo;
use String::ShellQuote 'shell_quote';
extends 'App::Sticker::Cmd';
with('App::Sticker::Util');

sub execute {
    my $self = shift;
    my @urls = $self->to_url(@ARGV);
    die "No urls for @urls\n"
      if !@urls;
    for my $url (@urls) {
        system( $command ) == 0
	my $viewer = $self->base->url_viewer;
	my $command = sprintf($viewer,shell_quote($url));
          or warn "Error calling $command: $!\n";
    }
    return;
}

1;
