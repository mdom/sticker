# stolen from https://gist.github.com/jberger/5153008
# all errors probably by me
package App::Sticker::URLQueue;
use Mojo::Base 'Mojo::EventEmitter';
use Mojo::UserAgent;
use Mojo::IOLoop;

has queue => sub { [] };
has ua => sub { Mojo::UserAgent->new( max_redirects => 5 ) };
has worker => 16;
has delay => sub { Mojo::IOLoop->delay };

sub start {
    my ( $self, $cb ) = @_;

    return unless @{ $self->queue };
    $self->{running} = 0;

    $self->_refresh;

    return $self->delay;
}

sub _refresh {
    my $self = shift;

    my $worker = $self->worker;
    while ( $self->{running} < $worker
        and my $url = shift @{ $self->queue } )
    {
        $self->{running}++;
        my $end = $self->delay->begin;

        $self->ua->get(
            $url => sub {
                my ( $ua, $tx ) = @_;

                $self->emit( process_url => $tx, $url );

                # refresh worker pool
                $self->{running}--;
                $self->_refresh;
                $end->();
            }
        );
    }
}

1;
