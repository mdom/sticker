package App::Sticker::Cmd;
use strict;
use warnings;
use Moo;
use MooX::Cmd;
use MooX::Options
  flavour      => [qw( pass_through )],
  protect_argv => 0;

sub base {
    my $self = shift;
    return $self->command_chain->[0];
}

1;
