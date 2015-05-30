package App::Sticker::Cmd::add;
use strict;
use warnings;
use Moo;
use MooX::Cmd;
use MooX::Options usage_string => 'USAGE: %c %o URL...';
extends 'App::Sticker::Cmd';
with('App::Sticker::UA','App::Sticker::Util','App::Sticker::Modifier');

sub execute {
    my $self = shift;
    my @urls = @ARGV;
    return unless \@urls;
    $self->add_urls( \@urls );
}

1;

__END__

=pod

=head1 Foo

bar