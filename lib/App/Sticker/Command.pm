package App::Sticker::Command;
use Mojo::Base -base;

use App::Sticker::URLQueue;
use Mojo::SQLite;
use Mojo::SQLite::Migrations;
use Mojo::ByteStream 'b';
use Path::Tiny;
use Config::Tiny;

has ua => sub {
    my $self = shift;
    App::Sticker::URLQueue->new( worker => $self->config->{worker} );
};

has sql       => sub { Mojo::SQLite->new('sticker.db'); };
has stopwords => sub { [qw(and the is are)] };

has config => sub {
    my $self     = shift;
    my %defaults = (
        url_viewer => 'xdg-open %s',
        worker     => 16,
    );
    return { %defaults, %{ $self->read_config } };
};

sub startup {
    my $self = shift;
    $self->sql->migrations->from_data->migrate;
    return $self;
}

sub read_config {
    my $self = shift;

    my $file =
      $ENV{STICKER_CONFIG_DIR} ? path( $ENV{STICKER_CONFIG_DIR} )
      : path(
          $ENV{XDG_CONFIG_HOME} ? $ENV{XDG_CONFIG_HOME}
        : $^O eq "MSWin32"      ? $ENV{APPDATA}
        : $^O eq 'darwin'       ? '~/Library/Application Support'
        :                         '~/.config/'
      )->child('sticker')->child('config');

    return {} if !$file->exists;
    my $file_config = Config::Tiny->read( $file, 'utf8' );
    warn Config::Tiny->errstr . "\n" if !$file_config;
    return {} if !( $file_config && exists $file_config->{_} );
    return $file_config->{_};
}

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

__DATA__

@@ migrations

-- 1 up

create table if not exists urls (
	url_id integer primary key,
	title text,
	content text,
	url text unique,
	add_date text
);
