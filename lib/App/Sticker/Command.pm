package App::Sticker::Command;
use Mojo::Base -base;

use App::Sticker::URLQueue;
use Mojo::SQLite;
use Mojo::ByteStream 'b';

has ua        => sub { App::Sticker::URLQueue->new };
has sql       => sub { Mojo::SQLite->new('sticker.db'); };
has stopwords => sub { [qw(and the is are)] };

sub db { return shift->sql->db }

sub import_url {
    my ( $self, $tx, $url ) = @_;
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
              map { $_ => 1 } @{ $self->stopwords };

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

        my @values = ( $title // '', $content // '', $url, scalar time() );
        $self->db->query(
'INSERT INTO urls ( title, content, url, add_date ) VALUES ( ?, ?, ?, ? )',
            @values
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
    return;
}

sub normalize_url {
    my $self       = shift;
    my $url_string = shift;
    my $url        = Mojo::URL->new($url_string);
    ## If the user enters a url without a protocoll or a path, Mojo::URL parses
    ## the hostname as path.
    if ( not defined $url->host and defined $url->path ) {
        $url = Mojo::URL->new()->host( $url->path->trailing_slash(0) );
    }
    $url->scheme('http') if !$url->scheme;
    $url->authority('')  if !$url->authority;
    $url->port(undef)    if $url->port && $url->port == 80;
    $url->path('/')      if $url->path eq '';
    return $url;
}

1;
