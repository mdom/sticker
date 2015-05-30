package App::Sticker::Cmd;
use strict;
use warnings;
use Moo;

sub base {
    my $self = shift;
    return $self->command_chain->[0];
}

1;
