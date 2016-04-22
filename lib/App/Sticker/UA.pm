package App::Sticker::UA;
use strict;
use warnings;
use feature "state";
use Moo::Role;
use Mojo::UserAgent;
use Mojo::ByteStream 'b';
use MooX::Options;

requires 'normalize_url';

option 'reload' => (
    is          => 'ro',
    negativable => 1,
    doc         => 'Reload already added urls',
    default     => sub { 1 }
);

sub add_urls {
    my ( $self, $urls ) = @_;
    state $urls_added = [];
    state $ua         = Mojo::UserAgent->new()->max_redirects(5);
    state $idle       = $self->base->worker;
    state $delay      = Mojo::IOLoop->delay();
    while ( $idle and my $url = shift @$urls ) {
        $url = $self->normalize_url($url);
        next if $self->base->db->get($url) && !$self->reload;
        $idle--;
        my $cb = $delay->begin;
        $ua->get(
            $url => sub {
                my ( $ua, $tx ) = @_;
                $idle++;
                $self->process_tx( $tx, $url, $urls_added );

                # refresh worker pool
                $self->add_urls($urls);
                $cb->();
            }
        );
    }
    $delay->wait unless $delay->ioloop->is_running;
    return $urls_added;
}


1;
