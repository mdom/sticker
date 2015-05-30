package App::Sticker::UA;
use strict;
use warnings;
use feature "state";
use Moo::Role;
use Mojo::UserAgent;
use Mojo::ByteStream 'b';

requires 'normalize_url';

sub add_urls {
    my ( $self, $urls ) = @_;
    state $ua    = Mojo::UserAgent->new()->max_redirects(5);
    state $idle  = $self->base->config->{worker};
    state $delay = Mojo::IOLoop->delay();
    while ( $idle and my $url = shift @$urls ) {
        $url = $self->normalize_url($url);
        $idle--;
        my $cb = $delay->begin;
        $ua->get(
            $url => sub {
                my ( $ua, $tx ) = @_;
                $idle++;
                $self->process_tx( $tx, $url );

                # refresh worker pool
                $self->add_urls($urls);
                $cb->();
            }
        );
    }
    $delay->wait unless $delay->ioloop->is_running;
}

sub process_tx {
    my $self = shift;
    my ( $tx, $url, $result ) = @_;
    if ( my $res = $tx->success ) {
        my ( $title, $content );
        if ( $res->headers->content_type =~ 'text/html' ) {
            my $dom = $res->dom;
            $title = $dom->at('title');
            if ($title) {
                $title = b( $title->all_text() )->squish;
            }
            $dom->find('head')->map('remove');
            $dom->find('script')->map('remove');
            my %stopword =
              map { $_ => 1 } @{ $self->base->config->{stopwords} };

            ## There are many pages without a body-tag, so i just use all the
            ## text in the dom as content, TODO remove head before all_text()?

            $content = $dom->all_text();
            if ($content) {
                $content =
                  b($content)->squish->split(qr/[[:punct:][:space:]]+/)
                  ->map( sub        { lc } )
                  ->uniq->grep( sub { not exists $stopword{$_} } )
                  ->grep( sub       { length > 1 } )->join(' ');
            }
            else {
                warn "No words for $url\n";
            }
        }

        $self->base->db->set(
            {
                title   => $title   || '',
                content => $content || '',
                url     => $url,
            }
        );

    }
    else {
        my $err = $tx->error;
        print STDERR "Error for $url: ";
        if ( $err->{code} ) {
            warn "code $err->{code} response: $err->{message}\n";
        }
        else {
            warn "Connection error: $err->{message}\n";
        }

    }
}

1;
