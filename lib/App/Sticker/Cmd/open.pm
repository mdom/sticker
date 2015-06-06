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
	my $viewer = shell_quote($self->base->config->{url_viewer});
	my $command = sprintf($viewer,$url);
        system( $command ) == 0
          or warn "Error calling $command: $!\n";
    }
    return;
}

1;
