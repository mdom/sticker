package App::Sticker::Command;
use Mojo::Base -base;

use App::Sticker::URLQueue;
use Mojo::SQLite;
use Mojo::SQLite::Migrations;
use Mojo::ByteStream 'b';
use Path::Tiny;
use Config::Tiny;

has config_file => sub {
    return
      $ENV{STICKER_CONFIG_DIR} ? path( $ENV{STICKER_CONFIG_DIR} )
      : path(
          $ENV{XDG_CONFIG_HOME} ? $ENV{XDG_CONFIG_HOME}
        : $^O eq "MSWin32"      ? $ENV{APPDATA}
        : $^O eq 'darwin'       ? '~/Library/Application Support'
        :                         '~/.config/'
      )->child('sticker')->child('config')->stringify;
};

has ua => sub {
    my $self = shift;
    App::Sticker::URLQueue->new( worker => $self->config->{worker} );
};

has sql => sub {
    my $self = shift;
    Mojo::SQLite->new( $self->config->{db_file} );
};

has stopwords => sub { [qw(and the is are)] };

has config => sub {
    my $self     = shift;
    my %defaults = (
        url_viewer => 'xdg-open %s',
        worker     => 16,
        db_file    => $self->_build_db_file,
    );
    return { %defaults, %{ $self->read_config } };
};

sub _build_db_file {
    my $dir = path(
          $^O eq "MSWin32" ? $ENV{APPDATA}
        : $^O eq 'darwin'  ? '~/Library/Application Support'
        :                    '~/.local/share/'
    )->child('sticker');
    $dir->mkpath if !$dir->exists;
    return $dir->child('bookmarks.db')->stringify;
}

sub startup {
    my $self = shift;
    $self->sql->migrations->from_data->migrate;
    return $self;
}

sub read_config {
    my $self = shift;
    my $file = path( $self->config_file );
    return {} if !$file->exists;
    my $config = Config::Tiny->read( $file, 'utf8' );
    warn Config::Tiny->errstr . "\n" if !$config;
    return {} if !( $config && exists $config->{_} );
    return $config->{_};
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
        $self->db->query( '
		insert or ignore into urls ( title, content, url, add_date )
		VALUES ( ?, ?, ?, ? )', @values );

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

sub filter_new_urls {
    my ( $self, @urls ) = @_;
    $self->db->query(
        'create temp table if not exists tmp_urls (url);delete from tmp_urls;');

    my $tx = $self->db->begin;
    $self->db->query( 'insert into tmp_urls values (?)', $_ ) for @urls;
    $tx->commit;

    return $self->db->query(
        'select url from tmp_urls except select url from urls ')
      ->arrays->flatten->each;
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

-- 2 up

create table if not exists tags (
	tag_id integer primary key,
	name text unique
);

create table if not exists tags_urls (
	tag_id integer references tags,
	url_id integer references urls,
	primary key ( tag_id, url_id )
);
